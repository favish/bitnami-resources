# Production-Ready Redis Docker Deployment

This directory contains a production-ready Redis Docker setup with multi-stage builds, comprehensive security hardening, and advanced monitoring capabilities.

## 🏗️ Architecture

### Multi-Stage Build
- **Builder Stage**: Compiles Redis from source with optimizations
- **Production Stage**: Minimal runtime image with only necessary components
- **Size Optimization**: Significantly smaller final image compared to full Redis builds
- **Security**: Build tools removed from final image

### Security Features
- ✅ Non-root user execution (UID/GID 999)
- ✅ Minimal package installation (runtime-only dependencies)
- ✅ Read-only filesystem support
- ✅ No setuid/setgid binaries
- ✅ TLS encryption support
- ✅ Proper signal handling for graceful shutdowns
- ✅ Comprehensive security labels

### Production Features
- ✅ Environment-based configuration (no config files)
- ✅ Health checks with configurable timeouts
- ✅ Graceful shutdown handling
- ✅ Comprehensive logging
- ✅ Performance monitoring hooks
- ✅ Memory management optimizations
- ✅ Persistence configuration options
- ✅ High availability support (Redis Sentinel)

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
# Generate secure password
REDIS_PASSWORD=$(openssl rand -base64 32)
```

### 3. Deploy
```bash
# Initialize and deploy
./deploy.sh init
./deploy.sh deploy

# Check status
./deploy.sh status

# View logs
./deploy.sh logs
```

## 📊 Deployment Options

### Standard Deployment
```bash
./deploy.sh deploy
```

### With Monitoring (Prometheus)
```bash
./deploy.sh deploy-monitoring
```

### High Availability (with Sentinel)
```bash
./deploy.sh deploy-ha
```

## 🔧 Configuration Management

### Environment Variables

#### Security Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_PASSWORD` | `""` | Redis authentication password |
| `REDIS_PROTECTED_MODE` | `yes` | Enable protected mode |

#### Memory Management
| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_MAXMEMORY` | `0` | Maximum memory usage (0 = unlimited) |
| `REDIS_MAXMEMORY_POLICY` | `noeviction` | Memory eviction policy |
| `REDIS_MAXMEMORY_SAMPLES` | `5` | Samples for LRU algorithm |

#### Persistence Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_AOF_ENABLED` | `yes` | Enable Append Only File |
| `REDIS_AOF_FSYNC` | `everysec` | AOF fsync policy |
| `REDIS_SAVE` | `900 1 300 10 60 10000` | RDB save points |
| `REDIS_RDB_COMPRESSION` | `yes` | Enable RDB compression |

#### Performance Tuning
| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_TCP_KEEPALIVE` | `300` | TCP keepalive timeout |
| `REDIS_SLOWLOG_LOG_SLOWER_THAN` | `10000` | Slow query threshold (microseconds) |
| `REDIS_SLOWLOG_MAX_LEN` | `128` | Max slow log entries |

#### TLS Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_TLS_ENABLED` | `false` | Enable TLS encryption |
| `REDIS_TLS_PORT` | `6380` | TLS port |
| `REDIS_TLS_CERT_FILE` | `/etc/redis/tls/redis.crt` | TLS certificate file |
| `REDIS_TLS_KEY_FILE` | `/etc/redis/tls/redis.key` | TLS private key file |

## 🛡️ Security Hardening

### Container Security
- Runs as non-root user (redis:999)
- Read-only root filesystem
- No new privileges
- Temporary filesystems for writable areas
- Minimal attack surface

### Network Security
- Password authentication required
- Protected mode enabled by default
- TLS encryption support
- Network policy compatibility

### Secrets Management
```bash
# Generate secure password
REDIS_PASSWORD=$(openssl rand -base64 32)

# Store in environment file (never commit to version control)
echo "REDIS_PASSWORD=$REDIS_PASSWORD" >> .env
```

## 📈 Performance Optimization

### Memory Configuration
```bash
# Example for 2GB system
REDIS_MAXMEMORY=1gb
REDIS_MAXMEMORY_POLICY=allkeys-lru
```

### Persistence Optimization
```bash
# For write-heavy workloads
REDIS_AOF_ENABLED=yes
REDIS_AOF_FSYNC=everysec

# For read-heavy workloads
REDIS_SAVE="900 1 300 10 60 10000"
REDIS_RDB_COMPRESSION=yes
```

### Resource Recommendations

| Use Case | Memory | CPU | Storage |
|----------|--------|-----|---------|
| Cache Only | 512MB-2GB | 0.1-0.5 cores | Minimal |
| Session Store | 1GB-4GB | 0.2-1 cores | 10-50GB |
| Message Queue | 2GB-8GB | 0.5-2 cores | 50-200GB |
| Database | 4GB+ | 1+ cores | 100GB+ |

## 📊 Monitoring & Observability

### Built-in Health Checks
- **Liveness**: Redis PING command
- **Readiness**: Redis connectivity check
- **Startup**: 5-second grace period

### Redis Metrics
The image includes built-in monitoring capabilities:

```bash
# Get comprehensive Redis info
./deploy.sh status

# Performance test
./deploy.sh test

# Access Redis CLI
./deploy.sh cli
```

### Prometheus Integration
When deployed with monitoring:
- Redis Exporter on port 9121
- Comprehensive metrics collection
- Grafana dashboard compatibility

### Key Metrics to Monitor
- Memory usage (`used_memory`)
- Connected clients (`connected_clients`)
- Commands per second (`instantaneous_ops_per_sec`)
- Hit rate calculation
- Slow query log
- Persistence status

## 🔄 Backup & Recovery

### Automated Backup
```bash
# Create backup
./deploy.sh backup

# Manual backup trigger
docker-compose -f docker-compose.prod.yml exec redis redis-cli BGSAVE
```

### Backup Types
1. **RDB Snapshots**: Point-in-time binary dumps
2. **AOF Files**: Append-only file for durability
3. **Volume Backup**: Complete data directory backup

### Recovery Process
```bash
# Stop Redis
./deploy.sh stop

# Restore data files
cp backup/dump.rdb data/redis/
cp backup/appendonly.aof data/redis/

# Start Redis
./deploy.sh deploy
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Memory Issues
```bash
# Check memory usage
docker-compose -f docker-compose.prod.yml exec redis redis-cli INFO memory

# Monitor memory in real-time
docker-compose -f docker-compose.prod.yml exec redis redis-cli --stat
```

#### 2. Connection Issues
```bash
# Test connectivity
docker-compose -f docker-compose.prod.yml exec redis redis-cli ping

# Check client connections
docker-compose -f docker-compose.prod.yml exec redis redis-cli CLIENT LIST
```

#### 3. Performance Issues
```bash
# Check slow queries
docker-compose -f docker-compose.prod.yml exec redis redis-cli SLOWLOG GET 10

# Monitor latency
docker-compose -f docker-compose.prod.yml exec redis redis-cli --latency
```

#### 4. Persistence Issues
```bash
# Check last save time
docker-compose -f docker-compose.prod.yml exec redis redis-cli LASTSAVE

# Force background save
docker-compose -f docker-compose.prod.yml exec redis redis-cli BGSAVE
```

### Debug Mode
```bash
# Enable debug logging
REDIS_LOGLEVEL=debug ./deploy.sh deploy

# Monitor commands
docker-compose -f docker-compose.prod.yml exec redis redis-cli MONITOR
```

## 🔗 High Availability Setup

### Redis Sentinel Configuration
```bash
# Deploy with Sentinel
./deploy.sh deploy-ha
```

### Sentinel Features
- Automatic failover
- Configuration provider
- Notification system
- Multiple sentinel instances

### Client Configuration for HA
```python
# Python example
import redis.sentinel

sentinel = redis.sentinel.Sentinel([
    ('localhost', 26379),
    ('localhost', 26380),
    ('localhost', 26381)
])

# Get master connection
master = sentinel.master_for('mymaster', socket_timeout=0.1)
```

## 📋 Maintenance

### Updates
```bash
# Build new version
./deploy.sh build

# Deploy update
./deploy.sh deploy

# Verify deployment
./deploy.sh status
```

### Health Monitoring
```bash
# Continuous health check
watch -n 5 './deploy.sh status'

# Log monitoring
./deploy.sh logs
```

### Cleanup
```bash
# Stop services
./deploy.sh stop

# Remove containers and volumes
docker-compose -f docker-compose.prod.yml down -v

# Clean Docker system
docker system prune -f
```

## 🔗 Additional Resources

- [Redis Documentation](https://redis.io/documentation) - Official Redis documentation
- [Redis Best Practices](https://redis.io/topics/memory-optimization) - Memory optimization guide
- [Redis Security](https://redis.io/topics/security) - Security best practices
- [Redis Monitoring](https://redis.io/topics/latency-monitor) - Monitoring and debugging
- [Redis Persistence](https://redis.io/topics/persistence) - Persistence configuration
- [Redis Sentinel](https://redis.io/topics/sentinel) - High availability guide

## 💡 Production Tips

1. **Memory Management**: Always set `maxmemory` in production
2. **Persistence**: Choose between RDB and AOF based on your needs
3. **Monitoring**: Set up proper monitoring and alerting
4. **Security**: Always use password authentication
5. **Backups**: Implement regular backup strategy
6. **Updates**: Test updates in staging environment first
7. **Scaling**: Consider Redis Cluster for horizontal scaling

This Redis setup is now production-ready with enterprise-grade security, monitoring, and operational features!