# docker-deye-collector
This is docker-based deye collector and extractor to grafana cloud

# Pre-requirements
1. Register your device in DeyeCloud application 

2. DeyeCloud developer account
Please visit https://developer.deyecloud.com/start to create account, obtain the APP_ID and
APP_SECRET. Also you need to know your device serial number

3. You need to have a Grafana Cloud account. Free plan will be enought to start your monitoring. Once you have account you need to get the prometheus endpoint credentials.
You may use a dashboards from this project to be imported to your grafana ui, or generate your own.

# Update .env file
APP_ID= - from DeyeCloud Developer portal

APP_SECRET= - from DeyeCloud Developer portal

EMAIL= - DeyeCloud Developer portal account e-mail

PASSWORD= - DeyeCloud Developer portal account password

DEVICE_SN=  - Your Deye invertor SN

BASE_URL= - DeyeCloud Developer portal base URL (in a top of https://developer.deyecloud.com/api)

OUT_DIR=/metrics <- do not change

GRAFANA_URL= - Cloud Prometheus endpoint

GRAFANA_USER= - Cloud Prometheus username

GRAFANA_API_KEY= - Cloud Prometheus api secret key

# Start the project
run in terminal sudo docker-compose up -d
after completion check the logs using the sudo docker-compose logs -f