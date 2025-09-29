# Custom OS Shell Container - Production Ready
# Multi-stage build for optimized production deployment

# Build stage for compiling tools
FROM debian:bookworm-slim AS builder

ARG TARGETARCH
ARG YQ_VERSION=v4.47.1
ARG BUILD_DATE
ARG VCS_REF

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Download and install yq (YAML processor)
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") \
    && curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# Production stage
FROM debian:bookworm-slim AS prod

ARG BUILD_DATE
ARG VCS_REF
ARG TARGETARCH

# Enhanced labels for production
LABEL org.opencontainers.image.title="os-shell" \
      org.opencontainers.image.description="Production-ready OS shell utilities container" \
      org.opencontainers.image.version="12" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="https://github.com/favish/bitnami-resources" \
      org.opencontainers.image.documentation="https://github.com/favish/bitnami-resources" \
      org.opencontainers.image.vendor="Favish" \
      maintainer="production-team"

# Security and performance environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="debian-12" \
    OS_NAME="linux"

# Copy helper scripts from prebuildfs
COPY prebuildfs /

# Set execute permissions for scripts
RUN chmod +x /usr/sbin/install_packages /usr/sbin/uninstall_packages /usr/sbin/run-script

# Set proper shell with error handling
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# Install essential packages and utilities
RUN /usr/sbin/install_packages \
    # Core system utilities
    ca-certificates \
    curl \
    wget \
    jq \
    procps \
    netcat-traditional \
    telnet \
    # Network and debugging tools
    dnsutils \
    iputils-ping \
    traceroute \
    # File and text processing
    file \
    less \
    nano \
    vim-tiny \
    # Archive and compression
    unzip \
    zip \
    tar \
    gzip \
    # Additional useful tools
    findutils \
    coreutils \
    util-linux \
    grep \
    sed \
    gawk \
    && apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy yq from builder stage
COPY --from=builder /usr/local/bin/yq /usr/local/bin/yq

# Create wait-for-port utility
COPY <<'EOF' /usr/local/bin/wait-for-port
#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 [-h host] [-p port] [-t timeout] [-s sleep_interval]"
    echo "  -h host: Host to check (default: localhost)"
    echo "  -p port: Port to check (required)"
    echo "  -t timeout: Timeout in seconds (default: 30)"
    echo "  -s sleep_interval: Sleep interval between checks (default: 1)"
    exit 1
}

host="localhost"
port=""
timeout=30
sleep_interval=1

while getopts "h:p:t:s:" opt; do
    case $opt in
        h) host="$OPTARG" ;;
        p) port="$OPTARG" ;;
        t) timeout="$OPTARG" ;;
        s) sleep_interval="$OPTARG" ;;
        *) usage ;;
    esac
done

if [ -z "$port" ]; then
    echo "Error: Port is required"
    usage
fi

echo "Waiting for $host:$port to be available..."
start_time=$(date +%s)

while ! nc -z "$host" "$port" 2>/dev/null; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    if [ $elapsed -ge $timeout ]; then
        echo "Timeout: $host:$port is not available after $timeout seconds"
        exit 1
    fi
    
    sleep "$sleep_interval"
done

echo "$host:$port is available!"
EOF

# Create render-template utility (basic template rendering)
COPY <<'EOF' /usr/local/bin/render-template
#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 [-t template_file] [-o output_file]"
    echo "  -t template_file: Template file to process"
    echo "  -o output_file: Output file (default: stdout)"
    echo "Templates support basic variable substitution: {{VAR_NAME}}"
    exit 1
}

template_file=""
output_file=""

while getopts "t:o:" opt; do
    case $opt in
        t) template_file="$OPTARG" ;;
        o) output_file="$OPTARG" ;;
        *) usage ;;
    esac
done

if [ -z "$template_file" ]; then
    echo "Error: Template file is required"
    usage
fi

if [ ! -f "$template_file" ]; then
    echo "Error: Template file '$template_file' not found"
    exit 1
fi

# Simple template rendering using envsubst-like functionality
content=$(cat "$template_file")

# Replace {{VAR_NAME}} with environment variable values
for var in $(env | cut -d= -f1); do
    value=$(printenv "$var" | sed 's/[[\.*^$()+?{|]/\\&/g')
    content=$(echo "$content" | sed "s/{{$var}}/$value/g")
done

if [ -n "$output_file" ]; then
    echo "$content" > "$output_file"
    echo "Template rendered to: $output_file"
else
    echo "$content"
fi
EOF

# Create ini-file utility (basic INI file manipulation)
COPY <<'EOF' /usr/local/bin/ini-file
#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 [-f ini_file] [-s section] [-k key] [-v value] [-d]"
    echo "  -f ini_file: INI file to manipulate"
    echo "  -s section: Section name"
    echo "  -k key: Key name"
    echo "  -v value: Value to set (omit to read)"
    echo "  -d: Delete key"
    exit 1
}

ini_file=""
section=""
key=""
value=""
delete_key=false

while getopts "f:s:k:v:d" opt; do
    case $opt in
        f) ini_file="$OPTARG" ;;
        s) section="$OPTARG" ;;
        k) key="$OPTARG" ;;
        v) value="$OPTARG" ;;
        d) delete_key=true ;;
        *) usage ;;
    esac
done

if [ -z "$ini_file" ] || [ -z "$section" ] || [ -z "$key" ]; then
    usage
fi

# Create file if it doesn't exist
if [ ! -f "$ini_file" ]; then
    touch "$ini_file"
fi

# Basic INI file operations
if $delete_key; then
    # Delete key
    sed -i "/^\[$section\]/,/^\[/{/^$key=/d;}" "$ini_file"
elif [ -n "$value" ]; then
    # Set value
    if grep -q "^\[$section\]" "$ini_file"; then
        # Section exists
        if grep -A 100 "^\[$section\]" "$ini_file" | grep -q "^$key="; then
            # Key exists, update it
            sed -i "/^\[$section\]/,/^\[/{s/^$key=.*/$key=$value/;}" "$ini_file"
        else
            # Key doesn't exist, add it
            sed -i "/^\[$section\]/a $key=$value" "$ini_file"
        fi
    else
        # Section doesn't exist, add it
        echo -e "\n[$section]" >> "$ini_file"
        echo "$key=$value" >> "$ini_file"
    fi
else
    # Read value
    grep -A 100 "^\[$section\]" "$ini_file" | grep "^$key=" | cut -d= -f2- | head -n1
fi
EOF

# Create scuttle utility (basic service mesh sidecar)
COPY <<'EOF' /usr/local/bin/scuttle
#!/bin/bash
set -euo pipefail

# Basic scuttle implementation for service mesh compatibility
# This is a simplified version that handles basic sidecar scenarios

SCUTTLE_LOGGING=${SCUTTLE_LOGGING:-true}
GENERIC_QUIT_ENDPOINTS=${GENERIC_QUIT_ENDPOINTS:-}
ISTIO_QUIT_API=${ISTIO_QUIT_API:-http://127.0.0.1:15000/quitquitquit}
NEVER_KILL_ISTIO=${NEVER_KILL_ISTIO:-false}
NEVER_KILL_ISTIO_ON_FAILURE=${NEVER_KILL_ISTIO_ON_FAILURE:-false}
START_WITHOUT_ENVOY=${START_WITHOUT_ENVOY:-false}

log() {
    if [ "$SCUTTLE_LOGGING" = "true" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
    fi
}

# Wait for Istio proxy if needed
if [ "$START_WITHOUT_ENVOY" != "true" ]; then
    log "Waiting for Istio proxy to be ready..."
    wait-for-port -h 127.0.0.1 -p 15000 -t 30 || {
        log "Istio proxy not available, continuing anyway..."
    }
fi

log "Starting main process: $*"

# Execute the main command
"$@" &
MAIN_PID=$!

# Function to cleanup
cleanup() {
    log "Received signal, cleaning up..."
    
    # Kill main process
    if kill -0 "$MAIN_PID" 2>/dev/null; then
        log "Stopping main process (PID: $MAIN_PID)"
        kill -TERM "$MAIN_PID" 2>/dev/null || true
        wait "$MAIN_PID" 2>/dev/null || true
    fi
    
    # Stop Istio proxy if configured
    if [ "$NEVER_KILL_ISTIO" != "true" ]; then
        log "Stopping Istio proxy..."
        curl -X POST "$ISTIO_QUIT_API" 2>/dev/null || true
        
        # Also try generic quit endpoints
        if [ -n "$GENERIC_QUIT_ENDPOINTS" ]; then
            IFS=',' read -ra ENDPOINTS <<< "$GENERIC_QUIT_ENDPOINTS"
            for endpoint in "${ENDPOINTS[@]}"; do
                log "Calling quit endpoint: $endpoint"
                curl -X POST "$endpoint" 2>/dev/null || true
            done
        fi
    fi
    
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT SIGQUIT

# Wait for main process
wait "$MAIN_PID"
MAIN_EXIT_CODE=$?

log "Main process exited with code: $MAIN_EXIT_CODE"

# Handle Istio cleanup based on exit code
if [ $MAIN_EXIT_CODE -ne 0 ] && [ "$NEVER_KILL_ISTIO_ON_FAILURE" = "true" ]; then
    log "Main process failed, but NEVER_KILL_ISTIO_ON_FAILURE is true, not stopping Istio"
else
    cleanup
fi

exit $MAIN_EXIT_CODE
EOF

# Make all utilities executable
RUN chmod +x /usr/local/bin/wait-for-port \
    /usr/local/bin/render-template \
    /usr/local/bin/ini-file \
    /usr/local/bin/scuttle \
    /usr/local/bin/yq

# Create system directories
RUN mkdir -p /opt/favish/common/bin \
    && ln -sf /usr/local/bin/yq /opt/favish/common/bin/yq \
    && ln -sf /usr/local/bin/wait-for-port /opt/favish/common/bin/wait-for-port \
    && ln -sf /usr/local/bin/render-template /opt/favish/common/bin/render-template \
    && ln -sf /usr/local/bin/ini-file /opt/favish/common/bin/ini-file \
    && ln -sf /usr/local/bin/scuttle /opt/favish/common/bin/scuttle

# Security: Remove setuid/setgid permissions
RUN find / -xdev -type f -perm +6000 -exec chmod a-s {} \; 2>/dev/null || true

# Production environment variables
ENV APP_VERSION="12" \
    FAVISH_APP_NAME="os-shell" \
    PATH="/opt/favish/common/bin:/usr/local/bin:$PATH"

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD [ "test", "-x", "/usr/local/bin/yq" ]

# Use non-root user for security
USER 1001

# Default command
CMD ["/bin/bash"]
