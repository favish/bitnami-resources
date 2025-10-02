# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

FROM debian:bookworm-slim

ARG ELASTICSEARCH_EXPORTER_VERSION="1.9.0"
ARG TARGETARCH

LABEL org.opencontainers.image.base.name="debian:bookworm" \
      org.opencontainers.image.created="2025-10-02T00:00:00Z" \
      org.opencontainers.image.description="Elasticsearch Exporter for Prometheus" \
      org.opencontainers.image.documentation="https://github.com/prometheus-community/elasticsearch_exporter" \
      org.opencontainers.image.source="https://github.com/favish/bitnami-resources" \
      org.opencontainers.image.title="elasticsearch-exporter" \
      org.opencontainers.image.vendor="Favish" \
      org.opencontainers.image.version="${ELASTICSEARCH_EXPORTER_VERSION}"

ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="debian-12" \
    OS_NAME="linux" \
    ELASTICSEARCH_EXPORTER_VERSION="${ELASTICSEARCH_EXPORTER_VERSION}" \
    PATH="/opt/elasticsearch-exporter:$PATH"

COPY prebuildfs /
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# Install required system packages and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Download and install Elasticsearch Exporter from official GitHub releases
RUN ARCH=$(case ${TARGETARCH:-amd64} in \
        amd64) echo "amd64" ;; \
        arm64) echo "arm64" ;; \
        *) echo "amd64" ;; \
    esac) && \
    mkdir -p /opt/elasticsearch-exporter && \
    curl -L "https://github.com/prometheus-community/elasticsearch_exporter/releases/download/v${ELASTICSEARCH_EXPORTER_VERSION}/elasticsearch_exporter-${ELASTICSEARCH_EXPORTER_VERSION}.linux-${ARCH}.tar.gz" | \
    tar -xz --strip-components=1 -C /opt/elasticsearch-exporter
RUN apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives
RUN chmod g+rwX /opt
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

ENV APP_VERSION="${ELASTICSEARCH_EXPORTER_VERSION}" \
    BITNAMI_APP_NAME="elasticsearch-exporter" \
    IMAGE_REVISION="1" \ 
    PATH="/opt/elasticsearch-exporter/bin:$PATH"

EXPOSE 9114

WORKDIR /opt/elasticsearch-exporter
USER 1001
ENTRYPOINT [ "/opt/elasticsearch-exporter/elasticsearch_exporter" ]
