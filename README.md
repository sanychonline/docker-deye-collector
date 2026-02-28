# docker-deye-collector

Lightweight Docker-based collector for Deye inverter metrics with export
to Grafana Cloud using the DeyeCloud Developer API.

This project pulls inverter data from DeyeCloud, converts it to
Prometheus metrics, and sends them directly to Grafana Cloud via
remote_write.

  No local database
  No heavy monitoring stack
  Just API → metrics → Grafana

------------------------------------------------------------------------

✨ Features

-   Authentication via DeyeCloud Developer Portal
-   Periodic inverter polling
-   Prometheus-compatible metrics
-   Direct remote_write to Grafana Cloud
-   Fully Docker-based
-   Built-in control scripts
-   Optional authenticated HTTP control API

------------------------------------------------------------------------

📦 Requirements

Before starting, ensure you have:

1. Deye Inverter registered in DeyeCloud

Your inverter must be active and linked to your DeyeCloud account.

------------------------------------------------------------------------

2. DeyeCloud Developer Account

Register at:

https://developer.deyecloud.com/start

You will need:

-   APP_ID
-   APP_SECRET
-   Developer account email
-   Developer account password
-   Inverter serial number (DEVICE_SN)

------------------------------------------------------------------------

3. Grafana Cloud Account

Free plan is sufficient.

From your Grafana Cloud Prometheus instance, obtain:

-   remote_write endpoint
-   Username
-   API key (recommended: write-only key)

------------------------------------------------------------------------

⚙️ Configuration

Create a .env file in the project root:

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

------------------------------------------------------------------------

🚀 Quick Start

Start the stack:

    docker compose up -d

View logs:

    docker compose logs -f

------------------------------------------------------------------------

🛠 Utility Scripts

Inside the container:

/opt/deye/

Available scripts:

-   deye-start.sh
-   deye-stop.sh
-   deye-restart.sh
-   deye-check.sh

Example usage:

    docker exec -it deye-collector /opt/deye/deye-check.sh

------------------------------------------------------------------------

🌐 Exposed Control API

The container includes an optional authenticated HTTP control API.

Expose the port in docker-compose:

    ports:
      - "9090:9090"

Available endpoints:

-   POST /api/check
-   POST /api/start
-   POST /api/stop
-   POST /api/restart

Example:

    export APP_SECRET=your_secret
    curl -X POST -H "X-API-KEY: ${APP_SECRET}" http://127.0.0.1:9090/api/check

------------------------------------------------------------------------

🔐 Security

-   Do not commit .env
-   Use strong APP_SECRET
-   Restrict port 9090
-   Prefer HTTPS if exposed publicly

------------------------------------------------------------------------

⚠ Disclaimer

This project is not affiliated with Deye or DeyeCloud.

Use at your own risk.