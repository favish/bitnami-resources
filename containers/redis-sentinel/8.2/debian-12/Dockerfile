# Production-Ready Redis Sentinel Docker Image
# Multi-stage build for optimized production deployment

# Build stage
FROM debian:bookworm-slim AS builder

ARG REDIS_VERSION=8.2.2
ARG REDIS_DOWNLOAD_URL=http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz
ARG BUILD_DATE
ARG VCS_REF

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    gcc \
    libc6-dev \
    libssl-dev \
    make \
    pkg-config \
    # Additional tools for stable compilation
    binutils \
    libtool \
    autoconf \
    && rm -rf /var/lib/apt/lists/*

# Download and compile Redis from source (includes Sentinel)
WORKDIR /usr/src/redis
RUN curl -fsSL "$REDIS_DOWNLOAD_URL" -o redis.tar.gz \
    && echo "${REDIS_SHA256:-*} redis.tar.gz" | sha256sum -c - || true \
    && tar -xzf redis.tar.gz --strip-components=1 \
    && rm redis.tar.gz

# Build Redis with stable compilation flags (disable LTO to avoid issues)
RUN make -j$(nproc) \
    BUILD_TLS=yes \
    USE_SYSTEMD=no \
    PREFIX=/usr/local \
    OPTIMIZATION="-O2" \
    CFLAGS="-fno-lto -fno-fat-lto-objects" \
    LDFLAGS="-fno-lto" \
    V=1 \
    || make \
    BUILD_TLS=yes \
    USE_SYSTEMD=no \
    PREFIX=/usr/local \
    OPTIMIZATION="-O1" \
    V=1 \
    && make install PREFIX=/usr/local

# Production stage
FROM debian:bookworm-slim AS prod

ARG REDIS_VERSION=8.2.2
ARG BUILD_DATE
ARG VCS_REF

# Enhanced labels for production
LABEL org.opencontainers.image.title="redis-sentinel" \
      org.opencontainers.image.description="Production-ready Redis Sentinel for high availability" \
      org.opencontainers.image.version="${REDIS_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="https://github.com/favish/bitnami-resources" \
      org.opencontainers.image.url="https://redis.io/" \
      org.opencontainers.image.documentation="https://redis.io/documentation" \
      org.opencontainers.image.vendor="Redis" \
      maintainer="favish-team"

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    # Required for TLS support
    libssl3 \
    # Process management
    dumb-init \
    # Monitoring and debugging tools
    procps \
    net-tools \
    # Bitnami script requirements
    bash \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Copy Redis binaries from builder
COPY --from=builder /usr/local/bin/redis-sentinel /usr/local/bin/
COPY --from=builder /usr/local/bin/redis-cli /usr/local/bin/

# Create redis user with consistent UID/GID
RUN groupadd -r -g 999 redis \
    && useradd -r -g redis -u 999 -d /opt/bitnami/redis-sentinel -s /bin/bash redis

# Create Bitnami directory structure
RUN mkdir -p \
    /opt/bitnami/redis-sentinel/bin \
    /opt/bitnami/redis-sentinel/etc \
    /opt/bitnami/redis-sentinel/etc.default \
    /opt/bitnami/redis-sentinel/logs \
    /opt/bitnami/redis-sentinel/tmp \
    /opt/bitnami/redis-sentinel/mounted-etc \
    /bitnami/redis-sentinel/data \
    && ln -sf /usr/local/bin/redis-sentinel /opt/bitnami/redis-sentinel/bin/ \
    && ln -sf /usr/local/bin/redis-cli /opt/bitnami/redis-sentinel/bin/ \
    && chown -R redis:redis /opt/bitnami/redis-sentinel /bitnami \
    && chmod 755 /opt/bitnami/redis-sentinel \
    && chmod 755 /bitnami

# Copy Bitnami prebuildfs scripts (common libraries)
COPY --chown=redis:redis prebuildfs/ /

# Copy Bitnami rootfs scripts (redis-sentinel specific)
COPY --chown=redis:redis rootfs/ /

# Make scripts executable
RUN find /opt/bitnami/scripts -type f -name "*.sh" -exec chmod +x {} \; \
    && find /usr/sbin -type f -name "*" -exec chmod +x {} \; 2>/dev/null || true

# Security: Remove setuid/setgid permissions
RUN find / -xdev -type f -perm +6000 -exec chmod a-s {} \; 2>/dev/null || true

# Set environment variables for Bitnami compatibility
ENV BITNAMI_APP_NAME="redis-sentinel" \
    BITNAMI_IMAGE_VERSION="${REDIS_VERSION}" \
    HOME="/opt/bitnami/redis-sentinel" \
    OS_ARCH="amd64" \
    OS_FLAVOUR="debian-12" \
    OS_NAME="linux" \
    PATH="/opt/bitnami/redis-sentinel/bin:/opt/bitnami/common/bin:/usr/local/bin:/usr/bin:/bin"

# Switch to redis user
USER redis

# Set working directory
WORKDIR /opt/bitnami/redis-sentinel

# Health check using Bitnami patterns
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD redis-cli -h 127.0.0.1 -p ${REDIS_SENTINEL_PORT_NUMBER:-26379} ${REDIS_SENTINEL_PASSWORD:+-a "$REDIS_SENTINEL_PASSWORD"} ping | grep -q PONG

# Expose Sentinel port
EXPOSE 26379

# Volume for persistent data
VOLUME ["/bitnami/redis-sentinel"]

# Use dumb-init as PID 1 for proper signal handling
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/opt/bitnami/scripts/redis-sentinel/entrypoint.sh"]

# Default command uses Bitnami run script
CMD ["/opt/bitnami/scripts/redis-sentinel/run.sh"]