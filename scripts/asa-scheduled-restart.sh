#!/bin/bash
################################################################################
# ARK: Survival Ascended - Scheduled Restart Script
# 
# This script handles graceful server restarts with player notifications via
# RCON. It replaces Windows .bat scheduled restart functionality with Linux
# shell script equivalents.
#
# Usage: ./asa-scheduled-restart.sh [server-name] [warning-time]
#
# Arguments:
#   server-name    - Name of the container to restart (default: asa-server-1)
#   warning-time   - Warning time in minutes (default: 30, options: 5, 10, 15, 30, 60)
################################################################################

set -e

# Default configuration
DEFAULT_CONTAINER_NAME="asa-server-1"
DEFAULT_WARNING_TIME=30

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
ARK: Survival Ascended - Scheduled Restart Script

Usage: $0 [server-name] [warning-time]

Arguments:
    server-name    Name of the container to restart (default: ${DEFAULT_CONTAINER_NAME})
    warning-time   Warning time in minutes (default: ${DEFAULT_WARNING_TIME})
                   Supported values: 5, 10, 15, 30, 60

Examples:
    $0                      # Restart asa-server-1 with 30 min warning
    $0 asa-server-1 10      # Restart asa-server-1 with 10 min warning
    $0 asa-server-2 60      # Restart asa-server-2 with 60 min warning

Warning Schedule:
    60 min: Warnings at 60, 45, 30, 15, 10, 5, 3, 1 min and 30 sec
    30 min: Warnings at 30, 15, 10, 5, 3, 1 min and 30 sec
    15 min: Warnings at 15, 10, 5, 3, 1 min and 30 sec
    10 min: Warnings at 10, 5, 3, 1 min and 30 sec
    5 min:  Warnings at 5, 3, 1 min and 30 sec

Features:
    - Player notifications via RCON
    - Automatic world save before restart
    - Graceful shutdown
    - Update check on restart

For automated daily restarts, add to crontab:
    # Daily restart at 4:00 AM with 30 minute warning
    30 3 * * * /path/to/asa-scheduled-restart.sh asa-server-1 30

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

send_rcon_message() {
    local container_name="$1"
    local message="$2"
    
    if ! is_container_running "$container_name"; then
        print_warning "Container is not running, cannot send RCON message"
        return 1
    fi
    
    if docker exec "$container_name" asa-ctrl rcon --exec "serverchat ${message}" 2>/dev/null; then
        print_info "RCON: ${message}"
        return 0
    else
        print_warning "Failed to send RCON message: ${message}"
        return 1
    fi
}

save_world() {
    local container_name="$1"
    
    print_info "Saving world..."
    if docker exec "$container_name" asa-ctrl rcon --exec 'saveworld' 2>/dev/null; then
        print_success "World saved successfully"
        return 0
    else
        print_warning "Failed to save world via RCON"
        return 1
    fi
}

perform_restart() {
    local container_name="$1"
    
    print_info "Performing server restart..."
    
    # Save world one more time
    save_world "$container_name"
    sleep 3
    
    # Restart the container (this also updates server files)
    print_info "Restarting container (this will also check for updates)..."
    docker restart "$container_name"
    
    # Wait for container to start
    print_info "Waiting for server to come back online..."
    local counter=0
    local max_wait=180
    
    while [ $counter -lt $max_wait ]; do
        if is_container_running "$container_name"; then
            print_success "Server restarted successfully"
            print_info "Server is now online and checking for updates"
            return 0
        fi
        sleep 1
        counter=$((counter + 1))
    done
    
    print_error "Server did not start within ${max_wait} seconds"
    return 1
}

do_scheduled_restart() {
    local container_name="$1"
    local warning_time="$2"
    
    print_info "Starting scheduled restart for: ${container_name}"
    print_info "Warning time: ${warning_time} minutes"
    
    # Check if container exists and is running
    check_container_exists "$container_name"
    
    if ! is_container_running "$container_name"; then
        print_warning "Container is not running. Starting it instead..."
        docker start "$container_name"
        exit 0
    fi
    
    # Execute warning schedule based on warning time
    case "$warning_time" in
        60)
            send_rcon_message "$container_name" "Server will restart in 60 minutes"
            sleep 900  # 15 minutes
            send_rcon_message "$container_name" "Server will restart in 45 minutes"
            sleep 900  # 15 minutes
            ;&  # Fall through
        30)
            send_rcon_message "$container_name" "Server will restart in 30 minutes"
            sleep 900  # 15 minutes
            ;&  # Fall through
        15)
            send_rcon_message "$container_name" "Server will restart in 15 minutes"
            sleep 300  # 5 minutes
            ;&  # Fall through
        10)
            send_rcon_message "$container_name" "Server will restart in 10 minutes"
            sleep 300  # 5 minutes
            ;&  # Fall through
        5)
            send_rcon_message "$container_name" "Server will restart in 5 minutes"
            sleep 120  # 2 minutes
            send_rcon_message "$container_name" "Server will restart in 3 minutes"
            sleep 120  # 2 minutes
            send_rcon_message "$container_name" "Server will restart in 1 minute! Please find a safe place!"
            sleep 30   # 30 seconds
            send_rcon_message "$container_name" "Server restarting in 30 seconds!"
            sleep 30   # 30 seconds
            ;;
        *)
            print_error "Invalid warning time: ${warning_time}"
            print_error "Supported values: 5, 10, 15, 30, 60"
            exit 1
            ;;
    esac
    
    # Final warning
    send_rcon_message "$container_name" "Server restarting NOW!"
    sleep 2
    
    # Perform restart
    perform_restart "$container_name"
    
    print_success "Scheduled restart completed"
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
    local warning_time="${2:-$DEFAULT_WARNING_TIME}"
    
    # Validate warning time
    if ! [[ "$warning_time" =~ ^[0-9]+$ ]]; then
        print_error "Invalid warning time: ${warning_time}"
        print_error "Warning time must be a positive integer"
        exit 1
    fi
    
    # Validate warning time is one of the supported values
    if ! [[ "$warning_time" =~ ^(5|10|15|30|60)$ ]]; then
        print_warning "Warning time ${warning_time} is not a standard value"
        print_warning "Supported values: 5, 10, 15, 30, 60"
        print_warning "Using closest standard value..."
        
        if [ "$warning_time" -lt 8 ]; then
            warning_time=5
        elif [ "$warning_time" -lt 13 ]; then
            warning_time=10
        elif [ "$warning_time" -lt 23 ]; then
            warning_time=15
        elif [ "$warning_time" -lt 45 ]; then
            warning_time=30
        else
            warning_time=60
        fi
        
        print_info "Using warning time: ${warning_time} minutes"
    fi
    
    # Perform scheduled restart
    do_scheduled_restart "$container_name" "$warning_time"
}

main "$@"
