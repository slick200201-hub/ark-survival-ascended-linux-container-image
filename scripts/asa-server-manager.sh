#!/bin/bash
################################################################################
# ARK: Survival Ascended - Server Management Script
# 
# This script provides comprehensive management for ARK ASA servers running
# in Docker containers, replacing Windows .bat file functionality with Linux
# shell script equivalents.
#
# Usage: ./asa-server-manager.sh [command] [server-name]
#
# Commands:
#   start       - Start the server container
#   stop        - Stop the server container gracefully
#   restart     - Restart the server container
#   status      - Show server status
#   update      - Update server files and restart
#   logs        - Show server logs (tail -f)
#   backup      - Create a backup of server files
#   rcon        - Execute RCON command
#   help        - Show this help message
################################################################################

set -e

# Default configuration
DEFAULT_CONTAINER_NAME="asa-server-1"
BACKUP_DIR="/var/lib/docker/volumes/backups"
COMPOSE_FILE="docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
ARK: Survival Ascended - Server Management Script

Usage: $0 [command] [server-name]

Commands:
    start [name]        Start the server container (default: ${DEFAULT_CONTAINER_NAME})
    stop [name]         Stop the server container gracefully
    restart [name]      Restart the server container
    status [name]       Show server status
    update [name]       Update server files and restart
    logs [name]         Show server logs (tail -f)
    backup [name]       Create a backup of server files
    rcon [name] [cmd]   Execute RCON command
    list                List all ASA server containers
    help                Show this help message

Examples:
    $0 start
    $0 stop asa-server-1
    $0 restart asa-server-2
    $0 rcon asa-server-1 "saveworld"
    $0 backup asa-server-1
    $0 logs

Environment Variables:
    ASA_COMPOSE_FILE    Path to docker-compose.yml (default: ./docker-compose.yml)
    ASA_BACKUP_DIR      Backup directory (default: ${BACKUP_DIR})

EOF
    exit 0
}

get_container_name() {
    local name="${1:-$DEFAULT_CONTAINER_NAME}"
    echo "$name"
}

check_container_exists() {
    local container_name="$1"
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        print_error "Container '${container_name}' does not exist"
        print_info "Available ASA containers:"
        docker ps -a --filter "name=asa-server" --format "  - {{.Names}} ({{.Status}})"
        exit 1
    fi
}

is_container_running() {
    local container_name="$1"
    docker ps --format '{{.Names}}' | grep -q "^${container_name}$"
}

wait_for_container() {
    local container_name="$1"
    local timeout="${2:-30}"
    local counter=0
    
    print_info "Waiting for container to be ready..."
    while [ $counter -lt $timeout ]; do
        if is_container_running "$container_name"; then
            print_success "Container is running"
            return 0
        fi
        sleep 1
        counter=$((counter + 1))
    done
    
    print_warning "Container did not start within ${timeout} seconds"
    return 1
}

################################################################################
# Command Functions
################################################################################

cmd_start() {
    local container_name=$(get_container_name "$1")
    
    print_info "Starting server: ${container_name}"
    
    check_container_exists "$container_name"
    
    if is_container_running "$container_name"; then
        print_warning "Server '${container_name}' is already running"
        return 0
    fi
    
    if [ -f "$COMPOSE_FILE" ]; then
        # Use docker compose if compose file exists
        docker compose start "$container_name"
    else
        # Use docker directly
        docker start "$container_name"
    fi
    
    wait_for_container "$container_name"
    print_success "Server '${container_name}' started successfully"
}

cmd_stop() {
    local container_name=$(get_container_name "$1")
    local timeout=60
    
    print_info "Stopping server: ${container_name}"
    
    check_container_exists "$container_name"
    
    if ! is_container_running "$container_name"; then
        print_warning "Server '${container_name}' is not running"
        return 0
    fi
    
    # Try to save the world via RCON before stopping
    print_info "Attempting to save world via RCON..."
    if docker exec "$container_name" asa-ctrl rcon --exec 'saveworld' 2>/dev/null; then
        print_success "World saved successfully"
        sleep 5
    else
        print_warning "Could not save via RCON, proceeding with stop"
    fi
    
    if [ -f "$COMPOSE_FILE" ]; then
        docker compose stop "$container_name"
    else
        docker stop -t $timeout "$container_name"
    fi
    
    print_success "Server '${container_name}' stopped successfully"
}

cmd_restart() {
    local container_name=$(get_container_name "$1")
    
    print_info "Restarting server: ${container_name}"
    
    cmd_stop "$container_name"
    sleep 2
    cmd_start "$container_name"
}

cmd_status() {
    local container_name=$(get_container_name "$1")
    
    check_container_exists "$container_name"
    
    print_info "Status for: ${container_name}"
    echo ""
    
    # Container status
    local status=$(docker inspect -f '{{.State.Status}}' "$container_name")
    local running=$(docker inspect -f '{{.State.Running}}' "$container_name")
    
    echo "Container Status: $status"
    echo "Running: $running"
    
    if [ "$running" = "true" ]; then
        # Get uptime
        local started=$(docker inspect -f '{{.State.StartedAt}}' "$container_name")
        echo "Started: $started"
        
        # Get resource usage
        echo ""
        echo "Resource Usage:"
        docker stats "$container_name" --no-stream --format "  CPU: {{.CPUPerc}}\n  Memory: {{.MemUsage}}\n  Network: {{.NetIO}}"
        
        # Try to get server info via RCON
        echo ""
        print_info "Attempting to query server status..."
        if docker exec "$container_name" asa-ctrl rcon --exec 'listplayers' 2>/dev/null; then
            echo ""
        else
            print_warning "RCON not available or not configured"
        fi
    fi
}

cmd_update() {
    local container_name=$(get_container_name "$1")
    
    print_info "Updating server: ${container_name}"
    
    check_container_exists "$container_name"
    
    # Notify players if server is running
    if is_container_running "$container_name"; then
        print_info "Notifying players about restart..."
        docker exec "$container_name" asa-ctrl rcon --exec 'serverchat Server will restart in 5 minutes for updates' 2>/dev/null || true
        sleep 60
        
        docker exec "$container_name" asa-ctrl rcon --exec 'serverchat Server will restart in 4 minutes for updates' 2>/dev/null || true
        sleep 60
        
        docker exec "$container_name" asa-ctrl rcon --exec 'serverchat Server will restart in 3 minutes for updates' 2>/dev/null || true
        sleep 60
        
        docker exec "$container_name" asa-ctrl rcon --exec 'serverchat Server will restart in 2 minutes for updates' 2>/dev/null || true
        sleep 60
        
        docker exec "$container_name" asa-ctrl rcon --exec 'serverchat Server will restart in 1 minute for updates' 2>/dev/null || true
        sleep 30
        
        docker exec "$container_name" asa-ctrl rcon --exec 'serverchat Server restarting in 30 seconds!' 2>/dev/null || true
        sleep 30
    fi
    
    # Restart triggers update
    print_info "Restarting server to apply updates..."
    docker restart "$container_name"
    
    wait_for_container "$container_name" 120
    print_success "Server '${container_name}' updated and restarted"
}

cmd_logs() {
    local container_name=$(get_container_name "$1")
    
    check_container_exists "$container_name"
    
    print_info "Showing logs for: ${container_name}"
    print_info "Press Ctrl+C to exit"
    echo ""
    
    docker logs -f "$container_name"
}

cmd_backup() {
    local container_name=$(get_container_name "$1")
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="${container_name}_backup_${timestamp}"
    
    print_info "Creating backup: ${backup_name}"
    
    check_container_exists "$container_name"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Determine volume name
    local volume_name=$(docker inspect "$container_name" | grep -o "asa-server_server-files-[0-9]*" | head -1)
    
    if [ -z "$volume_name" ]; then
        print_error "Could not determine server files volume"
        exit 1
    fi
    
    # Save world if server is running
    if is_container_running "$container_name"; then
        print_info "Saving world before backup..."
        docker exec "$container_name" asa-ctrl rcon --exec 'saveworld' 2>/dev/null || print_warning "Could not save via RCON"
        sleep 5
    fi
    
    local volume_path="/var/lib/docker/volumes/${volume_name}/_data"
    
    print_info "Backing up from: ${volume_path}"
    print_info "Backup destination: ${BACKUP_DIR}/${backup_name}.tar.gz"
    
    # Create compressed backup
    tar -czf "${BACKUP_DIR}/${backup_name}.tar.gz" -C "$volume_path" . 2>/dev/null
    
    if [ $? -eq 0 ]; then
        local backup_size=$(du -h "${BACKUP_DIR}/${backup_name}.tar.gz" | cut -f1)
        print_success "Backup created successfully (Size: ${backup_size})"
        print_info "Backup location: ${BACKUP_DIR}/${backup_name}.tar.gz"
    else
        print_error "Backup failed"
        exit 1
    fi
}

cmd_rcon() {
    local container_name=$(get_container_name "$1")
    shift
    local rcon_command="$@"
    
    if [ -z "$rcon_command" ]; then
        print_error "No RCON command provided"
        echo "Usage: $0 rcon [server-name] [command]"
        exit 1
    fi
    
    check_container_exists "$container_name"
    
    if ! is_container_running "$container_name"; then
        print_error "Server '${container_name}' is not running"
        exit 1
    fi
    
    print_info "Executing RCON command: ${rcon_command}"
    docker exec -t "$container_name" asa-ctrl rcon --exec "$rcon_command"
}

cmd_list() {
    print_info "Available ASA server containers:"
    echo ""
    
    docker ps -a --filter "name=asa-server" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

################################################################################
# Main
################################################################################

main() {
    # Check if docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Parse environment variables
    COMPOSE_FILE="${ASA_COMPOSE_FILE:-$COMPOSE_FILE}"
    BACKUP_DIR="${ASA_BACKUP_DIR:-$BACKUP_DIR}"
    
    # Parse command
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        start)
            cmd_start "$@"
            ;;
        stop)
            cmd_stop "$@"
            ;;
        restart)
            cmd_restart "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        update)
            cmd_update "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        backup)
            cmd_backup "$@"
            ;;
        rcon)
            cmd_rcon "$@"
            ;;
        list)
            cmd_list
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            ;;
    esac
}

main "$@"
