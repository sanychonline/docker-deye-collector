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
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-linux-amd64.zip \
    -O /tmp/alloy.zip && \
    unzip /tmp/alloy.zip -d /tmp && \
    mv /tmp/alloy-linux-amd64 /usr/local/bin/alloy && \
    chmod +x /usr/local/bin/alloy && \
    rm -rf /tmp/*

WORKDIR /opt/deye

COPY dockerfiles/collector/deye-connector.sh .
COPY dockerfiles/collector/entrypoint.sh .
COPY dockerfiles/collector/config.alloy /etc/alloy/config.alloy

RUN chmod +x deye-connector.sh entrypoint.sh
RUN mkdir -p /metrics

ENTRYPOINT ["/opt/deye/entrypoint.sh"]