FROM debian:bookworm-slim

ARG TARGETARCH
ARG ALLOY_VERSION=1.16.0

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

# Install Grafana Alloy (multi-arch, with fallback when TARGETARCH is not set)
RUN set -eu; \
    ARCH="${TARGETARCH:-}"; \
    if [ -z "${ARCH}" ]; then \
      ARCH="$(dpkg --print-architecture)"; \
    fi; \
    case "${ARCH}" in \
      x86_64) ARCH="amd64" ;; \
      aarch64) ARCH="arm64" ;; \
    esac; \
    case "${ARCH}" in \
      amd64|arm64) ;; \
      *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;; \
    esac; \
    echo "Building for arch: ${ARCH}"; \
    wget "https://github.com/grafana/alloy/releases/download/v${ALLOY_VERSION}/alloy-linux-${ARCH}.zip"; \
    unzip "alloy-linux-${ARCH}.zip"; \
    mv "alloy-linux-${ARCH}" /usr/local/bin/alloy; \
    chmod +x /usr/local/bin/alloy; \
    rm -f "alloy-linux-${ARCH}.zip"

# Copy application files
COPY dockerfiles/collector/ /opt/deye/

# Ensure Alloy config path exists
RUN mkdir -p /etc/alloy \
    && cp /opt/deye/config.alloy /etc/alloy/config.alloy

# Make scripts to be executable
RUN chmod +x /opt/deye/*.sh

EXPOSE 9090

ENTRYPOINT ["/opt/deye/entrypoint.sh"]
