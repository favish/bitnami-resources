#!/bin/bash

# Redis Replication Deployment Script
# This script demonstrates how to deploy Redis with master-slave replication architecture

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DEPLOYMENT_MODE="${1:-basic}"  # basic, sentinel, full
REDIS_PASSWORD="${REDIS_PASSWORD:-$(openssl rand -base64 32)}"
NAMESPACE="${REDIS_NAMESPACE:-redis-replication}"

print_header() {
    echo -e "${GREEN}===================================================${NC}"
    echo -e "${GREEN}  Redis Replication Architecture Deployment${NC}"
    echo -e "${GREEN}===================================================${NC}"
    echo ""
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    print_info "Checking requirements..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is required but not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is required but not installed"
        exit 1
    fi
    
    print_info "All requirements satisfied"
}

build_images() {
    print_info "Building Redis production image..."
    docker build -f Dockerfile.prod -t redis-prod:latest .
}

deploy_basic_replication() {
    print_info "Deploying basic master-slave replication (1 master + 2 replicas)..."
    
    cat > .env.replication << EOF
# Redis Configuration
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_MAXMEMORY=1gb
REDIS_MAXMEMORY_POLICY=allkeys-lru
REDIS_REPLICA_MAXMEMORY=512mb

# Persistence
REDIS_AOF_ENABLED=yes
REDIS_AOF_FSYNC=everysec
REDIS_SAVE=900 1 300 10 60 10000
REDIS_REPLICA_AOF_ENABLED=no

# Logging
REDIS_LOGLEVEL=notice

# Build metadata
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')
EOF
    
    docker-compose -f docker-compose.replication.yml --env-file .env.replication up -d \
        redis-master redis-replica-1 redis-replica-2
    
    print_info "Basic replication deployed successfully!"
    print_info "Master: localhost:6379"
    print_info "Replica 1: localhost:6380"
    print_info "Replica 2: localhost:6381"
}

deploy_with_sentinel() {
    print_info "Deploying with Redis Sentinel for automatic failover..."
    
    cat >> .env.replication << EOF

# Sentinel Configuration
REDIS_SENTINEL_MASTER_NAME=mymaster
REDIS_SENTINEL_QUORUM=2
REDIS_SENTINEL_DOWN_AFTER=30000
REDIS_SENTINEL_FAILOVER_TIMEOUT=180000
EOF
    
    docker-compose -f docker-compose.replication.yml --env-file .env.replication \
        --profile sentinel up -d
    
    print_info "Replication with Sentinel deployed!"
    print_info "Sentinel 1: localhost:26379"
    print_info "Sentinel 2: localhost:26380"
    print_info "Sentinel 3: localhost:26381"
}

deploy_full_stack() {
    print_info "Deploying full stack with monitoring and load balancing..."
    
    docker-compose -f docker-compose.replication.yml --env-file .env.replication \
        --profile sentinel --profile monitoring --profile loadbalancer up -d
    
    print_info "Full stack deployed!"
    print_info "Load Balancer (Write): localhost:6382"
    print_info "Load Balancer (Read): localhost:6383"
    print_info "Monitoring: localhost:9121/metrics"
    print_info "HAProxy Stats: localhost:8404/stats"
}

verify_replication() {
    print_info "Verifying replication setup..."
    
    sleep 10  # Allow services to start
    
    # Test master
    print_info "Testing master connection..."
    if docker-compose -f docker-compose.replication.yml exec -T redis-master \
        redis-cli -a "${REDIS_PASSWORD}" ping; then
        print_info "Master is responding"
    else
        print_error "Master is not responding"
        return 1
    fi
    
    # Test replication
    print_info "Testing replication..."
    docker-compose -f docker-compose.replication.yml exec -T redis-master \
        redis-cli -a "${REDIS_PASSWORD}" set test_key "replication_works"
    
    sleep 2
    
    for replica in 1 2; do
        value=$(docker-compose -f docker-compose.replication.yml exec -T redis-replica-${replica} \
            redis-cli -a "${REDIS_PASSWORD}" get test_key 2>/dev/null || echo "")
        
        if [ "$value" = "replication_works" ]; then
            print_info "Replica ${replica} is properly synchronized"
        else
            print_warning "Replica ${replica} may not be synchronized (value: '$value')"
        fi
    done
    
    # Clean up test key
    docker-compose -f docker-compose.replication.yml exec -T redis-master \
        redis-cli -a "${REDIS_PASSWORD}" del test_key > /dev/null
}

show_connection_info() {
    print_info "Connection Information:"
    echo ""
    echo "Redis Password: ${REDIS_PASSWORD}"
    echo ""
    echo "Connection URLs:"
    echo "  Master (Read/Write): redis://:${REDIS_PASSWORD}@localhost:6379"
    echo "  Replica 1 (Read):   redis://:${REDIS_PASSWORD}@localhost:6380"
    echo "  Replica 2 (Read):   redis://:${REDIS_PASSWORD}@localhost:6381"
    
    if [[ "$DEPLOYMENT_MODE" == "sentinel" ]] || [[ "$DEPLOYMENT_MODE" == "full" ]]; then
        echo ""
        echo "Sentinel URLs:"
        echo "  Sentinel 1: redis-sentinel://localhost:26379"
        echo "  Sentinel 2: redis-sentinel://localhost:26380"
        echo "  Sentinel 3: redis-sentinel://localhost:26381"
    fi
    
    if [[ "$DEPLOYMENT_MODE" == "full" ]]; then
        echo ""
        echo "Load Balanced URLs:"
        echo "  Write Operations: redis://:${REDIS_PASSWORD}@localhost:6382"
        echo "  Read Operations:  redis://:${REDIS_PASSWORD}@localhost:6383"
        echo ""
        echo "Monitoring:"
        echo "  Prometheus Metrics: http://localhost:9121/metrics"
        echo "  HAProxy Statistics: http://localhost:8404/stats"
    fi
}

show_example_usage() {
    print_info "Example client usage:"
    echo ""
    echo "# Using redis-cli with master"
    echo "redis-cli -h localhost -p 6379 -a '${REDIS_PASSWORD}'"
    echo ""
    echo "# Using redis-cli with replica"
    echo "redis-cli -h localhost -p 6380 -a '${REDIS_PASSWORD}'"
    echo ""
    echo "# Python example with master-slave"
    cat << 'EOF'
import redis

# Master (read/write)
master = redis.Redis(
    host='localhost',
    port=6379,
    password='your_password',
    decode_responses=True
)

# Replica (read-only)
replica = redis.Redis(
    host='localhost',
    port=6380,
    password='your_password',
    decode_responses=True
)

# Write to master
master.set('key', 'value')

# Read from replica
value = replica.get('key')
EOF
    echo ""
    
    if [[ "$DEPLOYMENT_MODE" == "sentinel" ]] || [[ "$DEPLOYMENT_MODE" == "full" ]]; then
        echo "# Python with Sentinel"
        cat << 'EOF'
from redis.sentinel import Sentinel

sentinel = Sentinel([
    ('localhost', 26379),
    ('localhost', 26380),
    ('localhost', 26381)
])

# Discover master and replicas
master = sentinel.master_for('mymaster', password='your_password')
replica = sentinel.slave_for('mymaster', password='your_password')
EOF
    fi
}

cleanup() {
    print_info "Cleaning up deployment..."
    docker-compose -f docker-compose.replication.yml down -v
    docker system prune -f
    rm -f .env.replication
}

main() {
    print_header
    
    case "${DEPLOYMENT_MODE}" in
        "basic")
            print_info "Deploying basic master-slave replication"
            ;;
        "sentinel")
            print_info "Deploying with Redis Sentinel"
            ;;
        "full")
            print_info "Deploying full production stack"
            ;;
        "cleanup")
            cleanup
            exit 0
            ;;
        *)
            print_error "Invalid deployment mode: ${DEPLOYMENT_MODE}"
            echo "Usage: $0 [basic|sentinel|full|cleanup]"
            exit 1
            ;;
    esac
    
    check_requirements
    build_images
    
    case "${DEPLOYMENT_MODE}" in
        "basic")
            deploy_basic_replication
            ;;
        "sentinel")
            deploy_basic_replication
            deploy_with_sentinel
            ;;
        "full")
            deploy_basic_replication
            deploy_with_sentinel
            deploy_full_stack
            ;;
    esac
    
    verify_replication
    show_connection_info
    show_example_usage
    
    print_info "Deployment completed successfully!"
    print_info "Run '$0 cleanup' to remove all services"
}

# Handle script interruption
trap 'print_error "Deployment interrupted"; exit 1' INT TERM

main "$@"