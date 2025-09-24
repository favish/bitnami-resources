# Discourse Docker Image for Helm/Kubernetes Deployment

This production-ready Discourse Docker image is optimized for deployment with Helm charts in Kubernetes environments.

## 🎯 Key Features for Kubernetes

- **Environment Variable Configuration**: No config files - all configuration via env vars
- **Health Checks**: Built-in Kubernetes-compatible health endpoints
- **Graceful Shutdown**: Proper SIGTERM handling for pod termination
- **Security Hardening**: Non-root user, minimal attack surface
- **Multi-stage Build**: Optimized image size for faster pulls

## 🔧 Required Environment Variables

### Database Configuration
```yaml
env:
  - name: DISCOURSE_DB_HOST
    value: "postgres-service"
  - name: DISCOURSE_DB_NAME
    value: "discourse_production"
  - name: DISCOURSE_DB_USERNAME
    value: "discourse"
  - name: DISCOURSE_DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: discourse-secrets
        key: db-password
```

### Redis Configuration
```yaml
env:
  - name: DISCOURSE_REDIS_HOST
    value: "redis-service"
  - name: DISCOURSE_REDIS_PORT
    value: "6379"
```

### Core Settings
```yaml
env:
  - name: DISCOURSE_HOSTNAME
    value: "discourse.example.com"
  - name: DISCOURSE_SECRET_KEY_BASE
    valueFrom:
      secretKeyRef:
        name: discourse-secrets
        key: secret-key-base
```

### Email Configuration
```yaml
env:
  - name: DISCOURSE_SMTP_ADDRESS
    value: "smtp.example.com"
  - name: DISCOURSE_SMTP_PORT
    value: "587"
  - name: DISCOURSE_SMTP_USER_NAME
    valueFrom:
      secretKeyRef:
        name: discourse-secrets
        key: smtp-username
  - name: DISCOURSE_SMTP_PASSWORD
    valueFrom:
      secretKeyRef:
        name: discourse-secrets
        key: smtp-password
```

## 📋 Complete Helm Values Example

```yaml
image:
  repository: your-registry/discourse
  tag: "3.5.0"
  pullPolicy: IfNotPresent

replicaCount: 2

service:
  type: ClusterIP
  port: 3000

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: discourse.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: discourse-tls
      hosts:
        - discourse.example.com

env:
  # Core Configuration
  - name: DISCOURSE_HOSTNAME
    value: "discourse.example.com"
  - name: DISCOURSE_FORCE_HTTPS
    value: "true"
  
  # Database
  - name: DISCOURSE_DB_HOST
    value: "postgres-postgresql"
  - name: DISCOURSE_DB_NAME
    value: "discourse_production"
  - name: DISCOURSE_DB_USERNAME
    value: "discourse"
  - name: DISCOURSE_DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: discourse-secrets
        key: database-password
  
  # Redis
  - name: DISCOURSE_REDIS_HOST
    value: "redis-master"
  
  # Email
  - name: DISCOURSE_SMTP_ADDRESS
    value: "smtp.mailgun.org"
  - name: DISCOURSE_SMTP_PORT
    value: "587"
  - name: DISCOURSE_SMTP_USER_NAME
    valueFrom:
      secretKeyRef:
        name: discourse-secrets
        key: smtp-username
  - name: DISCOURSE_SMTP_PASSWORD
    valueFrom:
      secretKeyRef:
        name: discourse-secrets
        key: smtp-password
  
  # Security
  - name: DISCOURSE_SECRET_KEY_BASE
    valueFrom:
      secretKeyRef:
        name: discourse-secrets
        key: secret-key-base
  
  # Performance (adjust based on resources)
  - name: DISCOURSE_UNICORN_WORKERS
    value: "4"
  - name: RAILS_MAX_THREADS
    value: "8"
  
  # Optional: Admin user for initial setup
  - name: DISCOURSE_ADMIN_EMAIL
    value: "admin@example.com"
  - name: DISCOURSE_ADMIN_USERNAME
    value: "admin"
  - name: DISCOURSE_ADMIN_PASSWORD
    valueFrom:
      secretKeyRef:
        name: discourse-secrets
        key: admin-password

envFrom:
  - secretRef:
      name: discourse-secrets

resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi

livenessProbe:
  httpGet:
    path: /srv/status
    port: 3000
  initialDelaySeconds: 60
  periodSeconds: 30
  timeoutSeconds: 10

readinessProbe:
  httpGet:
    path: /srv/status
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5

securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  runAsGroup: 1001
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL

volumeMounts:
  - name: uploads
    mountPath: /opt/discourse/public/uploads
  - name: backups
    mountPath: /opt/discourse/public/backups
  - name: logs
    mountPath: /opt/discourse/log
  - name: tmp
    mountPath: /opt/discourse/tmp

volumes:
  - name: uploads
    persistentVolumeClaim:
      claimName: discourse-uploads
  - name: backups
    persistentVolumeClaim:
      claimName: discourse-backups
  - name: logs
    emptyDir: {}
  - name: tmp
    emptyDir: {}

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
```

## 🔐 Secrets Management

Create the required secrets:

```bash
# Generate secure secrets
SECRET_KEY_BASE=$(openssl rand -hex 64)
DB_PASSWORD=$(openssl rand -base64 32)
ADMIN_PASSWORD=$(openssl rand -base64 24)

# Create the secret
kubectl create secret generic discourse-secrets \
  --from-literal=secret-key-base="$SECRET_KEY_BASE" \
  --from-literal=database-password="$DB_PASSWORD" \
  --from-literal=admin-password="$ADMIN_PASSWORD" \
  --from-literal=smtp-username="your-smtp-username" \
  --from-literal=smtp-password="your-smtp-password"
```

## 🚀 Deployment Commands

```bash
# Build and push image
docker build -t your-registry/discourse:3.5.0 .
docker push your-registry/discourse:3.5.0

# Deploy with Helm
helm install discourse ./discourse-chart \
  --values values.yaml \
  --namespace discourse \
  --create-namespace

# Upgrade deployment
helm upgrade discourse ./discourse-chart \
  --values values.yaml \
  --namespace discourse
```

## 📊 Monitoring Integration

### Prometheus Metrics
Add these annotations to enable Prometheus scraping:

```yaml
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "3000"
  prometheus.io/path: "/metrics"
```

### Log Aggregation
The image logs to stdout/stderr, making it compatible with:
- Fluentd
- Fluent Bit
- Logstash
- Vector

### Health Checks
- **Liveness**: `/srv/status` - Application health
- **Readiness**: `/srv/status` - Ready to serve traffic
- **Startup**: 60-second grace period for initialization

## 🔧 Performance Tuning

### Resource Recommendations

| Deployment Size | CPU | Memory | Replicas |
|----------------|-----|--------|----------|
| Small (< 1k users) | 500m | 1Gi | 2 |
| Medium (< 10k users) | 1000m | 2Gi | 3-5 |
| Large (< 100k users) | 2000m | 4Gi | 5-10 |

### Environment Variables for Performance

```yaml
env:
  # Adjust based on available CPU cores
  - name: DISCOURSE_UNICORN_WORKERS
    value: "4"  # Usually CPU cores * 1.5
  
  # Thread pool size
  - name: RAILS_MAX_THREADS
    value: "8"
  
  # Database connection pool
  - name: DISCOURSE_DB_POOL
    value: "25"
  
  # Unicorn timeout
  - name: DISCOURSE_UNICORN_TIMEOUT
    value: "30"
```

## 🛡️ Security Best Practices

1. **Use Secrets**: Never put sensitive data in ConfigMaps
2. **Network Policies**: Restrict pod-to-pod communication
3. **Pod Security Standards**: Enforce restricted security context
4. **Image Scanning**: Scan images for vulnerabilities
5. **RBAC**: Limit service account permissions

## 🔄 Backup Strategy

```yaml
# Backup CronJob example
apiVersion: batch/v1
kind: CronJob
metadata:
  name: discourse-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15
            command:
            - /bin/bash
            - -c
            - |
              pg_dump -h $POSTGRES_HOST -U $POSTGRES_USER $POSTGRES_DB > /backup/discourse_$(date +%Y%m%d_%H%M%S).sql
            env:
            - name: POSTGRES_HOST
              value: "postgres-postgresql"
            # ... other env vars
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
```

This image is now optimized for Helm/Kubernetes deployments with proper environment variable handling and no unnecessary configuration file generation.