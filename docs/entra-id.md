# Grafana login with Microsoft Entra ID

Sign in to Grafana with Entra ID accounts, with each person's Grafana role (Admin, Editor or Viewer) set by an app role in Entra.

Grafana's Entra ID login (`[auth.azuread]`) takes roles from app roles. It does not support `role_attribute_path`, so a group-based role mapping is ignored and, with strict mode on, everyone is refused with "IdP did not return a role attribute".

## 1. App registration

1. In the Azure portal, go to **Microsoft Entra ID → App registrations → New registration**.
2. Name it after the Grafana instance, for example `grafana-app`.
3. Supported account types: **Accounts in this organizational directory only**.
4. Redirect URI: platform **Web**, address `https://<grafana hostname>/login/azuread`, for example `https://grafana.lan/login/azuread`. Check it carefully: it must match `GF_SERVER_ROOT_URL` in `.env` exactly, including `https://`, the hostname, any port and the path.

The redirect works even if Grafana isn't on the internet: it's the browser that goes back to Grafana, not Entra. The address only has to resolve from the device you sign in with.

Grafana must be on HTTPS (this stack's default). Entra only accepts `http://` redirect URIs for `localhost`, so `http://grafana.lan:3000` is refused.

## 2. Values for `.env`

From the app registration's **Overview** page:

| Portal value | `.env` setting |
|---|---|
| Application (client) ID | `GF_AUTH_AZUREAD_CLIENT_ID` |
| Directory (tenant) ID | the `<tenant-id>` part of `GF_AUTH_AZUREAD_AUTH_URL` and `GF_AUTH_AZUREAD_TOKEN_URL` |

Then **Certificates & secrets → Client secrets → New client secret**. Copy the **Value** (not the Secret ID) into `GF_AUTH_AZUREAD_CLIENT_SECRET`. It's shown only once; if you lose it, create another. Note the expiry date: sign-in stops working when it expires.

Uncomment the Entra ID block in `.env` and fill it in:

```
GF_AUTH_AZUREAD_ENABLED=true
GF_AUTH_AZUREAD_NAME=Microsoft Entra ID
GF_AUTH_AZUREAD_CLIENT_ID=<application (client) id>
GF_AUTH_AZUREAD_CLIENT_SECRET=<client secret value>
GF_AUTH_AZUREAD_SCOPES=openid email profile
GF_AUTH_AZUREAD_AUTH_URL=https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/authorize
GF_AUTH_AZUREAD_TOKEN_URL=https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token
GF_AUTH_AZUREAD_ALLOW_SIGN_UP=true
GF_AUTH_AZUREAD_ROLE_ATTRIBUTE_STRICT=true
```

Save the file. `ROLE_ATTRIBUTE_STRICT=true` refuses anyone without an app role. With it off, they get in as Viewer.

## 3. App roles

In **App registrations → grafana-app → App roles → Create app role**, three times:

| Display name | Allowed member types | Value | Description |
|---|---|---|---|
| Admin | Users/Groups | `Admin` | Admin |
| Editor | Users/Groups | `Editor` | Editor |
| Viewer | Users/Groups | `Viewer` | Viewer |

The value must be exactly `Admin`, `Editor` or `Viewer`; Grafana reads it from the token. The description can be anything. Optionally add a fourth role with value `GrafanaAdmin` for Grafana server admins.

## 4. Assign users

In **Microsoft Entra ID → Enterprise applications → grafana-app → Users and groups → Add user/group**, pick each user or group and the role to give them.

On the Entra ID free tier you can only pick individual users. Assigning groups needs Entra ID P1 or above.

## 5. Apply the settings

```bash
docker compose up -d
```

`up -d` recreates the Grafana container with the new `.env`. `docker compose restart` does not reread `.env`.

Sign in from a new private window: the login page now has a **Sign in with Microsoft Entra ID** button. Role changes in Entra reach Grafana at the user's next sign-in.

## Using `grafana.ini` instead

If you configure Grafana with a config file rather than environment variables, set the same values:

```ini
[server]
root_url = https://grafana.lan/

[auth.azuread]
enabled = true
name = Microsoft Entra ID
client_id = <application (client) id>
client_secret = <client secret value>
scopes = openid email profile
auth_url = https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/authorize
token_url = https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token
allow_sign_up = true
role_attribute_strict = true
```

To keep the secret out of the file, use `client_secret = $__env{GRAFANA_ENTRA_SECRET}` and set that variable for the Grafana process.

## If it goes wrong

- **Redirect URI mismatch (AADSTS50011)**: the registered URI and `GF_SERVER_ROOT_URL` differ. Fix the registration, or `GF_SERVER_ROOT_URL` and run `docker compose up -d`.
- **"IdP did not return a role attribute"**: the user has no app role. Assign one in Enterprise applications, then sign in again from a new private window.
- **Certificate warning during sign-in**: the lab CA isn't trusted on this device. See step 2 of the setup in the README.
- **Invalid client secret (AADSTS7000215)**: the Secret ID was copied instead of the Value, or the secret has expired.
