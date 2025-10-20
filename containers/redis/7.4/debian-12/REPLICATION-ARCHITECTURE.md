# Redis Replication Architecture Guide

## Overview

Yes, this Redis setup **fully supports replication architecture** with multiple deployment modes:

- **Master-Slave Replication**: 1 master + multiple replicas
- **Redis Sentinel**: Automatic failover and monitoring  
- **Load Balancing**: Separate read/write traffic routing
- **High Availability**: Zero-downtime deployments

## Architecture Modes

### 1. Basic Master-Slave Replication

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Master    │────▶│  Replica 1  │     │  Replica 2  │
│             │     │             │     │             │
│ Read/Write  │     │ Read Only   │     │ Read Only   │
│ Port: 6379  │     │ Port: 6380  │     │ Port: 6381  │
└─────────────┘     └─────────────┘     └─────────────┘
```

**Features:**
- Asynchronous replication
- Read scaling across replicas
- Master handles all writes
- Automatic data synchronization

**Deployment:**
```bash
./deploy-replication.sh basic
```

### 2. Redis Sentinel (High Availability)

```
    ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
    │  Sentinel 1  │     │  Sentinel 2  │     │  Sentinel 3  │
    │ Port: 26379  │     │ Port: 26380  │     │ Port: 26381  │
    └──────┬───────┘     └──────┬───────┘     └──────┬───────┘
           │                    │                    │
           └────────────────────┼────────────────────┘
                               │
    ┌─────────────┐     ┌──────▼──────┐     ┌─────────────┐
    │   Master    │────▶│  Replica 1  │     │  Replica 2  │
    │             │     │             │     │             │
    │ Read/Write  │     │ Read Only   │     │ Read Only   │
    └─────────────┘     └─────────────┘     └─────────────┘
```

**Features:**
- Automatic master failover
- Health monitoring
- Quorum-based decision making
- Service discovery
- Split-brain prevention

**Deployment:**
```bash
./deploy-replication.sh sentinel
```

### 3. Full Production Stack

```
                        ┌──────────────┐
                        │   HAProxy    │
                        │ Load Balancer│
                        └──────┬───────┘
                               │
    ┌─────────────┐     ┌──────▼──────┐     ┌─────────────┐
    │   Master    │────▶│  Replica 1  │     │  Replica 2  │
    │             │     │             │     │             │
    │ Read/Write  │     │ Read Only   │     │ Read Only   │
    └─────────────┘     └─────────────┘     └─────────────┘
           │                    │                    │
    ┌──────▼──────┐     ┌──────▼──────┐     ┌──────▼──────┐
    │ Sentinel 1  │     │ Sentinel 2  │     │ Sentinel 3  │
    └─────────────┘     └─────────────┘     └─────────────┘
           │
    ┌──────▼──────┐
    │ Monitoring  │
    │  Exporter   │
    └─────────────┘
```

**Features:**
- Master-slave replication
- Sentinel monitoring
- Load balancing
- Prometheus metrics
- HAProxy statistics

**Deployment:**
```bash
./deploy-replication.sh full
```

## Replication Configuration

### Environment Variables

The Docker image supports comprehensive replication configuration through environment variables:

```bash
# Replication Mode
REDIS_MODE=master|replica|sentinel

# Master Configuration
REDIS_MIN_REPLICAS_TO_WRITE=1
REDIS_MIN_REPLICAS_MAX_LAG=10

# Replica Configuration  
REDIS_MASTER_HOST=redis-master
REDIS_MASTER_PORT=6379
REDIS_MASTER_PASSWORD=password
REDIS_REPLICA_SERVE_STALE_DATA=yes
REDIS_REPLICA_READ_ONLY=yes
REDIS_REPLICA_PRIORITY=100

# Replication Tuning
REDIS_REPL_DISKLESS_SYNC=no
REDIS_REPL_DISKLESS_SYNC_DELAY=5
REDIS_REPL_PING_REPLICA_PERIOD=10
REDIS_REPL_TIMEOUT=60
REDIS_REPL_BACKLOG_SIZE=1mb

# Sentinel Configuration
REDIS_SENTINEL_MASTER_NAME=mymaster
REDIS_SENTINEL_QUORUM=2
REDIS_SENTINEL_DOWN_AFTER=30000
REDIS_SENTINEL_FAILOVER_TIMEOUT=180000
REDIS_SENTINEL_PARALLEL_SYNCS=1
```

## Quick Start Examples

### 1. Deploy Basic Replication

```bash
# Clone and navigate
cd /path/to/redis/debian-12

# Deploy basic master-slave setup
./deploy-replication.sh basic

# Test replication
redis-cli -h localhost -p 6379 -a 'your_password' set test_key "hello"
redis-cli -h localhost -p 6380 -a 'your_password' get test_key  # Should return "hello"
```

### 2. Deploy with Sentinel

```bash
# Deploy with automatic failover
./deploy-replication.sh sentinel

# Connect via Sentinel (Python example)
from redis.sentinel import Sentinel
sentinel = Sentinel([('localhost', 26379), ('localhost', 26380)])
master = sentinel.master_for('mymaster', password='your_password')
```

### 3. Deploy Full Production Stack

```bash
# Deploy everything
./deploy-replication.sh full

# Access services
# Write operations: localhost:6382
# Read operations:  localhost:6383
# Monitoring:       localhost:9121/metrics
# HAProxy stats:    localhost:8404/stats
```

## Connection Examples

### Python with Master-Slave

```python
import redis

# Master connection (read/write)
master = redis.Redis(
    host='localhost',
    port=6379,
    password='your_password',
    decode_responses=True
)

# Replica connection (read-only)
replica = redis.Redis(
    host='localhost', 
    port=6380,
    password='your_password',
    decode_responses=True
)

# Write to master
master.set('user:123', '{"name": "John", "age": 30}')

# Read from replica (load distribution)
user_data = replica.get('user:123')
```

### Python with Sentinel

```python
from redis.sentinel import Sentinel

# Configure Sentinel
sentinel = Sentinel([
    ('localhost', 26379),
    ('localhost', 26380), 
    ('localhost', 26381)
])

# Get master and replica connections
master = sentinel.master_for('mymaster', password='your_password')
replica = sentinel.slave_for('mymaster', password='your_password')

# Automatic failover handling
try:
    master.set('key', 'value')
except redis.ConnectionError:
    # Sentinel will automatically discover new master
    pass
```

### Node.js with Replication

```javascript
const Redis = require('ioredis');

// Master-slave setup
const master = new Redis({
    host: 'localhost',
    port: 6379,
    password: 'your_password'
});

const replica = new Redis({
    host: 'localhost', 
    port: 6380,
    password: 'your_password'
});

// Sentinel setup
const sentinel = new Redis({
    sentinels: [
        { host: 'localhost', port: 26379 },
        { host: 'localhost', port: 26380 },
        { host: 'localhost', port: 26381 }
    ],
    name: 'mymaster',
    password: 'your_password'
});
```

## Performance Characteristics

### Throughput
- **Master**: Full read/write operations
- **Replicas**: Read-only, scales horizontally
- **Load Balancing**: 50-90% read traffic to replicas

### Latency
- **Replication Lag**: Typically < 10ms
- **Failover Time**: 30-60 seconds with Sentinel
- **Connection Discovery**: < 1 second

### Scaling
- **Read Scaling**: Linear with replica count
- **Write Scaling**: Single master bottleneck
- **Memory**: Independent per instance

## Monitoring

### Health Checks
```bash
# Check master health
docker-compose exec redis-master redis-cli ping

# Check replication status
docker-compose exec redis-master redis-cli info replication

# Check Sentinel status
docker-compose exec redis-sentinel-1 redis-cli -p 26379 sentinel masters
```

### Metrics (Prometheus)
- Connection count
- Memory usage
- Replication lag
- Command statistics
- Sentinel status

Available at: `http://localhost:9121/metrics`

## High Availability Features

### Automatic Failover
1. Sentinel detects master failure
2. Quorum reached (2/3 Sentinels agree)
3. Promote replica to master
4. Update client connections
5. Remaining replicas follow new master

### Split-Brain Prevention
- Minimum replica acknowledgment
- Quorum-based decisions
- Network partition handling

### Data Consistency
- Asynchronous replication (eventual consistency)
- Configurable sync policies
- Backlog for disconnected replicas

## Production Considerations

### Security
- Password authentication
- Network isolation
- TLS encryption support
- Non-root containers

### Resource Planning
- Master: 2GB RAM, 1 CPU
- Replicas: 1GB RAM, 0.5 CPU  
- Sentinels: 256MB RAM, 0.1 CPU

### Backup Strategy
- Master: Full RDB + AOF
- Replicas: Optional persistence
- Cross-region replication support

## Cleanup

```bash
# Remove all services
./deploy-replication.sh cleanup

# Or manually
docker-compose -f docker-compose.replication.yml down -v
```

This Redis setup provides enterprise-grade replication architecture with automatic failover, load balancing, and comprehensive monitoring - fully production-ready without any Bitnami dependencies.