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
5. Optional, for Azure: fill in the `AZ_*` values in `.env`, then turn on the Azure Monitor data source. Grafana doesn't read the `AZ_*` variables itself; only this provisioning file does, and it ignores the `.example` copy:

   ```bash
   cp provisioning/datasources/azure-monitor.yaml.example provisioning/datasources/azure-monitor.yaml
   docker compose up -d && docker compose restart grafana
   ```

   `up -d` loads the changed `.env`; the restart makes Grafana read the new provisioning file. Then check **Azure Monitor** with **Save & test**.

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
- **Without Docker Compose**: the same stack with plain `docker run` commands is in [docs/docker-run.md](docs/docker-run.md).

## The videos

Each House of Logic video built on this stack has a section here with the settings it needs. Every one starts from the [Setup](#setup) above. Settings go in `.env`; after changing `.env`, run `docker compose up -d` (a restart doesn't reread it).

### Video: How to setup Grafana and Prometheus with Docker Compose

Watch: https://youtu.be/1pjhhABDWtE

The quick route to the stack on an unprivileged Proxmox LXC container.

- **Container**: unprivileged, with `nesting=1` and `keyctl=1` (Options → Features in Proxmox). Without them Docker fails with permission errors; don't make the container privileged to fix that.
- **Settings**: only the [Setup](#setup) steps. The other sections of `.env` stay commented out until their videos.
- **Your targets**: edit `local/prometheus.yml`, not `prometheus.yml`, so `git pull` never clashes. Then `docker compose restart prometheus`.
- **Ports**: 443 (Grafana), 9090 (Prometheus), 9115 (Blackbox exporter). For a second app on the same Docker host, give it its own folder and Compose file and choose ports that don't clash with these.

### Azure service principal (for the Azure videos)

Grafana reads Azure with a service principal: an identity with a secret and only the read access it needs. The Azure VMs and Log Analytics videos below use one.

```bash
az login
SUB=$(az account show --query id -o tsv)
az ad sp create-for-rbac -n sp-hol-grafana --role "Monitoring Reader" \
  --scopes /subscriptions/$SUB/resourceGroups/<resource-group>
```

Use the resource group that holds what you're monitoring. **Monitoring Reader** can read metrics and query Log Analytics, and can't change anything. Scoping it to one resource group means Grafana sees nothing else. To let it read another resource group too:

```bash
az role assignment create --assignee <appId> --role "Monitoring Reader" \
  --scope /subscriptions/$SUB/resourceGroups/<other-resource-group>
```

Put the output in `.env` and uncomment the lines:

| `create-for-rbac` output | `.env` |
|---|---|
| `tenant` | `AZ_TENANT` |
| `appId` | `AZ_CLIENT_ID` |
| `password` | `AZ_CLIENT_SECRET` |
| `az account show --query id -o tsv` | `AZ_SUBSCRIPTION` |

`GF_AUTH_AZURE_AUTH_ENABLED=true` must stay on. The secret expires after a year; get a new one with `az ad sp credential reset --id <appId>`, update `AZ_CLIENT_SECRET`, then `docker compose up -d`.

### Video: How to Monitor Azure VMs with Grafana

- **Identity**: the [Azure service principal](#azure-service-principal-for-the-azure-videos) with Monitoring Reader on the VMs' resource group.
- **Data source**: step 5 of the [Setup](#setup): copy `provisioning/datasources/azure-monitor.yaml.example` to `azure-monitor.yaml`, then `docker compose up -d && docker compose restart grafana`, and **Save & test** on the Azure Monitor data source.
- **Alert email**: fill in the email section of `.env`. For Gmail, `GF_SMTP_PASSWORD` is a 16-character app password (2-step verification on), not your Gmail password. Then `docker compose up -d`, and check it with **Test** on the email contact point (Alerting → Contact points).
- **Memory**: VM memory isn't among the platform metrics. It needs the Azure Monitor Agent, which the [Log Analytics video](#video-azure-log-analytics-in-grafana) sets up.

### Video: Azure Log Analytics in Grafana

- **Identity**: the same service principal. Monitoring Reader covers KQL queries on a Log Analytics workspace in its resource group. If the workspace is in another resource group, add a role assignment there.
- **Data source**: the same Azure Monitor data source as the VMs video; Logs queries pick the workspace in the query editor.
- **Custom table sender**: the Logs Ingestion API sender doesn't use Grafana's service principal. It needs its own identity with **Monitoring Metrics Publisher** on the data collection rule, and the `DCE_LOGS_URL` and `DCR_ID` values in `.env`.
- **No rows at first**: new data takes a few minutes to arrive, and a new custom table can take longer the first time.

### Video: Grafana Login with Microsoft Entra ID

- **Identity**: a second app registration, separate from `sp-hol-grafana`. That one reads monitoring data; this one signs people in, with its own secret and redirect URI. Keeping them apart means a leaked login secret can't read Azure, and the other way round.
- **HTTPS**: required (the stack's default). Entra only accepts `http://` redirects for `localhost`.
- **Settings**: the Entra ID section of `.env`, then `docker compose up -d`. Full steps, app roles and fixes for common errors: [docs/entra-id.md](docs/entra-id.md).

To create the app registration from the command line instead of the portal:

```bash
az ad app create --display-name grafana-app --sign-in-audience AzureADMyOrg \
  --web-redirect-uris https://grafana.lan/login/azuread
az ad sp create --id <appId>     # the Enterprise application, where users get their roles
az ad app credential reset --id <appId> --display-name grafana --years 1
```

`appId` goes in `GF_AUTH_AZUREAD_CLIENT_ID`, `password` in `GF_AUTH_AZUREAD_CLIENT_SECRET`, and `tenant` replaces `<tenant-id>` in the two URLs. Then create the Admin, Editor and Viewer app roles and assign users as in [docs/entra-id.md](docs/entra-id.md#3-app-roles).
