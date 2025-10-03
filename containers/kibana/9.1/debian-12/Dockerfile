# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

FROM debian:bookworm-slim

# Build arguments
ARG KIBANA_VERSION="9.1.4"
ARG YQ_VERSION="4.47.2"
ARG TARGETARCH

LABEL org.opencontainers.image.base.name="debian:bookworm" \
  org.opencontainers.image.created="2025-09-18T18:52:28Z" \
  org.opencontainers.image.description="Kibana application" \
  org.opencontainers.image.documentation="https://www.elastic.co/guide/en/kibana/current/index.html" \
  org.opencontainers.image.source="https://github.com/favish/bitnami-resources" \
  org.opencontainers.image.title="kibana" \
  org.opencontainers.image.vendor="Favish" \
  org.opencontainers.image.version="${KIBANA_VERSION}"

ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="debian-12" \
    OS_NAME="linux" \
    KIBANA_VERSION="${KIBANA_VERSION}" \
    PATH="/opt/bitnami/kibana/bin:/usr/local/bin:$PATH"

COPY prebuildfs /
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]
# Install required system packages and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    procps \
    gnupg \
    wget \
    libnss3 \
    libexpat1 \
    libstdc++6 \
    libgcc-s1 \
    && rm -rf /var/lib/apt/lists/*

# Install yq (arch aware)
RUN ARCH=$(case ${TARGETARCH:-amd64} in \
        amd64) echo "amd64" ;; \
        arm64) echo "arm64" ;; \
        *) echo "amd64" ;; \
    esac) && \
    curl -L "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${ARCH}" -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# Download and install Kibana
RUN mkdir -p /opt/bitnami/kibana && \
    ARCH_DIR=$(case ${TARGETARCH:-amd64} in \
        amd64) echo "x86_64" ;; \
        arm64) echo "aarch64" ;; \
        *) echo "x86_64" ;; \
    esac) && \
    curl -L "https://artifacts.elastic.co/downloads/kibana/kibana-${KIBANA_VERSION}-linux-${ARCH_DIR}.tar.gz" | \
    tar -xz --strip-components=1 -C /opt/bitnami/kibana
RUN apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives
RUN chmod g+rwX /opt/bitnami
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

COPY rootfs /
# Ensure scripts are executable before running postunpack
RUN chmod +x /opt/bitnami/scripts/kibana/*.sh && \
    /opt/bitnami/scripts/kibana/postunpack.sh
ENV APP_VERSION="${KIBANA_VERSION}" \
  BITNAMI_APP_NAME="kibana" \
  IMAGE_REVISION="0"

EXPOSE 5601

USER 1001
ENTRYPOINT [ "/opt/bitnami/scripts/kibana/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/kibana/run.sh" ]
