# Production-Ready Redis Exporter Docker Image
# Multi-stage build for optimized production deployment

# Build stage
FROM debian:bookworm-slim AS builder

ARG REDIS_EXPORTER_VERSION=1.79.0
ARG BUILD_DATE
ARG VCS_REF
ARG TARGETARCH

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Download Redis Exporter binary
WORKDIR /tmp
RUN ARCH=$(case ${TARGETARCH:-amd64} in \
        amd64) echo "amd64" ;; \
        arm64) echo "arm64" ;; \
        *) echo "amd64" ;; \
    esac) && \
    curl -L "https://github.com/oliver006/redis_exporter/releases/download/v${REDIS_EXPORTER_VERSION}/redis_exporter-v${REDIS_EXPORTER_VERSION}.linux-${ARCH}.tar.gz" | \
    tar -xz --strip-components=1 && \
    chmod +x redis_exporter

# Production stage  
FROM debian:bookworm-slim AS prod

ARG REDIS_EXPORTER_VERSION=1.79.0
ARG BUILD_DATE
ARG VCS_REF

# Enhanced labels for production
LABEL org.opencontainers.image.title="redis-exporter" \
      org.opencontainers.image.description="Production-ready Redis Exporter for Prometheus metrics" \
      org.opencontainers.image.version="${REDIS_EXPORTER_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="https://github.com/favish/bitnami-resources" \
      org.opencontainers.image.url="https://github.com/oliver006/redis_exporter" \
      org.opencontainers.image.documentation="https://github.com/oliver006/redis_exporter" \
      org.opencontainers.image.vendor="Redis" \
      maintainer="favish-team"

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    # Process management
    dumb-init \
    # Monitoring tools
    procps \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Copy Redis Exporter binary from builder
COPY --from=builder /tmp/redis_exporter /usr/local/bin/redis_exporter

# Create redis-exporter user with consistent UID/GID
RUN groupadd -r -g 999 redis-exporter \
    && useradd -r -g redis-exporter -u 999 -d /var/lib/redis-exporter -s /bin/bash redis-exporter

# Create directories with proper permissions
RUN mkdir -p /var/lib/redis-exporter \
    && chown -R redis-exporter:redis-exporter /var/lib/redis-exporter \
    && chmod 755 /var/lib/redis-exporter

# Security: Remove setuid/setgid permissions
RUN find / -xdev -type f -perm +6000 -exec chmod a-s {} \; 2>/dev/null || true

# Health check script
COPY <<'EOF' /usr/local/bin/redis-exporter-health-check.sh
#!/bin/bash
set -euo pipefail

PORT="${REDIS_EXPORTER_PORT:-9121}"
TIMEOUT="${REDIS_EXPORTER_HEALTH_TIMEOUT:-5}"

# Check if the exporter is responding
if curl -sf --max-time "$TIMEOUT" "http://localhost:$PORT/metrics" > /dev/null 2>&1; then
    exit 0
else
    echo "Health check failed: Redis Exporter not responding on port $PORT"
    exit 1
fi
EOF

RUN chmod +x /usr/local/bin/redis-exporter-health-check.sh

# Production environment variables with defaults
ENV REDIS_EXPORTER_VERSION="${REDIS_EXPORTER_VERSION}" \
    # Network Configuration
    REDIS_EXPORTER_PORT=9121 \
    REDIS_EXPORTER_WEB_LISTEN_ADDRESS=":9121" \
    REDIS_EXPORTER_WEB_TELEMETRY_PATH="/metrics" \
    # Redis Connection
    REDIS_ADDR="redis://localhost:6379" \
    REDIS_PASSWORD="" \
    REDIS_USER="" \
    REDIS_PASSWORD_FILE="" \
    # Exporter Configuration
    REDIS_EXPORTER_LOG_FORMAT="txt" \
    REDIS_EXPORTER_DEBUG=false \
    REDIS_EXPORTER_CHECK_KEYS="" \
    REDIS_EXPORTER_CHECK_SINGLE_KEYS="" \
    REDIS_EXPORTER_CHECK_STREAMS="" \
    REDIS_EXPORTER_CHECK_SINGLE_STREAMS="" \
    REDIS_EXPORTER_COUNT_KEYS="" \
    REDIS_EXPORTER_SCRIPT="" \
    REDIS_EXPORTER_CONNECTION_TIMEOUT="15s" \
    REDIS_EXPORTER_PING_ON_CONNECT=false \
    REDIS_EXPORTER_INCL_SYSTEM_METRICS=false \
    REDIS_EXPORTER_SKIP_TLS_VERIFICATION=false \
    # Health Check
    REDIS_EXPORTER_HEALTH_TIMEOUT=5

# Switch to redis-exporter user
USER redis-exporter

# Set working directory
WORKDIR /var/lib/redis-exporter

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD /usr/local/bin/redis-exporter-health-check.sh

# Expose Redis Exporter port
EXPOSE 9121

# Use dumb-init as PID 1 for proper signal handling
ENTRYPOINT ["/usr/bin/dumb-init", "--", "redis_exporter"]

# Default command (can be overridden)
CMD []
