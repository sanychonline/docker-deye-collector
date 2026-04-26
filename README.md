
# Deye Docker Collector

Production‑ready Docker stack for collecting metrics from a Deye inverter,
processing them, and forwarding them to monitoring systems (Grafana / Prometheus).

---

## ⚠ Disclaimer

This project is **not affiliated with or endorsed by Deye**.

It relies on public or reverse‑engineered API interactions and may break
if the vendor changes their API, authentication mechanism, or rate limits.

You are responsible for:

- Securing your credentials
- Complying with your local regulations
- Verifying data accuracy before operational decisions
- Ensuring safe deployment in your environment

Use at your own risk.

---

# 1. Overview

This stack is designed to:

- Authenticate against Deye Cloud API
- Periodically collect inverter metrics
- Expose metrics in Prometheus format
- Optionally forward via `remote_write`
- Provide ready-to-import Grafana dashboards
- Optionally securely expose endpoints through Caddy (HTTPS)

Fully containerized. Reproducible. Predictable.

---

# 2. Architecture

```
Deye Cloud API
        ↓
Collector Container
        ↓
Prometheus metrics endpoint
        ↓
(optional remote_write)
        ↓
Grafana / Grafana Cloud
```

Reverse proxy (Caddy) can expose selected endpoints externally via HTTPS.

---

# 3. Project Structure

```
docker-deye-collector/
├── docker-compose.yml
├── .env
├── Caddyfile
├── dashboard-*.json
└── README.md
```

### Key Files

- `docker-compose.yml` – Service definitions
- `.env` – Runtime configuration
- `Caddyfile` – Reverse proxy configuration
- `dashboard-*.json` – Grafana dashboards

---

# 4. Requirements

- Docker 20+
- Docker Compose v2+
- Stable internet connection
- Valid Deye Cloud credentials
- Optional: Grafana (Cloud or self-hosted)

---

# 5. Environment Configuration (.env)

Example:

```
APP_ID=your_deye_app_id
APP_SECRET=your_deye_app_secret
EMAIL=your_deye_account_email
PASSWORD=your_deye_account_password
DEVICE_SN=your_device_serial_number

BASE_URL=https://eu1-developer.deyecloud.com
OUT_DIR=/metrics

GRAFANA_URL=https://prometheus-xxx.grafana.net/api/prom/push
GRAFANA_USER=xxxxx
GRAFANA_API_KEY=glc_xxx

CADDY_BIND_IP=127.0.0.1
CADDY_HTTP_PORT=80
CADDY_HTTPS_PORT=443
PUBLIC_DOMAIN=metrics.example.com

PANEL_PASSWORD=strong_password
FLASK_SECRET=long_random_secret
```

## Variable Explanation

### Authentication

- `APP_ID`
- `APP_SECRET`
- `EMAIL`
- `PASSWORD`
- `DEVICE_SN`

### Deye API

- `BASE_URL` (e.g. `https://eu1-developer.deyecloud.com`)

### Collector Output

- `OUT_DIR` (default `/metrics`)

### Remote Write (Optional)

- `GRAFANA_URL`
- `GRAFANA_USER`
- `GRAFANA_API_KEY`

If not defined, metrics remain local only.

### Reverse Proxy

- `CADDY_BIND_IP` — where host ports are bound (recommended `127.0.0.1`)
- `CADDY_HTTP_PORT` — host port mapped to container `:80`
- `CADDY_HTTPS_PORT` — host port mapped to container `:443`
- `PUBLIC_DOMAIN` — optional domain used by Caddy for host-based routing/TLS
- Caddy starts together with collector in normal `docker compose up -d` flow

### Web UI Access

- `PANEL_PASSWORD`
- `FLASK_SECRET`

---

# 6. Deployment

Start:

```
docker compose up -d
```

Check status:

```
docker compose ps
```

Logs:

```
docker compose logs -f
```

Stop:

```
docker compose down
```
Restart cleanly:

```
docker compose down
docker compose up -d
```

---

# 7. Operational Management

## Check container health

```
docker compose ps
```

## Inspect logs

```
docker compose logs deye
```

## Update containers

```
docker compose pull
docker compose up -d
```

## Remove unused resources

```
docker system prune
```

---

# 8. Grafana Dashboard Import

1. Open Grafana
2. Dashboards → Import
3. Upload `dashboard-*.json`
4. Select data source
5. Save

If using Grafana Cloud, verify `remote_write` credentials first.

---

# 9. Caddy Reverse Proxy

Example:

```
:80 {
    reverse_proxy deye:9090
}

{$PUBLIC_DOMAIN:localhost} {
    reverse_proxy deye:9090
}
```

Features:

- HTTP listener for local/private access
- Optional host-based entrypoint for domain deployments
- Proxies traffic to `deye:9090`

If running in a private network, external exposure may be unnecessary.

---

# 10. Security Recommendations

- Use strong credentials
- Do not expose raw metrics publicly
- Restrict Docker published ports
- Place behind firewall or VPN
- Never commit `.env` with secrets

---

# 11. Troubleshooting

If no metrics appear:

1. Verify credentials
2. Confirm `DEVICE_SN`
3. Confirm `BASE_URL`
4. Check logs
5. Test outbound HTTPS connectivity
6. Validate remote_write endpoint

Common causes:

- Invalid login
- Expired API session
- Invalid `DEVICE_SN`
- Invalid Grafana API key (`401 Unauthorized`)
- Firewall blocking egress

---

# 12. Production Considerations

For more serious deployments:

- Use Docker secrets instead of .env
- Add container healthchecks
- Add monitoring for the collector itself
- Centralize logs
- Version your dashboards

---

# 13. Maintenance Strategy

Recommended:

- Backup `.env` securely
- Version control dashboards
- Tag stable configuration states
- Review logs periodically
- Validate metrics after upgrades

---

Maintained with emphasis on clarity, operational control, and long-term maintainability.
