# House of Logic - Grafana, Prometheus and Blackbox with Docker Compose

Grafana, Prometheus and the Prometheus Blackbox exporter in one Docker Compose stack, with Grafana on HTTPS. It's the base for the House of Logic Grafana monitoring videos. Tested on Ubuntu 24.04 in an unprivileged Proxmox LXC container with nesting and keyctl enabled.

| Service | Address |
|---|---|
| Grafana | https://grafana.lan (HTTP on 3000 is in the config, commented out) |
| Prometheus | http://grafana.lan:9090 |
| Blackbox exporter | http://grafana.lan:9115 |

## Setup

```bash
apt-get install -y docker.io docker-compose-v2 git
git clone https://github.com/HouseOfLogicGH/GrafanaPrometheusDockerCompose /opt/monitoring
cd /opt/monitoring
cp .env.example .env && chmod 600 .env
mkdir -p local && cp prometheus.yml local/
cp docker-compose.override.example.yml docker-compose.override.yml
sh certs/make-certs.sh grafana.lan 192.168.1.50 192.168.1.0/255.255.255.0
docker compose up -d
```

Use your own hostname, the host's IP address and your network in the `make-certs.sh` line. Leave the IP out if the host gets its address from DHCP. If the hostname isn't `grafana.lan`, also change it in `.env` (`GF_SERVER_DOMAIN`, `GF_SERVER_ROOT_URL`) and in `local/prometheus.yml` (`server_name`).

Then:

1. Point the hostname at the host in your router's DNS or your hosts file.
2. Copy `certs/ca.crt` to your PC and trust it. On Windows:
   `Import-Certificate -FilePath ca.crt -CertStoreLocation Cert:\CurrentUser\Root`
3. Open https://grafana.lan and sign in as `admin` / `admin`; Grafana asks for a new password.
4. Replace the example targets in `local/prometheus.yml` (the `blackbox_*` jobs) with your own websites and devices, then `docker compose restart prometheus`.

## Your settings and updates

Your settings live in files git doesn't track: `.env`, `certs/`, `local/` and `docker-compose.override.yml`, which Docker Compose reads automatically and which mounts `local/prometheus.yml` in place of the repo's copy. So updating never overwrites them:

```bash
git pull
docker compose up -d
```

After a pull, compare the repo's `prometheus.yml` with yours (`diff prometheus.yml local/prometheus.yml`) and copy across anything new you want.

## Configuration

- **`.env`**: image versions and Grafana settings. Email (SMTP), Azure, Entra ID login and AWS sections are commented out, with notes on where each value comes from. Never commit `.env`.
- **Entra ID login**: see [docs/entra-id.md](docs/entra-id.md).
- **HTTP instead of HTTPS**: follow the note in `.env`, then swap the port lines in `docker-compose.yml` and comment out the HTTPS lines in the `grafana` job in `local/prometheus.yml`.
- **After editing `local/prometheus.yml` or `blackbox.yml`**: `docker compose restart prometheus` (or `blackbox`). `docker compose up -d` only recreates a container when its service definition changes.
- **Upgrading**: change the version in `.env`, then `docker compose pull && docker compose up -d`.
