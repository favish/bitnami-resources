# Production-Ready Redis Docker Image
# Multi-stage build for optimized production deployment

# Build stage
FROM debian:bookworm-slim AS builder

ARG REDIS_VERSION=7.4.0
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

# Download and compile Redis from source
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

# Create redis user and directories
RUN groupadd -r -g 999 redis \
    && useradd -r -g redis -u 999 -d /var/lib/redis -s /bin/bash redis

# Production stage
FROM debian:bookworm-slim AS prod

ARG REDIS_VERSION=7.4.0
ARG BUILD_DATE
ARG VCS_REF

# Enhanced labels for production
LABEL org.opencontainers.image.title="redis" \
      org.opencontainers.image.description="Production-ready Redis in-memory data store" \
      org.opencontainers.image.version="${REDIS_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="https://github.com/favish/bitnami-resources" \
      org.opencontainers.image.url="https://redis.io/" \
      org.opencontainers.image.documentation="https://redis.io/documentation" \
      org.opencontainers.image.vendor="Redis" \
      maintainer="favish-team"

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    # Required for TLS support
    libssl3 \
    # Process management
    dumb-init \
    # Monitoring tools
    procps \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Copy Redis binaries from builder
COPY --from=builder /usr/local/bin/redis-* /usr/local/bin/

# Create redis user with consistent UID/GID
RUN groupadd -r -g 999 redis \
    && useradd -r -g redis -u 999 -d /var/lib/redis -s /bin/bash redis

# Create directories with proper permissions
RUN mkdir -p \
    /var/lib/redis \
    /var/log/redis \
    /etc/redis \
    /usr/local/etc/redis \
    && chown -R redis:redis /var/lib/redis /var/log/redis /etc/redis /usr/local/etc/redis \
    && chmod 755 /var/lib/redis \
    && chmod 755 /var/log/redis

# Security: Remove setuid/setgid permissions
RUN find / -xdev -type f -perm +6000 -exec chmod a-s {} \; 2>/dev/null || true

# Create production-ready entrypoint script
COPY <<'EOF' /usr/local/bin/redis-entrypoint.sh
#!/bin/bash
set -euo pipefail

# Function to handle shutdown signals
cleanup() {
    echo "Received shutdown signal, stopping Redis gracefully..."
    if [ -n "${REDIS_PID:-}" ]; then
        # Send SHUTDOWN command to Redis
        redis-cli -p "${REDIS_PORT:-6379}" ${REDIS_PASSWORD:+-a "$REDIS_PASSWORD"} SHUTDOWN NOSAVE 2>/dev/null || true
        # Wait for process to exit
        wait "$REDIS_PID" 2>/dev/null || true
    fi
    exit 0
}

# Set up signal handlers
trap cleanup TERM INT QUIT

# Generate Redis configuration
generate_redis_config() {
    local config_file="/usr/local/etc/redis/redis.conf"
    local mode="${REDIS_MODE:-standalone}"
    
    if [ "$mode" = "sentinel" ]; then
        generate_sentinel_config
        return
    fi
    
    cat > "$config_file" << CONF_EOF
# Redis Configuration - Generated at runtime

# Network
bind ${REDIS_BIND:-0.0.0.0}
port ${REDIS_PORT:-6379}
tcp-backlog ${REDIS_TCP_BACKLOG:-511}
timeout ${REDIS_TIMEOUT:-0}
tcp-keepalive ${REDIS_TCP_KEEPALIVE:-300}

# General
daemonize no
supervised no
pidfile /var/run/redis/redis.pid
loglevel ${REDIS_LOGLEVEL:-notice}
logfile ""
databases ${REDIS_DATABASES:-16}

# Security
$([ -n "${REDIS_PASSWORD:-}" ] && echo "requirepass $REDIS_PASSWORD" || echo "# No password set")
$([ "${REDIS_PROTECTED_MODE:-yes}" = "yes" ] && echo "protected-mode yes" || echo "protected-mode no")

# Replication Configuration
$([ -n "${REDIS_MASTER_HOST:-}" ] && cat << REPL_CONF
# This instance is a replica
replicaof ${REDIS_MASTER_HOST} ${REDIS_MASTER_PORT:-6379}
$([ -n "${REDIS_MASTER_PASSWORD:-}" ] && echo "masterauth $REDIS_MASTER_PASSWORD")
replica-serve-stale-data ${REDIS_REPLICA_SERVE_STALE_DATA:-yes}
replica-read-only ${REDIS_REPLICA_READ_ONLY:-yes}
repl-diskless-sync ${REDIS_REPL_DISKLESS_SYNC:-no}
repl-diskless-sync-delay ${REDIS_REPL_DISKLESS_SYNC_DELAY:-5}
repl-ping-replica-period ${REDIS_REPL_PING_REPLICA_PERIOD:-10}
repl-timeout ${REDIS_REPL_TIMEOUT:-60}
repl-disable-tcp-nodelay ${REDIS_REPL_DISABLE_TCP_NODELAY:-no}
repl-backlog-size ${REDIS_REPL_BACKLOG_SIZE:-1mb}
repl-backlog-ttl ${REDIS_REPL_BACKLOG_TTL:-3600}
replica-priority ${REDIS_REPLICA_PRIORITY:-100}
min-replicas-to-write ${REDIS_MIN_REPLICAS_TO_WRITE:-0}
min-replicas-max-lag ${REDIS_MIN_REPLICAS_MAX_LAG:-10}
REPL_CONF
)

# Memory Management
maxmemory ${REDIS_MAXMEMORY:-0}
maxmemory-policy ${REDIS_MAXMEMORY_POLICY:-noeviction}
maxmemory-samples ${REDIS_MAXMEMORY_SAMPLES:-5}

# Persistence - AOF
appendonly ${REDIS_AOF_ENABLED:-yes}
appendfilename ${REDIS_AOF_FILENAME:-appendonly.aof}
appendfsync ${REDIS_AOF_FSYNC:-everysec}
no-appendfsync-on-rewrite ${REDIS_AOF_NO_FSYNC_ON_REWRITE:-no}
auto-aof-rewrite-percentage ${REDIS_AOF_REWRITE_PERCENTAGE:-100}
auto-aof-rewrite-min-size ${REDIS_AOF_REWRITE_MIN_SIZE:-64mb}

# Persistence - RDB
save ${REDIS_SAVE:-900 1 300 10 60 10000}
rdbcompression ${REDIS_RDB_COMPRESSION:-yes}
rdbchecksum ${REDIS_RDB_CHECKSUM:-yes}
dbfilename ${REDIS_RDB_FILENAME:-dump.rdb}
dir /var/lib/redis

# Slow Log
slowlog-log-slower-than ${REDIS_SLOWLOG_LOG_SLOWER_THAN:-10000}
slowlog-max-len ${REDIS_SLOWLOG_MAX_LEN:-128}

# Latency Monitoring
latency-monitor-threshold ${REDIS_LATENCY_MONITOR_THRESHOLD:-0}

# Advanced Config
hash-max-ziplist-entries ${REDIS_HASH_MAX_ZIPLIST_ENTRIES:-512}
hash-max-ziplist-value ${REDIS_HASH_MAX_ZIPLIST_VALUE:-64}
list-max-ziplist-size ${REDIS_LIST_MAX_ZIPLIST_SIZE:--2}
list-compress-depth ${REDIS_LIST_COMPRESS_DEPTH:-0}
set-max-intset-entries ${REDIS_SET_MAX_INTSET_ENTRIES:-512}
zset-max-ziplist-entries ${REDIS_ZSET_MAX_ZIPLIST_ENTRIES:-128}
zset-max-ziplist-value ${REDIS_ZSET_MAX_ZIPLIST_VALUE:-64}
hll-sparse-max-bytes ${REDIS_HLL_SPARSE_MAX_BYTES:-3000}
stream-node-max-bytes ${REDIS_STREAM_NODE_MAX_BYTES:-4096}
stream-node-max-entries ${REDIS_STREAM_NODE_MAX_ENTRIES:-100}

# TLS Configuration (if enabled)
$([ "${REDIS_TLS_ENABLED:-false}" = "true" ] && cat << TLS_CONF
port 0
tls-port ${REDIS_TLS_PORT:-6380}
tls-cert-file ${REDIS_TLS_CERT_FILE:-/etc/redis/tls/redis.crt}
tls-key-file ${REDIS_TLS_KEY_FILE:-/etc/redis/tls/redis.key}
tls-ca-cert-file ${REDIS_TLS_CA_CERT_FILE:-/etc/redis/tls/ca.crt}
tls-protocols ${REDIS_TLS_PROTOCOLS:-TLSv1.2 TLSv1.3}
TLS_CONF
)

# Client Output Buffer Limits
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60

CONF_EOF

    echo "Redis configuration generated at $config_file"
}

# Generate Sentinel configuration
generate_sentinel_config() {
    local config_file="/usr/local/etc/redis/sentinel.conf"
    local port="${REDIS_SENTINEL_PORT:-26379}"
    local master_name="${REDIS_SENTINEL_MASTER_NAME:-mymaster}"
    local master_host="${REDIS_SENTINEL_MASTER_HOST:-127.0.0.1}"
    local master_port="${REDIS_SENTINEL_MASTER_PORT:-6379}"
    local quorum="${REDIS_SENTINEL_QUORUM:-1}"
    
    cat > "$config_file" << SENTINEL_CONF
# Redis Sentinel Configuration - Generated at runtime

# Basic Sentinel settings
port $port
sentinel announce-ip ${REDIS_SENTINEL_ANNOUNCE_IP:-}
sentinel announce-port ${REDIS_SENTINEL_ANNOUNCE_PORT:-$port}

# Master monitoring
sentinel monitor $master_name $master_host $master_port $quorum

# Authentication
$([ -n "${REDIS_PASSWORD:-}" ] && echo "sentinel auth-pass $master_name $REDIS_PASSWORD")

# Timeouts and thresholds
sentinel down-after-milliseconds $master_name ${REDIS_SENTINEL_DOWN_AFTER:-30000}
sentinel parallel-syncs $master_name ${REDIS_SENTINEL_PARALLEL_SYNCS:-1}
sentinel failover-timeout $master_name ${REDIS_SENTINEL_FAILOVER_TIMEOUT:-180000}

# Notification scripts
$([ -n "${REDIS_SENTINEL_NOTIFICATION_SCRIPT:-}" ] && echo "sentinel notification-script $master_name $REDIS_SENTINEL_NOTIFICATION_SCRIPT")
$([ -n "${REDIS_SENTINEL_CLIENT_RECONFIG_SCRIPT:-}" ] && echo "sentinel client-reconfig-script $master_name $REDIS_SENTINEL_CLIENT_RECONFIG_SCRIPT")

# Logging
loglevel ${REDIS_LOGLEVEL:-notice}
logfile ""

SENTINEL_CONF

    echo "Sentinel configuration generated at $config_file"
}

# Environment validation
validate_environment() {
    # Validate numeric values
    if [ -n "${REDIS_PORT:-}" ] && ! [[ "$REDIS_PORT" =~ ^[0-9]+$ ]]; then
        echo "ERROR: REDIS_PORT must be a number"
        exit 1
    fi
    
    if [ -n "${REDIS_DATABASES:-}" ] && ! [[ "$REDIS_DATABASES" =~ ^[0-9]+$ ]]; then
        echo "ERROR: REDIS_DATABASES must be a number"
        exit 1
    fi
    
    # Validate memory policy
    if [ -n "${REDIS_MAXMEMORY_POLICY:-}" ]; then
        valid_policies="volatile-lru allkeys-lru volatile-lfu allkeys-lfu volatile-random allkeys-random volatile-ttl noeviction"
        if [[ ! " $valid_policies " =~ " ${REDIS_MAXMEMORY_POLICY} " ]]; then
            echo "ERROR: Invalid REDIS_MAXMEMORY_POLICY: $REDIS_MAXMEMORY_POLICY"
            echo "Valid policies: $valid_policies"
            exit 1
        fi
    fi
}

# Create PID directory
mkdir -p /var/run/redis
chown redis:redis /var/run/redis

# Validate environment
validate_environment

# Generate configuration
generate_redis_config

# Change ownership of data directory
chown -R redis:redis /var/lib/redis

echo "Starting Redis..."

# Determine the mode and start appropriate service
mode="${REDIS_MODE:-standalone}"

case "$mode" in
    "sentinel")
        echo "Starting Redis Sentinel..."
        exec redis-sentinel /usr/local/etc/redis/sentinel.conf &
        ;;
    "replica"|"slave")
        echo "Starting Redis as replica of ${REDIS_MASTER_HOST}:${REDIS_MASTER_PORT:-6379}..."
        exec redis-server /usr/local/etc/redis/redis.conf &
        ;;
    "master"|"standalone"|*)
        echo "Starting Redis as master/standalone..."
        exec redis-server /usr/local/etc/redis/redis.conf &
        ;;
esac

REDIS_PID=$!
echo "Redis started with PID: $REDIS_PID"

# Wait for the process
wait "$REDIS_PID"
EOF

RUN chmod +x /usr/local/bin/redis-entrypoint.sh

# Health check script
COPY <<'EOF' /usr/local/bin/redis-health-check.sh
#!/bin/bash
set -euo pipefail

PORT="${REDIS_PORT:-6379}"
TIMEOUT="${REDIS_HEALTH_TIMEOUT:-5}"
PASSWORD="${REDIS_PASSWORD:-}"

# Build redis-cli command
REDIS_CLI_CMD="redis-cli -h 127.0.0.1 -p $PORT"
if [ -n "$PASSWORD" ]; then
    REDIS_CLI_CMD="$REDIS_CLI_CMD -a $PASSWORD"
fi

# Test Redis connectivity and responsiveness
if timeout "$TIMEOUT" $REDIS_CLI_CMD ping | grep -q PONG; then
    exit 0
else
    echo "Health check failed: Redis not responding on port $PORT"
    exit 1
fi
EOF

RUN chmod +x /usr/local/bin/redis-health-check.sh

# Redis monitoring script
COPY <<'EOF' /usr/local/bin/redis-info.sh
#!/bin/bash
set -euo pipefail

PORT="${REDIS_PORT:-6379}"
PASSWORD="${REDIS_PASSWORD:-}"

# Build redis-cli command
REDIS_CLI_CMD="redis-cli -h 127.0.0.1 -p $PORT"
if [ -n "$PASSWORD" ]; then
    REDIS_CLI_CMD="$REDIS_CLI_CMD -a $PASSWORD"
fi

echo "=== Redis Server Information ==="
$REDIS_CLI_CMD INFO server

echo -e "\n=== Redis Memory Information ==="
$REDIS_CLI_CMD INFO memory

echo -e "\n=== Redis Stats ==="
$REDIS_CLI_CMD INFO stats

echo -e "\n=== Redis Replication ==="
$REDIS_CLI_CMD INFO replication

echo -e "\n=== Connected Clients ==="
$REDIS_CLI_CMD CLIENT LIST
EOF

RUN chmod +x /usr/local/bin/redis-info.sh

# Production environment variables with defaults
ENV REDIS_VERSION="${REDIS_VERSION}" \
    # Mode Configuration
    REDIS_MODE=standalone \
    # Network Configuration
    REDIS_PORT=6379 \
    REDIS_BIND=0.0.0.0 \
    REDIS_TCP_BACKLOG=511 \
    REDIS_TIMEOUT=0 \
    REDIS_TCP_KEEPALIVE=300 \
    # Security
    REDIS_PASSWORD="" \
    REDIS_PROTECTED_MODE=yes \
    # Replication Configuration
    REDIS_MASTER_HOST="" \
    REDIS_MASTER_PORT=6379 \
    REDIS_MASTER_PASSWORD="" \
    REDIS_REPLICA_SERVE_STALE_DATA=yes \
    REDIS_REPLICA_READ_ONLY=yes \
    REDIS_REPL_DISKLESS_SYNC=no \
    REDIS_REPL_DISKLESS_SYNC_DELAY=5 \
    REDIS_REPL_PING_REPLICA_PERIOD=10 \
    REDIS_REPL_TIMEOUT=60 \
    REDIS_REPL_DISABLE_TCP_NODELAY=no \
    REDIS_REPL_BACKLOG_SIZE=1mb \
    REDIS_REPL_BACKLOG_TTL=3600 \
    REDIS_REPLICA_PRIORITY=100 \
    REDIS_MIN_REPLICAS_TO_WRITE=0 \
    REDIS_MIN_REPLICAS_MAX_LAG=10 \
    # Sentinel Configuration
    REDIS_SENTINEL_PORT=26379 \
    REDIS_SENTINEL_MASTER_NAME=mymaster \
    REDIS_SENTINEL_MASTER_HOST=127.0.0.1 \
    REDIS_SENTINEL_MASTER_PORT=6379 \
    REDIS_SENTINEL_QUORUM=1 \
    REDIS_SENTINEL_DOWN_AFTER=30000 \
    REDIS_SENTINEL_PARALLEL_SYNCS=1 \
    REDIS_SENTINEL_FAILOVER_TIMEOUT=180000 \
    REDIS_SENTINEL_ANNOUNCE_IP="" \
    REDIS_SENTINEL_ANNOUNCE_PORT="" \
    REDIS_SENTINEL_NOTIFICATION_SCRIPT="" \
    REDIS_SENTINEL_CLIENT_RECONFIG_SCRIPT="" \
    # Memory Management
    REDIS_MAXMEMORY=0 \
    REDIS_MAXMEMORY_POLICY=noeviction \
    REDIS_MAXMEMORY_SAMPLES=5 \
    # Persistence
    REDIS_AOF_ENABLED=yes \
    REDIS_AOF_FILENAME=appendonly.aof \
    REDIS_AOF_FSYNC=everysec \
    REDIS_AOF_NO_FSYNC_ON_REWRITE=no \
    REDIS_AOF_REWRITE_PERCENTAGE=100 \
    REDIS_AOF_REWRITE_MIN_SIZE=64mb \
    REDIS_SAVE="900 1 300 10 60 10000" \
    REDIS_RDB_COMPRESSION=yes \
    REDIS_RDB_CHECKSUM=yes \
    REDIS_RDB_FILENAME=dump.rdb \
    # Logging
    REDIS_LOGLEVEL=notice \
    # Database
    REDIS_DATABASES=16 \
    # Performance Monitoring
    REDIS_SLOWLOG_LOG_SLOWER_THAN=10000 \
    REDIS_SLOWLOG_MAX_LEN=128 \
    REDIS_LATENCY_MONITOR_THRESHOLD=0 \
    # TLS (disabled by default)
    REDIS_TLS_ENABLED=false \
    REDIS_TLS_PORT=6380 \
    # Health Check
    REDIS_HEALTH_TIMEOUT=5

# Switch to redis user
USER redis

# Set working directory
WORKDIR /var/lib/redis

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD /usr/local/bin/redis-health-check.sh

# Expose Redis port
EXPOSE 6379

# Volume for persistent data
VOLUME ["/var/lib/redis"]

# Use dumb-init as PID 1 for proper signal handling
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/redis-entrypoint.sh"]

# Default command (can be overridden)
CMD []