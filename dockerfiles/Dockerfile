FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV ALLOY_VERSION=1.13.2

RUN apt-get update && apt-get install -y \
    curl \
    jq \
    ca-certificates \
    bash \
    wget \
    python3 \
    python3-venv \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --upgrade pip && pip install flask

ARG TARGETARCH
RUN wget https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-linux-${TARGETARCH}.zip \
    && unzip alloy-linux-${TARGETARCH}.zip \
    && mv alloy-linux-${TARGETARCH} /usr/local/bin/alloy \
    && chmod +x /usr/local/bin/alloy \
    && rm alloy-linux-${TARGETARCH}.zip

WORKDIR /opt/deye

COPY dockerfiles/collector/deye-connector.sh .
COPY dockerfiles/collector/deye-check.sh .
COPY dockerfiles/collector/deye-restart.sh .
COPY dockerfiles/collector/deye-start.sh .
COPY dockerfiles/collector/deye-stop.sh .
COPY dockerfiles/collector/entrypoint.sh .
COPY dockerfiles/collector/config.alloy /etc/alloy/config.alloy

COPY dockerfiles/collector/api.py .
RUN chmod +x api.py

RUN chmod +x deye-*.sh entrypoint.sh
RUN mkdir -p /metrics

ENTRYPOINT ["/opt/deye/entrypoint.sh"]
