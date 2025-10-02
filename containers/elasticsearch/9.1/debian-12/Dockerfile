# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

FROM debian:bookworm-slim

ARG ELASTICSEARCH_VERSION="9.1.2"
ARG YQ_VERSION="4.47.2"
ARG JAVA_VERSION="21"
ARG ELASTICSEARCH_PLUGINS
ARG JAVA_EXTRA_SECURITY_DIR="/opt/java/extra-security"
ARG TARGETARCH

LABEL org.opencontainers.image.base.name="debian:bookworm" \
      org.opencontainers.image.created="2025-09-18T17:14:14Z" \
      org.opencontainers.image.description="Elasticsearch application" \
      org.opencontainers.image.documentation="https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html" \
      org.opencontainers.image.source="https://github.com/favish/bitnami-resources" \
      org.opencontainers.image.title="elasticsearch" \
      org.opencontainers.image.vendor="Favish" \
      org.opencontainers.image.version="${ELASTICSEARCH_VERSION}"

ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="debian-12" \
    OS_NAME="linux" \
    ELASTICSEARCH_VERSION="${ELASTICSEARCH_VERSION}" \
    PATH="/opt/java/bin:/opt/elasticsearch/bin:/usr/local/bin:$PATH"

COPY prebuildfs /
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# Install required system packages and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    procps \
    zlib1g \
    wget \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install OpenJDK 21 from Eclipse Adoptium
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    gnupg \
    software-properties-common \
    && wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null \
    && echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends temurin-21-jdk \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/java \
    && ln -sf /usr/lib/jvm/temurin-21-jdk-* /opt/java/current

# Install yq
RUN ARCH=$(case ${TARGETARCH:-amd64} in \
        amd64) echo "amd64" ;; \
        arm64) echo "arm64" ;; \
        *) echo "amd64" ;; \
    esac) && \
    curl -L "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${ARCH}" -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# Download and install Elasticsearch
RUN mkdir -p /opt/elasticsearch && \
    curl -L "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTICSEARCH_VERSION}-linux-x86_64.tar.gz" | \
    tar -xz --strip-components=1 -C /opt/elasticsearch
RUN apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives
RUN chmod g+rwX /opt
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

COPY rootfs /

# Make scripts executable and create necessary directories
RUN chmod +x /opt/bitnami/scripts/elasticsearch/*.sh /opt/bitnami/scripts/java/*.sh /opt/bitnami/scripts/*.sh && \
    mkdir -p /opt/bitnami/elasticsearch/data /opt/bitnami/elasticsearch/logs /opt/bitnami/elasticsearch/config && \
    chown -R 1001:1001 /opt/bitnami/elasticsearch
ENV APP_VERSION="${ELASTICSEARCH_VERSION}" \
    ES_JAVA_HOME="/opt/bitnami/java" \
    IMAGE_REVISION="0" \
    JAVA_HOME="/opt/bitnami/java" \
    LD_LIBRARY_PATH="/opt/bitnami/elasticsearch/jdk/lib:/opt/bitnami/elasticsearch/jdk/lib/server"

EXPOSE 9200 9300

USER 1001
ENTRYPOINT [ "/opt/bitnami/scripts/elasticsearch/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/elasticsearch/run.sh" ]
