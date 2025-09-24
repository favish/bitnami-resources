#!/bin/bash
set -euo pipefail

# Production Deployment Script for Redis
# This script helps deploy Redis in a production environment with proper checks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.prod.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required commands exist
check_requirements() {
    log_info "Checking requirements..."
    
    local requirements=("docker" "docker-compose" "openssl")
    local missing=()
    
    for cmd in "${requirements[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing requirements: ${missing[*]}"
        log_error "Please install the missing tools and try again."
        exit 1
    fi
    
    log_success "All requirements are met"
}

# Generate secure secrets
generate_secrets() {
    log_info "Generating secure secrets..."
    
    local redis_password
    redis_password=$(openssl rand -base64 32)
    
    echo "REDIS_PASSWORD=$redis_password"
    
    log_success "Secrets generated successfully"
}

# Validate environment configuration
validate_config() {
    log_info "Validating configuration..."
    
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Environment file not found: $ENV_FILE"
        log_error "Please copy .env.example to .env and configure it."
        exit 1
    fi
    
    # Source the environment file
    set -a
    source "$ENV_FILE"
    set +a
    
    local required_vars=(
        "REDIS_PASSWORD"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            log_error "  - $var"
        done
        exit 1
    fi
    
    # Validate memory settings
    if [ -n "${REDIS_MAXMEMORY:-}" ]; then
        if [[ ! "$REDIS_MAXMEMORY" =~ ^[0-9]+[kmgt]?b?$ ]]; then
            log_warning "REDIS_MAXMEMORY format might be invalid: $REDIS_MAXMEMORY"
            log_warning "Expected format: 512mb, 1gb, etc."
        fi
    fi
    
    log_success "Configuration validation passed"
}

# Build the Docker image
build_image() {
    log_info "Building Redis Docker image..."
    
    local build_args=(
        "--build-arg" "BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        "--build-arg" "VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
    )
    
    if ! docker-compose -f "$COMPOSE_FILE" build "${build_args[@]}" redis; then
        log_error "Failed to build Docker image"
        exit 1
    fi
    
    log_success "Docker image built successfully"
}

# Deploy the application
deploy() {
    log_info "Deploying Redis..."
    
    # Create necessary directories
    mkdir -p data/{redis,logs}
    
    # Start services
    if ! docker-compose -f "$COMPOSE_FILE" up -d redis; then
        log_error "Failed to deploy Redis"
        exit 1
    fi
    
    log_success "Redis deployed successfully"
    
    # Wait for Redis to be healthy
    log_info "Waiting for Redis to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f "$COMPOSE_FILE" ps --format json | jq -e '.[] | select(.Service == "redis") | select(.Health == "healthy")' > /dev/null 2>&1; then
            log_success "Redis is healthy and ready"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "Redis failed to become healthy within timeout"
            docker-compose -f "$COMPOSE_FILE" logs redis
            exit 1
        fi
        
        log_info "Waiting for Redis to be ready... (attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
}

# Deploy with monitoring
deploy_with_monitoring() {
    log_info "Deploying Redis with monitoring..."
    
    # Start services including monitoring
    if ! docker-compose -f "$COMPOSE_FILE" --profile monitoring up -d; then
        log_error "Failed to deploy Redis with monitoring"
        exit 1
    fi
    
    log_success "Redis deployed with monitoring successfully"
}

# Deploy with high availability (Sentinel)
deploy_ha() {
    log_info "Deploying Redis with High Availability (Sentinel)..."
    
    # Start services including sentinel
    if ! docker-compose -f "$COMPOSE_FILE" --profile sentinel up -d; then
        log_error "Failed to deploy Redis with Sentinel"
        exit 1
    fi
    
    log_success "Redis deployed with Sentinel successfully"
}

# Show deployment status
show_status() {
    log_info "Redis Deployment Status:"
    echo
    
    docker-compose -f "$COMPOSE_FILE" ps
    echo
    
    log_info "Health Checks:"
    if docker-compose -f "$COMPOSE_FILE" exec -T redis /usr/local/bin/redis-health-check.sh > /dev/null 2>&1; then
        log_success "Redis: Healthy"
    else
        log_error "Redis: Unhealthy"
    fi
    
    echo
    log_info "Redis Information:"
    docker-compose -f "$COMPOSE_FILE" exec -T redis /usr/local/bin/redis-info.sh | head -20
    
    echo
    log_info "Useful Commands:"
    echo "  View logs: docker-compose -f $COMPOSE_FILE logs -f redis"
    echo "  Redis CLI: docker-compose -f $COMPOSE_FILE exec redis redis-cli"
    echo "  Redis info: docker-compose -f $COMPOSE_FILE exec redis /usr/local/bin/redis-info.sh"
    echo "  Stop services: docker-compose -f $COMPOSE_FILE down"
}

# Backup function
backup() {
    log_info "Creating Redis backup..."
    
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Trigger Redis BGSAVE
    docker-compose -f "$COMPOSE_FILE" exec -T redis redis-cli BGSAVE
    
    # Wait for backup to complete
    log_info "Waiting for backup to complete..."
    sleep 5
    
    # Copy backup files
    docker run --rm -v redis_data:/data -v "$(pwd)/$backup_dir":/backup alpine \
        sh -c "cp /data/dump.rdb /backup/ 2>/dev/null || echo 'No RDB file found'"
    
    docker run --rm -v redis_data:/data -v "$(pwd)/$backup_dir":/backup alpine \
        sh -c "cp /data/appendonly.aof /backup/ 2>/dev/null || echo 'No AOF file found'"
    
    # Create volume backup
    docker run --rm -v redis_data:/data -v "$(pwd)/$backup_dir":/backup alpine \
        tar czf /backup/redis_data.tar.gz /data
    
    log_success "Backup created in $backup_dir"
}

# Performance test function
performance_test() {
    log_info "Running Redis performance test..."
    
    # Check if Redis is running
    if ! docker-compose -f "$COMPOSE_FILE" exec -T redis redis-cli ping > /dev/null 2>&1; then
        log_error "Redis is not running. Please deploy Redis first."
        exit 1
    fi
    
    # Run redis-benchmark
    log_info "Running benchmark tests..."
    docker-compose -f "$COMPOSE_FILE" exec redis redis-benchmark \
        -h 127.0.0.1 \
        -p 6379 \
        -t set,get \
        -n 10000 \
        -c 50 \
        -q
    
    log_success "Performance test completed"
}

# Show help
show_help() {
    echo "Redis Production Deployment Script"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  init        Initialize environment with generated secrets"
    echo "  validate    Validate configuration"
    echo "  build       Build Docker image"
    echo "  deploy      Deploy Redis"
    echo "  deploy-monitoring  Deploy Redis with monitoring"
    echo "  deploy-ha   Deploy Redis with High Availability"
    echo "  status      Show deployment status"
    echo "  backup      Create backup"
    echo "  test        Run performance test"
    echo "  logs        Show Redis logs"
    echo "  cli         Access Redis CLI"
    echo "  stop        Stop all services"
    echo "  help        Show this help message"
    echo
    echo "Examples:"
    echo "  $0 init && $0 deploy              # Basic deployment"
    echo "  $0 deploy-monitoring              # With Prometheus monitoring"
    echo "  $0 deploy-ha                      # High availability setup"
}

# Main script logic
main() {
    case "${1:-help}" in
        "init")
            check_requirements
            if [ ! -f "$ENV_FILE" ]; then
                cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
                log_success "Environment file created from template"
                echo
                log_info "Generated secrets (add these to your .env file):"
                generate_secrets
                echo
                log_warning "Please edit $ENV_FILE with your configuration before deploying"
            else
                log_warning "Environment file already exists: $ENV_FILE"
            fi
            ;;
        "validate")
            validate_config
            ;;
        "build")
            check_requirements
            validate_config
            build_image
            ;;
        "deploy")
            check_requirements
            validate_config
            build_image
            deploy
            show_status
            ;;
        "deploy-monitoring")
            check_requirements
            validate_config
            build_image
            deploy_with_monitoring
            show_status
            ;;
        "deploy-ha")
            check_requirements
            validate_config
            build_image
            deploy_ha
            show_status
            ;;
        "status")
            show_status
            ;;
        "backup")
            backup
            ;;
        "test")
            performance_test
            ;;
        "logs")
            docker-compose -f "$COMPOSE_FILE" logs -f redis
            ;;
        "cli")
            docker-compose -f "$COMPOSE_FILE" exec redis redis-cli
            ;;
        "stop")
            docker-compose -f "$COMPOSE_FILE" down
            log_success "Services stopped"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "$@"