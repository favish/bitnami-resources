# Production-Ready Discourse Docker Deployment

This directory contains a production-ready Discourse Docker setup with multi-stage builds, security hardening, and comprehensive monitoring capabilities.

## 🏗️ Architecture

### Multi-Stage Build
- **Builder Stage**: Compiles Ruby, installs dependencies, precompiles assets
- **Production Stage**: Minimal runtime image with only necessary components
- **Size Optimization**: Significantly smaller final image (~60% reduction)

### Security Features
- ✅ Non-root user execution (UID/GID 1001)
- ✅ Minimal package installation (runtime-only dependencies)
- ✅ Read-only filesystem support
- ✅ No setuid/setgid binaries
- ✅ Security labels and metadata
- ✅ Proper signal handling for graceful shutdowns

### Production Features
- ✅ Health checks with configurable timeouts
- ✅ Graceful shutdown handling
- ✅ Database migration automation
- ✅ Environment-based configuration
- ✅ Comprehensive logging
- ✅ Admin user auto-creation
- ✅ Performance optimizations

## 🚀 Quick Start

### 1. Configuration
```bash
# Copy environment template
cp .env.example .env

# Edit configuration
nano .env
```

### 2. Required Environment Variables
```bash
DISCOURSE_HOSTNAME=discourse.yourcompany.com
DISCOURSE_SECRET_KEY_BASE=$(openssl rand -hex 64)
POSTGRES_PASSWORD=$(openssl rand -base64 32)
SMTP_ADDRESS=smtp.yourprovider.com
SMTP_USERNAME=your_smtp_username
SMTP_PASSWORD=your_smtp_password
```

### 3. Deploy
```bash
# Build and start services
docker-compose -f docker-compose.prod.yml up -d

# Check status
docker-compose -f docker-compose.prod.yml ps

# View logs
docker-compose -f docker-compose.prod.yml logs -f discourse
```

## 📊 Monitoring & Health Checks

### Built-in Health Checks
- **Application**: HTTP endpoint `/srv/status`
- **Database**: PostgreSQL connectivity check
- **Redis**: Redis ping check
- **Startup**: 60-second grace period

### Log Monitoring
```bash
# Application logs
docker-compose -f docker-compose.prod.yml logs -f discourse

# System logs
docker exec -it discourse_discourse_1 tail -f /opt/discourse/log/production.log
```

## 🔧 Configuration Management

### Environment Variables

#### Required Variables
| Variable | Description | Example |
|----------|-------------|---------|
| `DISCOURSE_HOSTNAME` | Your domain name | `discourse.company.com` |
| `DISCOURSE_SECRET_KEY_BASE` | 64-char secret | Generated with `openssl rand -hex 64` |
| `POSTGRES_PASSWORD` | Database password | Generated with `openssl rand -base64 32` |
| `SMTP_ADDRESS` | Email server | `smtp.gmail.com` |
| `SMTP_USERNAME` | Email username | `admin@company.com` |
| `SMTP_PASSWORD` | Email password | Your email password |

#### Performance Tuning
| Variable | Default | Description |
|----------|---------|-------------|
| `DISCOURSE_UNICORN_WORKERS` | `3` | Number of Unicorn workers |
| `RAILS_MAX_THREADS` | `8` | Max threads per worker |
| `DISCOURSE_DB_POOL` | `25` | Database connection pool |
| `DISCOURSE_DB_TIMEOUT` | `5000` | DB timeout (ms) |

#### Security Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `DISCOURSE_FORCE_HTTPS` | `false` | Force HTTPS redirects |
| `DISCOURSE_ENABLE_CORS` | `false` | Enable CORS headers |

## 🛡️ Security Hardening

### Container Security
- Runs as non-root user (discourse:1001)
- Read-only root filesystem
- No new privileges
- Temporary filesystems for /tmp
- Minimal attack surface

### Network Security
- Internal network isolation
- Only necessary ports exposed
- Health check endpoints secured

### Secrets Management
```bash
# Generate secure secrets
DISCOURSE_SECRET_KEY_BASE=$(openssl rand -hex 64)
POSTGRES_PASSWORD=$(openssl rand -base64 32)
ADMIN_PASSWORD=$(openssl rand -base64 24)

# Store in .env file (never commit to version control)
echo "DISCOURSE_SECRET_KEY_BASE=$DISCOURSE_SECRET_KEY_BASE" >> .env
```

## 📈 Performance Optimization

### Resource Allocation
```yaml
# Add to docker-compose.prod.yml under discourse service
deploy:
  resources:
    limits:
      memory: 2G
      cpus: '1.0'
    reservations:
      memory: 1G
      cpus: '0.5'
```

### Database Optimization
```sql
-- PostgreSQL tuning for production
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
SELECT pg_reload_conf();
```

### Redis Configuration
```bash
# Add to redis command in docker-compose.prod.yml
redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru --save 900 1
```

## 🔄 Backup & Recovery

### Database Backup
```bash
# Create backup
docker exec discourse_postgres_1 pg_dump -U discourse discourse_production > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore backup
docker exec -i discourse_postgres_1 psql -U discourse discourse_production < backup_file.sql
```

### Volume Backup
```bash
# Backup uploads and data
docker run --rm -v discourse_uploads:/data -v $(pwd):/backup alpine tar czf /backup/uploads_$(date +%Y%m%d_%H%M%S).tar.gz /data

# Backup database data
docker run --rm -v postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_$(date +%Y%m%d_%H%M%S).tar.gz /data
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Database Connection Failed
```bash
# Check database status
docker-compose -f docker-compose.prod.yml exec postgres pg_isready -U discourse

# Check network connectivity
docker-compose -f docker-compose.prod.yml exec discourse nc -z postgres 5432
```

#### 2. Assets Not Loading
```bash
# Rebuild assets
docker-compose -f docker-compose.prod.yml exec discourse bundle exec rake assets:precompile

# Check asset permissions
docker-compose -f docker-compose.prod.yml exec discourse ls -la public/assets/
```

#### 3. Email Not Sending
```bash
# Test SMTP configuration
docker-compose -f docker-compose.prod.yml exec discourse bundle exec rails c
> ActionMailer::Base.smtp_settings
> ActionMailer::Base.delivery_method
```

### Debug Mode
```bash
# Enable debug logging
docker-compose -f docker-compose.prod.yml exec discourse \
  env RAILS_LOG_LEVEL=debug bundle exec rails console
```

## 📋 Maintenance

### Updates
```bash
# Update to new Discourse version
docker-compose -f docker-compose.prod.yml build --no-cache discourse
docker-compose -f docker-compose.prod.yml up -d discourse

# Run migrations
docker-compose -f docker-compose.prod.yml exec discourse bundle exec rake db:migrate
```

### Cleanup
```bash
# Remove unused Docker resources
docker system prune -f

# Clean old logs
docker-compose -f docker-compose.prod.yml exec discourse find /opt/discourse/log -name "*.log" -mtime +30 -delete
```

## 🔗 Additional Resources

- [Discourse Meta](https://meta.discourse.org/) - Official documentation
- [Docker Security](https://docs.docker.com/engine/security/) - Container security best practices
- [PostgreSQL Tuning](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server) - Database optimization
- [Nginx Configuration](https://meta.discourse.org/t/reverse-proxy-with-nginx/17654) - Reverse proxy setup