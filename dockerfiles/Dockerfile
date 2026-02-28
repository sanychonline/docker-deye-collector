FROM debian:bookworm-slim

ARG TARGETARCH
ARG ALLOY_VERSION=1.13.2

WORKDIR /opt/deye

# System packages
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

# Create Python virtual environment and install dependencies
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip \
    && /opt/venv/bin/pip install flask gunicorn requests

# Install Grafana Alloy (multi-arch)
RUN echo "Building for arch: ${TARGETARCH}" \
    && wget https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-linux-${TARGETARCH}.zip \
    && unzip alloy-linux-${TARGETARCH}.zip \
    && mv alloy-linux-${TARGETARCH} /usr/local/bin/alloy \
    && chmod +x /usr/local/bin/alloy \
    && rm alloy-linux-${TARGETARCH}.zip

# Copy application files
COPY dockerfiles/collector/ /opt/deye/

# Ensure Alloy config path exists
RUN mkdir -p /etc/alloy \
    && cp /opt/deye/config.alloy /etc/alloy/config.alloy

# Make scripts to be executable
RUN chmod +x /opt/deye/*.sh

EXPOSE 9090

ENTRYPOINT ["/opt/deye/entrypoint.sh"]