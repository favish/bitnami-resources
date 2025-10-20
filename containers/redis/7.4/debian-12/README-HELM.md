# Production Redis Docker Image for Helm/Kubernetes Deployment

This production-ready Redis Docker image is optimized for deployment with Helm charts in Kubernetes environments.

## 🎯 Key Features for Kubernetes

- **Environment Variable Configuration**: All Redis configuration via environment variables
- **Security Hardening**: Non-root user, minimal packages, secure defaults
- **Health Checks**: Built-in Kubernetes-compatible health endpoints
- **Graceful Shutdown**: Proper SIGTERM handling for pod termination
- **Multi-stage Build**: Optimized image size for faster deployment
- **TLS Support**: Optional TLS encryption for secure connections

## 🔧 Required Environment Variables

### Basic Configuration
```yaml
env:
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: redis-secrets
        key: redis-password
  - name: REDIS_MAXMEMORY
    value: "512mb"
  - name: REDIS_MAXMEMORY_POLICY
    value: "allkeys-lru"
```

### Security Settings
```yaml
env:
  - name: REDIS_PROTECTED_MODE
    value: "yes"
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: redis-secrets
        key: password
```

### Persistence Configuration
```yaml
env:
  - name: REDIS_AOF_ENABLED
    value: "yes"
  - name: REDIS_AOF_FSYNC
    value: "everysec"
  - name: REDIS_SAVE
    value: "900 1 300 10 60 10000"
```

## 📋 Complete Helm Values Example

```yaml
image:
  repository: your-registry/redis
  tag: "7.4.0"
  pullPolicy: IfNotPresent

replicaCount: 1

service:
  type: ClusterIP
  port: 6379

env:
  # Security
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: redis-secrets
        key: password
  - name: REDIS_PROTECTED_MODE
    value: "yes"
  
  # Memory Management
  - name: REDIS_MAXMEMORY
    value: "1gb"
  - name: REDIS_MAXMEMORY_POLICY
    value: "allkeys-lru"
  - name: REDIS_MAXMEMORY_SAMPLES
    value: "5"
  
  # Persistence
  - name: REDIS_AOF_ENABLED
    value: "yes"
  - name: REDIS_AOF_FSYNC
    value: "everysec"
  - name: REDIS_SAVE
    value: "900 1 300 10 60 10000"
  - name: REDIS_RDB_COMPRESSION
    value: "yes"
  - name: REDIS_RDB_CHECKSUM
    value: "yes"
  
  # Performance
  - name: REDIS_TCP_KEEPALIVE
    value: "300"
  - name: REDIS_SLOWLOG_LOG_SLOWER_THAN
    value: "10000"
  - name: REDIS_SLOWLOG_MAX_LEN
    value: "128"
  
  # Logging
  - name: REDIS_LOGLEVEL
    value: "notice"
  
  # Database
  - name: REDIS_DATABASES
    value: "16"

resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 100m
    memory: 512Mi

livenessProbe:
  exec:
    command:
      - /usr/local/bin/redis-health-check.sh
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  exec:
    command:
      - /usr/local/bin/redis-health-check.sh
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

securityContext:
  runAsNonRoot: true
  runAsUser: 999
  runAsGroup: 999
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL

volumeMounts:
  - name: redis-data
    mountPath: /var/lib/redis
  - name: redis-tmp
    mountPath: /tmp
  - name: redis-run
    mountPath: /var/run/redis

volumes:
  - name: redis-data
    persistentVolumeClaim:
      claimName: redis-pvc
  - name: redis-tmp
    emptyDir:
      sizeLimit: 100Mi
  - name: redis-run
    emptyDir:
      sizeLimit: 10Mi

persistence:
  enabled: true
  size: 10Gi
  storageClass: fast-ssd
  accessMode: ReadWriteOnce

# High Availability with Redis Sentinel
sentinel:
  enabled: false
  replicaCount: 3
  service:
    type: ClusterIP
    port: 26379
  env:
    - name: REDIS_SENTINEL_MASTER_NAME
      value: "mymaster"
    - name: REDIS_SENTINEL_QUORUM
      value: "2"
    - name: REDIS_SENTINEL_DOWN_AFTER
      value: "30000"
    - name: REDIS_SENTINEL_FAILOVER_TIMEOUT
      value: "180000"

# Monitoring with Redis Exporter
monitoring:
  enabled: false
  serviceMonitor:
    enabled: true
    interval: 30s
    scrapeTimeout: 10s
```

## 🔐 Secrets Management

Create the required secrets:

```bash
# Generate secure password
REDIS_PASSWORD=$(openssl rand -base64 32)

# Create the secret
kubectl create secret generic redis-secrets \
  --from-literal=password="$REDIS_PASSWORD"
```

## 🚀 Deployment Commands

### Single Instance Deployment
```bash
# Build and push image
docker build -f Dockerfile.prod -t your-registry/redis:7.4.0 .
docker push your-registry/redis:7.4.0

# Deploy with Helm
helm install redis ./redis-chart \
  --values values.yaml \
  --namespace redis \
  --create-namespace
```

### High Availability Deployment
```bash
# Deploy Redis with Sentinel
helm install redis ./redis-chart \
  --values values.yaml \
  --set sentinel.enabled=true \
  --set replicaCount=3 \
  --namespace redis \
  --create-namespace
```

## 📊 Monitoring and Observability

### Redis Exporter for Prometheus
```yaml
monitoring:
  enabled: true
  image:
    repository: oliver006/redis_exporter
    tag: latest
  env:
    - name: REDIS_ADDR
      value: "redis://localhost:6379"
    - name: REDIS_PASSWORD
      valueFrom:
        secretKeyRef:
          name: redis-secrets
          key: password
```

### Grafana Dashboard
Use the official Redis Grafana dashboard (ID: 763) for comprehensive monitoring.

### Key Metrics to Monitor
- Memory usage (`used_memory`)
- Connected clients (`connected_clients`)
- Commands per second (`instantaneous_ops_per_sec`)
- Hit rate (`keyspace_hits / (keyspace_hits + keyspace_misses)`)
- Replication lag (for master-slave setups)

## 🛡️ Security Configuration

### TLS Encryption
```yaml
env:
  - name: REDIS_TLS_ENABLED
    value: "true"
  - name: REDIS_TLS_PORT
    value: "6380"
  - name: REDIS_TLS_CERT_FILE
    value: "/etc/redis/tls/redis.crt"
  - name: REDIS_TLS_KEY_FILE
    value: "/etc/redis/tls/redis.key"
  - name: REDIS_TLS_CA_CERT_FILE
    value: "/etc/redis/tls/ca.crt"

volumeMounts:
  - name: redis-tls
    mountPath: /etc/redis/tls
    readOnly: true

volumes:
  - name: redis-tls
    secret:
      secretName: redis-tls-certs
```

### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: redis-network-policy
spec:
  podSelector:
    matchLabels:
      app: redis
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: allowed-clients
    ports:
    - protocol: TCP
      port: 6379
```

## ⚡ Performance Tuning

### Memory Optimization
```yaml
env:
  # Set appropriate memory limit
  - name: REDIS_MAXMEMORY
    value: "2gb"
  
  # Choose eviction policy based on use case
  - name: REDIS_MAXMEMORY_POLICY
    value: "allkeys-lru"  # or volatile-lru, allkeys-lfu, etc.
  
  # Optimize data structures
  - name: REDIS_HASH_MAX_ZIPLIST_ENTRIES
    value: "512"
  - name: REDIS_HASH_MAX_ZIPLIST_VALUE
    value: "64"
```

### Persistence Tuning
```yaml
env:
  # For write-heavy workloads
  - name: REDIS_AOF_ENABLED
    value: "yes"
  - name: REDIS_AOF_FSYNC
    value: "everysec"
  
  # For read-heavy workloads
  - name: REDIS_SAVE
    value: "900 1 300 10 60 10000"
  - name: REDIS_RDB_COMPRESSION
    value: "yes"
```

### Resource Requests and Limits
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "100m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

## 🔄 Backup and Recovery

### Automated Backup CronJob
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: redis-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: redis-backup
            image: your-registry/redis:7.4.0
            command:
            - /bin/bash
            - -c
            - |
              redis-cli -h redis -p 6379 -a $REDIS_PASSWORD BGSAVE
              sleep 10
              cp /var/lib/redis/dump.rdb /backup/redis-backup-$(date +%Y%m%d_%H%M%S).rdb
            env:
            - name: REDIS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: redis-secrets
                  key: password
            volumeMounts:
            - name: redis-data
              mountPath: /var/lib/redis
              readOnly: true
            - name: backup-storage
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: redis-data
            persistentVolumeClaim:
              claimName: redis-pvc
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Memory Issues
```bash
# Check memory usage
kubectl exec redis-0 -- redis-cli INFO memory

# Check eviction stats
kubectl exec redis-0 -- redis-cli INFO stats | grep evicted
```

#### 2. Connection Issues
```bash
# Test connectivity
kubectl exec redis-0 -- redis-cli ping

# Check connected clients
kubectl exec redis-0 -- redis-cli CLIENT LIST
```

#### 3. Performance Issues
```bash
# Check slow log
kubectl exec redis-0 -- redis-cli SLOWLOG GET 10

# Monitor latency
kubectl exec redis-0 -- redis-cli --latency
```

### Debug Commands
```bash
# Get comprehensive Redis info
kubectl exec redis-0 -- /usr/local/bin/redis-info.sh

# Check configuration
kubectl exec redis-0 -- redis-cli CONFIG GET "*"

# Monitor commands in real-time
kubectl exec redis-0 -- redis-cli MONITOR
```

This Redis image is now production-ready and optimized for Kubernetes deployments with comprehensive monitoring, security, and performance features!