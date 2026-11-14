# The stack without Docker Compose

The same Grafana, Prometheus and Blackbox exporter stack using plain `docker run`. It uses the same config files as the Compose version, so every video's settings in the [README](../README.md#the-videos) apply unchanged. Only the commands to start and recreate containers differ.

## Setup

```bash
apt-get install -y docker.io git
git clone https://github.com/HouseOfLogicGH/GrafanaPrometheusDockerCompose /opt/monitoring
cd /opt/monitoring
cp .env.example .env && chmod 600 .env
mkdir -p local && cp prometheus.yml local/
sh certs/make-certs.sh grafana.lan 192.168.1.50 192.168.1.0/255.255.255.0
```

The `make-certs.sh` line works as in the README: your hostname, the host's IP (leave it out for DHCP) and your network.

The containers find each other by name (`prometheus`, `blackbox`, `grafana`) on their own network, the same names the config files use:

```bash
docker network create monitoring
```

## Run the containers

Run these from `/opt/monitoring`. `v` reads an image version from `.env`, so `.env` stays the one place versions are set.

```bash
v() { sed -n "s/^$1=//p" .env; }

docker run -d --name prometheus --network monitoring --restart unless-stopped \
  -v "$PWD/local/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  -v "$PWD/certs/ca.crt:/etc/prometheus/ca.crt:ro" \
  -v prometheus-data:/prometheus \
  -p 9090:9090 \
  prom/prometheus:$(v PROMETHEUS_VERSION) \
  --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.retention.time=30d

docker run -d --name blackbox --network monitoring --restart unless-stopped \
  -v "$PWD/blackbox.yml:/etc/blackbox/blackbox.yml:ro" \
  -p 9115:9115 \
  prom/blackbox-exporter:$(v BLACKBOX_VERSION) \
  --config.file=/etc/blackbox/blackbox.yml

docker run -d --name grafana --network monitoring --restart unless-stopped \
  --env-file .env \
  -v "$PWD/provisioning:/etc/grafana/provisioning" \
  -v "$PWD/certs/grafana.crt:/etc/grafana/certs/grafana.crt:ro" \
  -v "$PWD/certs/grafana.key:/etc/grafana/certs/grafana.key:ro" \
  -v grafana-data:/var/lib/grafana \
  -p 443:3000 \
  grafana/grafana:$(v GRAFANA_VERSION)
```

For HTTP instead of HTTPS, follow the note in `.env`, use `-p 3000:3000` for Grafana and comment out the HTTPS lines in the `grafana` job in `local/prometheus.yml`.

Then follow the numbered steps after the commands in the [README setup](../README.md#setup): DNS, trusting the CA, first sign-in and your own targets.

## Applying changes

| You changed | Run |
|---|---|
| `local/prometheus.yml` | `docker restart prometheus` |
| `blackbox.yml` | `docker restart blackbox` |
| A provisioning file | `docker restart grafana` |
| `.env` (any video's settings) | `docker rm -f grafana`, then the Grafana `docker run` command again |
| An image version in `.env` | `docker rm -f <name>`, then that container's `docker run` command again (it pulls the new image) |

A restart doesn't reread `.env`: environment variables are fixed when a container is created. Removing a container keeps its data, which lives in the `grafana-data` and `prometheus-data` volumes.

## The videos' settings

Everything else is the same as with Compose:

- **Azure VMs**: create the [service principal](../README.md#azure-service-principal-for-the-azure-videos), fill in the `AZ_*` values and the email section in `.env`, and for the Azure Monitor data source:

  ```bash
  cp provisioning/datasources/azure-monitor.yaml.example provisioning/datasources/azure-monitor.yaml
  docker rm -f grafana    # then the Grafana docker run command
  ```

- **Entra ID login**: the Entra ID section of `.env` ([docs/entra-id.md](entra-id.md)), then recreate Grafana.

## Notes

- `--env-file` takes each line literally: no quotes around values, and notes on their own lines. `.env.example` is already written that way.
- These containers and volumes are separate from the Compose ones (Compose prefixes its volumes with the folder name, e.g. `monitoring_grafana-data`). Don't run both versions on the same host: they want the same ports.
- To remove everything except the data: `docker rm -f grafana prometheus blackbox && docker network rm monitoring`.
