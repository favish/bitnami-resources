#!/bin/bash
set -euo pipefail

# Production Deployment Script for Discourse
# This script helps deploy Discourse in a production environment with proper checks

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
    
    local secret_key_base
    local postgres_password
    local admin_password
    
    secret_key_base=$(openssl rand -hex 64)
    postgres_password=$(openssl rand -base64 32)
    admin_password=$(openssl rand -base64 24)
    
    echo "DISCOURSE_SECRET_KEY_BASE=$secret_key_base"
    echo "POSTGRES_PASSWORD=$postgres_password"
    echo "ADMIN_PASSWORD=$admin_password"
    
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
        "DISCOURSE_HOSTNAME"
        "DISCOURSE_SECRET_KEY_BASE"
        "POSTGRES_PASSWORD"
        "SMTP_ADDRESS"
        "SMTP_USERNAME"
        "SMTP_PASSWORD"
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
    
    # Validate hostname format
    if [[ ! "$DISCOURSE_HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "Invalid hostname format: $DISCOURSE_HOSTNAME"
        exit 1
    fi
    
    # Check secret key length
    if [ ${#DISCOURSE_SECRET_KEY_BASE} -lt 64 ]; then
        log_warning "Secret key base should be at least 64 characters long"
    fi
    
    log_success "Configuration validation passed"
}

# Build the Docker image
build_image() {
    log_info "Building Discourse Docker image..."
    
    local build_args=(
        "--build-arg" "BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        "--build-arg" "VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
    )
    
    if ! docker-compose -f "$COMPOSE_FILE" build "${build_args[@]}" discourse; then
        log_error "Failed to build Docker image"
        exit 1
    fi
    
    log_success "Docker image built successfully"
}

# Deploy the application
deploy() {
    log_info "Deploying Discourse..."
    
    # Create necessary directories
    mkdir -p data/{postgres,redis,uploads,backups,logs}
    
    # Start services
    if ! docker-compose -f "$COMPOSE_FILE" up -d; then
        log_error "Failed to deploy services"
        exit 1
    fi
    
    log_success "Services deployed successfully"
    
    # Wait for services to be healthy
    log_info "Waiting for services to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f "$COMPOSE_FILE" ps --format json | jq -e '.[] | select(.Service == "discourse") | select(.Health == "healthy")' > /dev/null 2>&1; then
            log_success "Discourse is healthy and ready"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "Discourse failed to become healthy within timeout"
            docker-compose -f "$COMPOSE_FILE" logs discourse
            exit 1
        fi
        
        log_info "Waiting for Discourse to be ready... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
}

# Show deployment status
show_status() {
    log_info "Deployment Status:"
    echo
    
    docker-compose -f "$COMPOSE_FILE" ps
    echo
    
    log_info "Health Checks:"
    docker-compose -f "$COMPOSE_FILE" exec discourse /usr/local/bin/health-check.sh && log_success "Discourse: Healthy" || log_error "Discourse: Unhealthy"
    
    echo
    log_info "Access Information:"
    source "$ENV_FILE"
    echo "  URL: https://${DISCOURSE_HOSTNAME}"
    echo "  Admin: ${ADMIN_EMAIL:-'Not configured'}"
    
    echo
    log_info "Useful Commands:"
    echo "  View logs: docker-compose -f $COMPOSE_FILE logs -f discourse"
    echo "  Shell access: docker-compose -f $COMPOSE_FILE exec discourse bash"
    echo "  Stop services: docker-compose -f $COMPOSE_FILE down"
}

# Backup function
backup() {
    log_info "Creating backup..."
    
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Database backup
    docker-compose -f "$COMPOSE_FILE" exec -T postgres pg_dump -U discourse discourse_production > "$backup_dir/database.sql"
    
    # Volume backups
    docker run --rm -v discourse_uploads:/data -v "$(pwd)/$backup_dir":/backup alpine tar czf /backup/uploads.tar.gz /data
    docker run --rm -v postgres_data:/data -v "$(pwd)/$backup_dir":/backup alpine tar czf /backup/postgres_data.tar.gz /data
    
    log_success "Backup created in $backup_dir"
}

# Show help
show_help() {
    echo "Discourse Production Deployment Script"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  init        Initialize environment with generated secrets"
    echo "  validate    Validate configuration"
    echo "  build       Build Docker image"
    echo "  deploy      Deploy all services"
    echo "  status      Show deployment status"
    echo "  backup      Create backup"
    echo "  logs        Show application logs"
    echo "  shell       Access application shell"
    echo "  stop        Stop all services"
    echo "  help        Show this help message"
    echo
    echo "Full deployment: $0 init && $0 deploy"
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
        "status")
            show_status
            ;;
        "backup")
            backup
            ;;
        "logs")
            docker-compose -f "$COMPOSE_FILE" logs -f discourse
            ;;
        "shell")
            docker-compose -f "$COMPOSE_FILE" exec discourse bash
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