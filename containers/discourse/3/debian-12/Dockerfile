# Production-Ready Discourse Docker Image
# Multi-stage build for optimized production deployment

# Build stage
FROM debian:bookworm-slim AS builder

ARG TARGETARCH
ARG DISCOURSE_VERSION=3.5.0
ARG DISCOURSE_REPOSITORY=https://github.com/discourse/discourse.git
ARG BUILD_DATE
ARG VCS_REF

# Install basic dependencies first
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    wget \
    # Ruby dependencies
    libffi-dev \
    libgmp-dev \
    libreadline-dev \
    libssl-dev \
    libyaml-dev \
    zlib1g-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup Node.js repository and install Node.js with package managers
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    && corepack enable \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Enable Corepack and install modern Yarn
RUN corepack enable \
    && corepack prepare yarn@stable --activate

# Install Ruby via rbenv (build stage only)
ENV RBENV_ROOT="/opt/rbenv"
ENV PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"

RUN git clone --depth=1 https://github.com/rbenv/rbenv.git $RBENV_ROOT \
    && git clone --depth=1 https://github.com/rbenv/ruby-build.git $RBENV_ROOT/plugins/ruby-build \
    && $RBENV_ROOT/bin/rbenv install 3.3.9 \
    && $RBENV_ROOT/bin/rbenv global 3.3.9 \
    && $RBENV_ROOT/bin/rbenv rehash \
    && gem update --system --no-document \
    && gem install bundler --no-document

# Create discourse user for build
RUN groupadd -r discourse && useradd -r -g discourse -d /opt/discourse -s /bin/bash discourse

# Install Discourse source
WORKDIR /opt/discourse
RUN git clone --depth=1 --branch=v${DISCOURSE_VERSION} ${DISCOURSE_REPOSITORY} . \
    && chown -R discourse:discourse /opt/discourse

USER discourse

# Install Ruby dependencies
RUN bundle config set --local deployment 'true' \
    && bundle config set --local without 'development test' \
    && bundle config set --local path 'vendor/bundle' \
    && bundle install --jobs $(nproc)

# Install Node.js dependencies and precompile assets with mock services
ENV NODE_ENV=production
ENV RAILS_ENV=production
RUN corepack enable pnpm \
    && pnpm install --prod --frozen-lockfile \
    && SKIP_DB_AND_REDIS=1 \
       PRECOMPILE_ONLY=1 \
       bundle exec rake assets:precompile \
    && pnpm store prune

# Clean up build artifacts
RUN rm -rf .git \
    && rm -rf node_modules/.cache \
    && rm -rf tmp/cache \
    && find vendor/bundle -name "*.o" -delete \
    && find vendor/bundle -name "*.c" -delete

# Production stage
FROM debian:bookworm-slim AS prod

ARG DISCOURSE_VERSION=3.5.0
ARG BUILD_DATE
ARG VCS_REF

# Enhanced labels for production
LABEL org.opencontainers.image.title="discourse" \
      org.opencontainers.image.description="Production-ready Discourse forum software" \
      org.opencontainers.image.version="${DISCOURSE_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="https://github.com/favish/bitnami-resources" \
      org.opencontainers.image.url="https://www.discourse.org/" \
      org.opencontainers.image.documentation="https://meta.discourse.org/" \
      org.opencontainers.image.vendor="Discourse" \
      maintainer="production-team"

# Security and performance environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    DISCOURSE_VERSION="${DISCOURSE_VERSION}" \
    RAILS_ENV=production \
    NODE_ENV=production \
    RAILS_SERVE_STATIC_FILES=true \
    RAILS_LOG_TO_STDOUT=true

# Install runtime dependencies (including gnupg for Node.js setup)
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Essential runtime packages
    ca-certificates \
    curl \
    gnupg \
    # Ruby runtime dependencies
    libffi8 \
    libgmp10 \
    libreadline8 \
    libssl3 \
    libyaml-0-2 \
    zlib1g \
    # Image processing (production optimized)
    imagemagick \
    gifsicle \
    jpegoptim \
    optipng \
    pngcrush \
    pngquant \
    advancecomp \
    # System libraries needed by gems
    libbrotli1 \
    libicu72 \
    libxml2 \
    libxslt1.1 \
    libpq5 \
    # Utilities
    file \
    # Security: remove unnecessary packages and clean up
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Setup Node.js repository and install (after gnupg is available)
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/* \
    && corepack enable \
    && corepack prepare yarn@stable --activate

# Install Ruby from builder stage via copying precompiled version
COPY --from=builder /opt/rbenv /opt/rbenv
ENV RBENV_ROOT="/opt/rbenv"
ENV PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"

# Security: Create discourse user with specific UID/GID for consistency
RUN groupadd -r -g 1001 discourse \
    && useradd -r -u 1001 -g discourse -d /opt/discourse -s /bin/bash discourse \
    && mkdir -p /opt/discourse \
    && chown discourse:discourse /opt/discourse

# Copy application from builder
COPY --from=builder --chown=discourse:discourse /opt/discourse /opt/discourse

# Set up runtime directories with proper permissions
RUN mkdir -p \
    /opt/discourse/log \
    /opt/discourse/tmp/pids \
    /opt/discourse/tmp/sockets \
    /opt/discourse/tmp/cache \
    /opt/discourse/public/uploads \
    /opt/discourse/public/backups \
    && chown -R discourse:discourse /opt/discourse \
    && chmod -R 755 /opt/discourse \
    && chmod -R 750 /opt/discourse/log \
    && chmod -R 750 /opt/discourse/tmp

# Security: Remove setuid/setgid permissions
RUN find / -xdev -type f -perm +6000 -exec chmod a-s {} \; 2>/dev/null || true

# Create production-ready entrypoint script
COPY <<'EOF' /usr/local/bin/discourse-entrypoint.sh
#!/bin/bash
set -euo pipefail

# Function to handle shutdown signals
cleanup() {
    echo "Received shutdown signal, stopping Discourse gracefully..."
    if [ -n "${DISCOURSE_PID:-}" ]; then
        kill -TERM "$DISCOURSE_PID" 2>/dev/null || true
        wait "$DISCOURSE_PID" 2>/dev/null || true
    fi
    exit 0
}

# Set up signal handlers
trap cleanup TERM INT QUIT

# Environment validation
required_vars=(
    "DISCOURSE_HOSTNAME"
    "DISCOURSE_DB_HOST"
    "DISCOURSE_DB_NAME"
    "DISCOURSE_DB_USERNAME"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo "ERROR: Required environment variable $var is not set"
        exit 1
    fi
done

# Initialize rbenv
eval "$(/opt/rbenv/bin/rbenv init -)"

# Change to discourse directory
cd /opt/discourse

# Database connectivity check
echo "Checking database connectivity..."
timeout 30 bash -c "
until bundle exec rails runner 'ActiveRecord::Base.connection.execute(\"SELECT 1\")' > /dev/null 2>&1; do
    echo 'Waiting for database to be ready...'
    sleep 2
done
"

# Run database migrations if needed
if [ "${DISCOURSE_SKIP_MIGRATIONS:-false}" != "true" ]; then
    echo "Running database migrations..."
    bundle exec rake db:migrate
fi

# Create admin user if specified
if [ -n "${DISCOURSE_ADMIN_EMAIL:-}" ] && [ -n "${DISCOURSE_ADMIN_PASSWORD:-}" ]; then
    echo "Creating admin user if not exists..."
    bundle exec rails runner "
        unless User.find_by(email: ENV['DISCOURSE_ADMIN_EMAIL'])
            User.create!(
                email: ENV['DISCOURSE_ADMIN_EMAIL'],
                password: ENV['DISCOURSE_ADMIN_PASSWORD'],
                username: ENV['DISCOURSE_ADMIN_USERNAME'] || 'admin',
                admin: true,
                active: true,
                approved: true
            )
            puts 'Admin user created successfully'
        else
            puts 'Admin user already exists'
        end
    " || echo "Admin user creation skipped or failed"
fi

echo "Starting Discourse..."

# Start Discourse with proper signal handling
bundle exec rails server \
    -b 0.0.0.0 \
    -p "${DISCOURSE_PORT:-3000}" \
    -e production &

DISCOURSE_PID=$!
echo "Discourse started with PID: $DISCOURSE_PID"

# Wait for the process
wait "$DISCOURSE_PID"
EOF

RUN chmod +x /usr/local/bin/discourse-entrypoint.sh

# Health check script
COPY <<'EOF' /usr/local/bin/health-check.sh
#!/bin/bash
set -euo pipefail

PORT="${DISCOURSE_PORT:-3000}"
TIMEOUT="${HEALTH_CHECK_TIMEOUT:-10}"

# Check if the application is responding
if curl -sf --max-time "$TIMEOUT" "http://localhost:$PORT/srv/status" > /dev/null 2>&1; then
    exit 0
else
    echo "Health check failed: Discourse not responding on port $PORT"
    exit 1
fi
EOF

RUN chmod +x /usr/local/bin/health-check.sh

# Production environment variables with defaults
ENV DISCOURSE_VERSION="${DISCOURSE_VERSION}" \
    RAILS_ENV=production \
    NODE_ENV=production \
    PATH="/opt/rbenv/bin:/opt/rbenv/shims:$PATH" \
    # Discourse configuration
    DISCOURSE_PORT=3000 \
    DISCOURSE_RELATIVE_URL_ROOT="" \
    DISCOURSE_FORCE_HTTPS=false \
    DISCOURSE_CDN_URL="" \
    # Database configuration (to be overridden by Helm)
    DISCOURSE_DB_HOST="" \
    DISCOURSE_DB_PORT=5432 \
    DISCOURSE_DB_NAME=discourse \
    DISCOURSE_DB_USERNAME=discourse \
    DISCOURSE_DB_PASSWORD="" \
    DISCOURSE_DB_POOL=25 \
    DISCOURSE_DB_TIMEOUT=5000 \
    # Redis configuration (to be overridden by Helm)
    DISCOURSE_REDIS_HOST="" \
    DISCOURSE_REDIS_PORT=6379 \
    DISCOURSE_REDIS_DB=0 \
    DISCOURSE_REDIS_PASSWORD="" \
    # Email configuration (to be overridden by Helm)
    DISCOURSE_SMTP_ADDRESS="" \
    DISCOURSE_SMTP_PORT=587 \
    DISCOURSE_SMTP_USER_NAME="" \
    DISCOURSE_SMTP_PASSWORD="" \
    DISCOURSE_SMTP_ENABLE_START_TLS=true \
    DISCOURSE_SMTP_AUTHENTICATION=plain \
    # Security settings (to be overridden by Helm)
    DISCOURSE_SECRET_KEY_BASE="" \
    DISCOURSE_HOSTNAME="" \
    # Performance settings
    DISCOURSE_UNICORN_WORKERS=3 \
    DISCOURSE_UNICORN_TIMEOUT=30 \
    RAILS_MAX_THREADS=8 \
    # Feature flags
    DISCOURSE_ENABLE_CORS=false \
    DISCOURSE_SKIP_MIGRATIONS=false \
    # Monitoring
    HEALTH_CHECK_TIMEOUT=10

# Switch to discourse user for final setup
USER discourse

WORKDIR /opt/discourse

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/health-check.sh

# Expose port
EXPOSE 3000

# Volume for persistent data
VOLUME ["/opt/discourse/public/uploads", "/opt/discourse/public/backups", "/opt/discourse/log"]

# Production entrypoint
ENTRYPOINT ["/usr/local/bin/discourse-entrypoint.sh"]

# Default command (can be overridden)
CMD []
