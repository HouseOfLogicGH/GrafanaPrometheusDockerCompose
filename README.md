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
sh certs/make-certs.sh grafana.lan 192.168.5.227 192.168.5.0/255.255.255.0
docker compose up -d
```

Then:

1. Point `grafana.lan` at the host in your router's DNS or your hosts file.
2. Copy `certs/ca.crt` to your PC and trust it. On Windows:
   `Import-Certificate -FilePath ca.crt -CertStoreLocation Cert:\CurrentUser\Root`
3. Open https://grafana.lan and sign in as `admin` / `admin`; Grafana asks for a new password.

Change the targets in `prometheus.yml` (the `blackbox_*` jobs) to your own websites and devices.

## Configuration

- **`.env`**: image versions and Grafana settings. Email (SMTP), Azure, Entra ID login and AWS sections are commented out, with notes on where each value comes from. Never commit `.env`.
- **HTTP instead of HTTPS**: follow the note in `.env`, then swap the port lines in `docker-compose.yml` and comment out the HTTPS lines in the `grafana` job in `prometheus.yml`.
- **After editing `prometheus.yml` or `blackbox.yml`**: `docker compose restart prometheus` (or `blackbox`). `docker compose up -d` only recreates a container when its service definition changes.
- **Upgrading**: change the version in `.env`, then `docker compose pull && docker compose up -d`.
