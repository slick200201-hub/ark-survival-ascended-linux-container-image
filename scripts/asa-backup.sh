#!/bin/bash
################################################################################
# ARK: Survival Ascended - Backup Management Script
# 
# This script handles backup creation, restoration, and management for ARK ASA
# servers. It replaces Windows .bat backup functionality with Linux shell
# script equivalents.
#
# Usage: ./asa-backup.sh [command] [server-name] [options]
#
# Commands:
#   create      - Create a new backup
#   restore     - Restore from a backup
#   list        - List available backups
#   cleanup     - Clean up old backups
#   help        - Show this help message
################################################################################

set -e

# Default configuration
DEFAULT_CONTAINER_NAME="asa-server-1"
DEFAULT_BACKUP_DIR="/var/lib/docker/volumes/backups"
DEFAULT_MAX_BACKUPS=10

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
ARK: Survival Ascended - Backup Management Script

Usage: $0 [command] [server-name] [options]

Commands:
    create [name] [label]           Create a new backup
    restore [name] [backup-file]    Restore from a backup
    list [name]                     List available backups
    cleanup [name] [keep-count]     Clean up old backups
    help                            Show this help message

Examples:
    $0 create                                    # Backup asa-server-1
    $0 create asa-server-1 "pre-update"         # Backup with label
    $0 restore asa-server-1 backup_20240204.tar.gz
    $0 list asa-server-1
    $0 cleanup asa-server-1 10                   # Keep 10 most recent

Environment Variables:
    ASA_BACKUP_DIR      Backup directory (default: ${DEFAULT_BACKUP_DIR})
    ASA_MAX_BACKUPS     Maximum backups to keep (default: ${DEFAULT_MAX_BACKUPS})

Features:
    - Automatic world save before backup
    - Compressed backups (tar.gz)
    - Backup rotation/cleanup
    - Labeled backups for important saves
    - Safe restore with confirmation

For automated daily backups, add to crontab:
    # Daily backup at 3:00 AM
    0 3 * * * /path/to/asa-backup.sh create asa-server-1 daily

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

get_volume_name() {
    local container_name="$1"
    local volume_name=$(docker inspect "$container_name" | grep -o "asa-server_server-files-[0-9]*" | head -1)
    
    if [ -z "$volume_name" ]; then
        print_error "Could not determine server files volume for container: ${container_name}"
        exit 1
    fi
    
    echo "$volume_name"
}

get_volume_path() {
    local volume_name="$1"
    echo "/var/lib/docker/volumes/${volume_name}/_data"
}

save_world() {
    local container_name="$1"
    
    if ! is_container_running "$container_name"; then
        print_info "Container is not running, skipping world save"
        return 0
    fi
    
    print_info "Saving world via RCON..."
    if docker exec "$container_name" asa-ctrl rcon --exec 'saveworld' 2>/dev/null; then
        print_success "World saved successfully"
        sleep 3
        return 0
    else
        print_warning "Could not save world via RCON (RCON may not be configured)"
        return 1
    fi
}

################################################################################
# Command Functions
################################################################################

cmd_create() {
    local container_name="${1:-$DEFAULT_CONTAINER_NAME}"
    local label="${2:-}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="${container_name}_backup_${timestamp}"
    
    if [ -n "$label" ]; then
        # Sanitize label (remove special characters)
        label=$(echo "$label" | tr -cd '[:alnum:]_-')
        backup_name="${container_name}_backup_${timestamp}_${label}"
    fi
    
    print_info "Creating backup: ${backup_name}"
    
    check_container_exists "$container_name"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$DEFAULT_BACKUP_DIR"
    
    # Get volume information
    local volume_name=$(get_volume_name "$container_name")
    local volume_path=$(get_volume_path "$volume_name")
    
    print_info "Volume: ${volume_name}"
    print_info "Source: ${volume_path}"
    
    # Check if volume path exists
    if [ ! -d "$volume_path" ]; then
        print_error "Volume path does not exist: ${volume_path}"
        exit 1
    fi
    
    # Save world before backup
    save_world "$container_name"
    
    # Create backup
    local backup_file="${DEFAULT_BACKUP_DIR}/${backup_name}.tar.gz"
    print_info "Creating compressed backup..."
    
    if tar -czf "$backup_file" -C "$volume_path" . 2>/dev/null; then
        local backup_size=$(du -h "$backup_file" | cut -f1)
        print_success "Backup created successfully"
        print_info "Backup file: ${backup_file}"
        print_info "Backup size: ${backup_size}"
        
        # Create backup info file
        local info_file="${DEFAULT_BACKUP_DIR}/${backup_name}.info"
        cat > "$info_file" << EOF
Container: ${container_name}
Volume: ${volume_name}
Created: $(date '+%Y-%m-%d %H:%M:%S')
Size: ${backup_size}
Label: ${label:-none}
EOF
        
        return 0
    else
        print_error "Backup failed"
        exit 1
    fi
}

cmd_restore() {
    local container_name="${1:-$DEFAULT_CONTAINER_NAME}"
    local backup_file="$2"
    
    if [ -z "$backup_file" ]; then
        print_error "No backup file specified"
        echo "Usage: $0 restore [server-name] [backup-file]"
        echo ""
        echo "Available backups:"
        cmd_list "$container_name"
        exit 1
    fi
    
    # Add path if not absolute
    if [[ ! "$backup_file" = /* ]]; then
        backup_file="${DEFAULT_BACKUP_DIR}/${backup_file}"
    fi
    
    if [ ! -f "$backup_file" ]; then
        print_error "Backup file does not exist: ${backup_file}"
        exit 1
    fi
    
    print_warning "========================================="
    print_warning "WARNING: This will REPLACE all server data!"
    print_warning "Container: ${container_name}"
    print_warning "Backup: ${backup_file}"
    print_warning "========================================="
    
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Restore cancelled"
        exit 0
    fi
    
    check_container_exists "$container_name"
    
    # Stop container if running
    local was_running=false
    if is_container_running "$container_name"; then
        was_running=true
        print_info "Stopping container..."
        docker stop "$container_name"
        sleep 3
    fi
    
    # Get volume information
    local volume_name=$(get_volume_name "$container_name")
    local volume_path=$(get_volume_path "$volume_name")
    
    print_info "Restoring to: ${volume_path}"
    
    # Backup current data before restoring (safety measure)
    local safety_backup="${DEFAULT_BACKUP_DIR}/${container_name}_pre_restore_$(date +%Y%m%d_%H%M%S).tar.gz"
    print_info "Creating safety backup of current data..."
    tar -czf "$safety_backup" -C "$volume_path" . 2>/dev/null
    print_success "Safety backup created: ${safety_backup}"
    
    # Clear existing data
    print_info "Clearing existing server data..."
    rm -rf "${volume_path:?}"/*
    
    # Extract backup
    print_info "Restoring from backup..."
    if tar -xzf "$backup_file" -C "$volume_path" 2>/dev/null; then
        print_success "Backup restored successfully"
        
        # Restart container if it was running
        if [ "$was_running" = true ]; then
            print_info "Restarting container..."
            docker start "$container_name"
            sleep 3
        fi
        
        print_success "Restore completed successfully"
        return 0
    else
        print_error "Failed to restore backup"
        print_info "Restoring from safety backup..."
        tar -xzf "$safety_backup" -C "$volume_path" 2>/dev/null
        
        if [ "$was_running" = true ]; then
            docker start "$container_name"
        fi
        
        exit 1
    fi
}

cmd_list() {
    local container_name="${1:-$DEFAULT_CONTAINER_NAME}"
    
    print_info "Available backups for: ${container_name}"
    echo ""
    
    if [ ! -d "$DEFAULT_BACKUP_DIR" ]; then
        print_warning "Backup directory does not exist: ${DEFAULT_BACKUP_DIR}"
        exit 0
    fi
    
    local backup_files=$(find "$DEFAULT_BACKUP_DIR" -name "${container_name}_backup_*.tar.gz" -type f | sort -r)
    
    if [ -z "$backup_files" ]; then
        print_warning "No backups found"
        exit 0
    fi
    
    printf "%-50s %-15s %-20s\n" "Backup File" "Size" "Date"
    printf "%-50s %-15s %-20s\n" "----------" "----" "----"
    
    while IFS= read -r backup_file; do
        local filename=$(basename "$backup_file")
        local size=$(du -h "$backup_file" | cut -f1)
        local date=$(stat -c %y "$backup_file" | cut -d'.' -f1)
        
        printf "%-50s %-15s %-20s\n" "$filename" "$size" "$date"
        
        # Show info file if it exists
        local info_file="${backup_file%.tar.gz}.info"
        if [ -f "$info_file" ]; then
            local label=$(grep "^Label:" "$info_file" | cut -d':' -f2- | xargs)
            if [ "$label" != "none" ] && [ -n "$label" ]; then
                printf "  └─ Label: %s\n" "$label"
            fi
        fi
    done <<< "$backup_files"
    
    echo ""
    local total_size=$(du -sh "$DEFAULT_BACKUP_DIR" | cut -f1)
    print_info "Total backup size: ${total_size}"
}

cmd_cleanup() {
    local container_name="${1:-$DEFAULT_CONTAINER_NAME}"
    local keep_count="${2:-$DEFAULT_MAX_BACKUPS}"
    
    if ! [[ "$keep_count" =~ ^[0-9]+$ ]] || [ "$keep_count" -lt 1 ]; then
        print_error "Invalid keep count: ${keep_count}"
        print_error "Keep count must be a positive integer"
        exit 1
    fi
    
    print_info "Cleaning up backups for: ${container_name}"
    print_info "Keeping: ${keep_count} most recent backups"
    
    if [ ! -d "$DEFAULT_BACKUP_DIR" ]; then
        print_warning "Backup directory does not exist: ${DEFAULT_BACKUP_DIR}"
        exit 0
    fi
    
    local backup_files=$(find "$DEFAULT_BACKUP_DIR" -name "${container_name}_backup_*.tar.gz" -type f | sort -r)
    local total_backups=$(echo "$backup_files" | wc -l)
    
    if [ -z "$backup_files" ] || [ "$total_backups" -eq 0 ]; then
        print_info "No backups found"
        exit 0
    fi
    
    print_info "Found ${total_backups} backups"
    
    if [ "$total_backups" -le "$keep_count" ]; then
        print_info "No cleanup needed (${total_backups} <= ${keep_count})"
        exit 0
    fi
    
    local to_delete=$((total_backups - keep_count))
    print_info "Will delete ${to_delete} old backups"
    
    local deleted_count=0
    local deleted_size=0
    
    # Delete oldest backups
    echo "$backup_files" | tail -n "$to_delete" | while IFS= read -r backup_file; do
        local size=$(stat -c %s "$backup_file")
        deleted_size=$((deleted_size + size))
        
        print_info "Deleting: $(basename "$backup_file")"
        rm -f "$backup_file"
        
        # Delete associated info file
        local info_file="${backup_file%.tar.gz}.info"
        if [ -f "$info_file" ]; then
            rm -f "$info_file"
        fi
        
        deleted_count=$((deleted_count + 1))
    done
    
    print_success "Cleanup completed: ${deleted_count} backups removed"
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
    DEFAULT_BACKUP_DIR="${ASA_BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
    DEFAULT_MAX_BACKUPS="${ASA_MAX_BACKUPS:-$DEFAULT_MAX_BACKUPS}"
    
    # Parse command
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        create)
            cmd_create "$@"
            ;;
        restore)
            cmd_restore "$@"
            ;;
        list)
            cmd_list "$@"
            ;;
        cleanup)
            cmd_cleanup "$@"
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
