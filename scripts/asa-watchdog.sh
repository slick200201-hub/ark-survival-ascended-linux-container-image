#!/bin/bash
################################################################################
# ARK: Survival Ascended - Server Watchdog Script
# 
# This script monitors an ARK ASA server container and automatically restarts
# it if it crashes or becomes unresponsive. This replaces the Windows .bat
# file watchdog functionality with Linux shell script equivalents.
#
# Usage: ./asa-watchdog.sh [server-name] [check-interval]
#
# Arguments:
#   server-name      - Name of the container to monitor (default: asa-server-1)
#   check-interval   - Check interval in seconds (default: 60)
################################################################################

set -e

# Default configuration
DEFAULT_CONTAINER_NAME="asa-server-1"
DEFAULT_CHECK_INTERVAL=60
DEFAULT_RESTART_DELAY=10
MAX_RESTART_ATTEMPTS=3
RESTART_WINDOW=300  # 5 minutes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# State tracking
RESTART_COUNT=0
RESTART_WINDOW_START=0

################################################################################
# Helper Functions
################################################################################

print_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $1"
}

show_help() {
    cat << EOF
ARK: Survival Ascended - Server Watchdog Script

Usage: $0 [server-name] [check-interval]

Arguments:
    server-name      Name of the container to monitor (default: ${DEFAULT_CONTAINER_NAME})
    check-interval   Check interval in seconds (default: ${DEFAULT_CHECK_INTERVAL})

Examples:
    $0                           # Monitor asa-server-1 with 60s interval
    $0 asa-server-2              # Monitor asa-server-2 with 60s interval
    $0 asa-server-1 30           # Monitor asa-server-1 with 30s interval

Features:
    - Monitors container health and status
    - Automatically restarts crashed containers
    - Prevents restart loops (max ${MAX_RESTART_ATTEMPTS} restarts in ${RESTART_WINDOW}s)
    - Logs all events with timestamps

To run as a background service:
    nohup $0 asa-server-1 60 > /var/log/asa-watchdog.log 2>&1 &

To run as a systemd service, create /etc/systemd/system/asa-watchdog.service

EOF
    exit 0
}

check_container_exists() {
    local container_name="$1"
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        print_error "Container '${container_name}' does not exist"
        exit 1
    fi
}

is_container_running() {
    local container_name="$1"
    docker ps --format '{{.Names}}' | grep -q "^${container_name}$"
}

get_container_exit_code() {
    local container_name="$1"
    docker inspect -f '{{.State.ExitCode}}' "$container_name" 2>/dev/null || echo "unknown"
}

check_restart_limit() {
    local current_time=$(date +%s)
    
    # Reset counter if we're outside the restart window
    if [ $RESTART_WINDOW_START -eq 0 ] || [ $((current_time - RESTART_WINDOW_START)) -gt $RESTART_WINDOW ]; then
        RESTART_WINDOW_START=$current_time
        RESTART_COUNT=0
        return 0
    fi
    
    # Check if we've exceeded the restart limit
    if [ $RESTART_COUNT -ge $MAX_RESTART_ATTEMPTS ]; then
        return 1
    fi
    
    return 0
}

restart_server() {
    local container_name="$1"
    
    if ! check_restart_limit; then
        print_error "Too many restarts (${RESTART_COUNT}) in ${RESTART_WINDOW}s window. Stopping watchdog to prevent restart loop."
        print_error "Please investigate the issue and restart the watchdog manually."
        exit 1
    fi
    
    RESTART_COUNT=$((RESTART_COUNT + 1))
    print_warning "Attempting restart ${RESTART_COUNT}/${MAX_RESTART_ATTEMPTS}..."
    
    # Get exit code before restarting
    local exit_code=$(get_container_exit_code "$container_name")
    print_info "Container exit code: ${exit_code}"
    
    # Try to save the world if possible
    print_info "Attempting to save world data..."
    if docker exec "$container_name" asa-ctrl rcon --exec 'saveworld' 2>/dev/null; then
        print_success "World saved successfully"
        sleep 3
    else
        print_warning "Could not save world via RCON"
    fi
    
    # Restart the container
    print_info "Restarting container..."
    docker restart "$container_name"
    
    # Wait for container to start
    local counter=0
    local max_wait=120
    
    while [ $counter -lt $max_wait ]; do
        if is_container_running "$container_name"; then
            print_success "Container restarted successfully"
            return 0
        fi
        sleep 1
        counter=$((counter + 1))
    done
    
    print_error "Container did not start within ${max_wait} seconds"
    return 1
}

monitor_server() {
    local container_name="$1"
    local check_interval="$2"
    
    print_info "Starting watchdog for container: ${container_name}"
    print_info "Check interval: ${check_interval} seconds"
    print_info "Press Ctrl+C to stop"
    echo ""
    
    while true; do
        if ! is_container_running "$container_name"; then
            local status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")
            print_warning "Container is not running (Status: ${status})"
            
            if [ "$status" = "exited" ] || [ "$status" = "dead" ]; then
                print_error "Container has crashed or exited unexpectedly"
                restart_server "$container_name"
            elif [ "$status" = "created" ] || [ "$status" = "restarting" ]; then
                print_info "Container is in ${status} state, waiting..."
            else
                print_error "Container is in unexpected state: ${status}"
                restart_server "$container_name"
            fi
        else
            # Container is running, perform health check
            local health_status=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")
            
            if [ "$health_status" != "none" ] && [ "$health_status" != "healthy" ]; then
                print_warning "Container health check failed: ${health_status}"
                if [ "$health_status" = "unhealthy" ]; then
                    print_error "Container is unhealthy, restarting..."
                    restart_server "$container_name"
                fi
            else
                # All good
                local uptime=$(docker inspect -f '{{.State.StartedAt}}' "$container_name")
                print_success "Container is running (Started: ${uptime})"
            fi
        fi
        
        sleep "$check_interval"
    done
}

cleanup() {
    print_info "Watchdog stopped"
    exit 0
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
    
    # Parse arguments
    if [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
    fi
    
    local container_name="${1:-$DEFAULT_CONTAINER_NAME}"
    local check_interval="${2:-$DEFAULT_CHECK_INTERVAL}"
    
    # Validate check interval
    if ! [[ "$check_interval" =~ ^[0-9]+$ ]]; then
        print_error "Invalid check interval: ${check_interval}"
        print_error "Check interval must be a positive integer"
        exit 1
    fi
    
    if [ "$check_interval" -lt 10 ]; then
        print_warning "Check interval is very short (${check_interval}s). Recommended minimum: 30s"
    fi
    
    # Check if container exists
    check_container_exists "$container_name"
    
    # Set up signal handlers
    trap cleanup SIGINT SIGTERM
    
    # Start monitoring
    monitor_server "$container_name" "$check_interval"
}

main "$@"
