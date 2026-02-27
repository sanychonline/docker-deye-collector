# docker-deye-collector

Lightweight Docker-based collector for Deye inverter metrics with export to Grafana Cloud using the DeyeCloud Developer API.

This project pulls inverter data from DeyeCloud, converts it to Prometheus metrics, and sends them directly to Grafana Cloud via `remote_write`.

> No local database  
> No heavy monitoring stack  
> Just API → metrics → Grafana

---

## ✨ Features

- Authentication via DeyeCloud Developer Portal
- Periodic inverter polling
- Prometheus-compatible metrics
- Direct remote_write to Grafana Cloud
- Fully Docker-based
- Built-in control scripts

---

## 📦 Requirements

Before starting, ensure you have:

### 1. Deye Inverter registered in DeyeCloud

Your inverter must be active and linked to your DeyeCloud account.

---

### 2. DeyeCloud Developer Account

Register at:

https://developer.deyecloud.com/start

You will need:

- APP_ID
- APP_SECRET
- Developer account email
- Developer account password
- Inverter serial number (DEVICE_SN)

---

### 3. Grafana Cloud Account

Free plan is sufficient.

From your Grafana Cloud Prometheus instance, obtain:

- remote_write endpoint
- Username
- API key (recommended: write-only key)

---

## ⚙️ Configuration

Create a `.env` file in the project root:

```env
APP_ID=
APP_SECRET=
EMAIL=
PASSWORD=
DEVICE_SN=
BASE_URL=https://developer.deyecloud.com
OUT_DIR=/metrics
GRAFANA_URL=
GRAFANA_USER=
GRAFANA_API_KEY=
```

### Variable Description

| Variable | Description |
|----------|------------|
| APP_ID | DeyeCloud Developer APP_ID |
| APP_SECRET | DeyeCloud Developer APP_SECRET |
| EMAIL | Developer account email |
| PASSWORD | Developer account password |
| DEVICE_SN | Inverter serial number |
| BASE_URL | DeyeCloud API base URL |
| OUT_DIR | Metrics output directory (do not change) |
| GRAFANA_URL | Prometheus remote_write endpoint |
| GRAFANA_USER | Prometheus username |
| GRAFANA_API_KEY | Prometheus API key |

---

## 🚀 Quick Start

Start the stack:

```bash
docker-compose up -d
```

View logs:

```bash
docker-compose logs -f
```

If configured correctly, you should see successful login and data collection messages.

---

## 🛠 Utility Scripts

Inside the container:

```
/opt/deye/
```

Available scripts:

- deye-start.sh
- deye-stop.sh
- deye-restart.sh
- deye-check.sh

Example usage from host:

```bash
docker exec -it deye-collector /opt/deye/deye-check.sh
```

Example output:

```
== LOGIN ==
Token OK

== READ REGISTER 0x0050 ==
Raw value: 0001
INVERTER: RUN
```

---

## 📊 Grafana Dashboards

You may:

- Import dashboards included in this repository
- Create custom dashboards based on exported metrics

Metrics follow standard Prometheus naming conventions.

---

## 📂 Project Structure (example)

```
.
├── docker-compose.yml
├── .env
├── collector/
├── scripts/
└── dashboards/
```

---

## 🔍 Troubleshooting

If metrics are not visible in Grafana:

1. Check container status:
   ```bash
   docker ps
   ```

2. Check logs:
   ```bash
   docker-compose logs -f
   ```

3. Verify:
   - APP_ID / APP_SECRET
   - DEVICE_SN
   - Grafana credentials
   - Network connectivity

---

## 🔐 Security

- Do not commit `.env` to Git
- Use least-privilege Grafana API keys
- Do not expose developer credentials publicly

---

## 🤝 Contributing

Contributions are welcome.

If you would like to improve:

- Metrics coverage
- Error handling
- Logging
- Documentation
- Dashboards

Please:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

Keep changes focused and clearly documented.

---

## ⚠ Disclaimer

This project is not affiliated with Deye or DeyeCloud.

Use at your own risk.
