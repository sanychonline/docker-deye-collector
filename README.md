
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
- Securely expose endpoints through Caddy (HTTPS)

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
DEYE_USERNAME=your_email
DEYE_PASSWORD=your_password
DEYE_REGION=eu1
DEYE_SITE_ID=123456

SCRAPE_INTERVAL=60s

REMOTE_WRITE_URL=https://prometheus-xxx.grafana.net/api/prom/push
REMOTE_WRITE_USERNAME=xxxxx
REMOTE_WRITE_PASSWORD=xxxxx

PUBLIC_DOMAIN=metrics.example.com
```

## Variable Explanation

### Authentication

- `DEYE_USERNAME`
- `DEYE_PASSWORD`
- `DEYE_REGION`
- `DEYE_SITE_ID`

Region must match your Deye account (e.g., `eu1`, `cn`, etc).

### Scraping

- `SCRAPE_INTERVAL` — metric pull frequency

Lower interval = more API calls.

### Remote Write (Optional)

- `REMOTE_WRITE_URL`
- `REMOTE_WRITE_USERNAME`
- `REMOTE_WRITE_PASSWORD`

If not defined, metrics remain local only.

### Reverse Proxy

- `PUBLIC_DOMAIN` — used by Caddy for automatic TLS

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
docker compose logs collector
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
metrics.example.com {
    reverse_proxy collector:8080
}
```

Features:

- Automatic HTTPS
- Automatic certificate renewal
- Clean public endpoint

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
2. Confirm region
3. Confirm correct site ID
4. Check logs
5. Test outbound HTTPS connectivity
6. Validate remote_write endpoint

Common causes:

- Invalid login
- Expired API session
- Firewall blocking egress
- Incorrect region selection

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
