#!/bin/bash
################################################################################
# ARK: Survival Ascended - Setup Helper Script
# 
# This script provides an interactive setup wizard for ARK ASA servers on
# Linux systems using Docker. It replaces Windows PowerShell setup scripts
# with Linux shell script equivalents.
#
# Usage: ./asa-setup.sh [--auto] [--skip-docker]
#
# Options:
#   --auto         Run in automatic mode (non-interactive)
#   --skip-docker  Skip Docker installation
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
AUTO_MODE=false
SKIP_DOCKER=false

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

press_enter() {
    if [ "$AUTO_MODE" = false ]; then
        echo ""
        read -p "Press Enter to continue..."
        echo ""
    fi
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$AUTO_MODE" = true ]; then
        return 0
    fi
    
    while true; do
        if [ "$default" = "y" ]; then
            read -p "${prompt} [Y/n]: " -r response
            response=${response:-y}
        else
            read -p "${prompt} [y/N]: " -r response
            response=${response:-n}
        fi
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                print_warning "Please answer yes or no"
                ;;
        esac
    done
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        print_info "Please run: sudo $0"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
}

################################################################################
# Installation Functions
################################################################################

install_docker_debian() {
    print_header "Installing Docker (Debian/Ubuntu)"
    
    print_info "Updating package index..."
    apt-get update
    
    print_info "Installing prerequisites..."
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    print_info "Adding Docker's official GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    print_info "Setting up Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    print_info "Installing Docker Engine..."
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    print_success "Docker installed successfully"
}

install_docker_ubuntu() {
    print_header "Installing Docker (Ubuntu)"
    
    print_info "Updating package index..."
    apt-get update
    
    print_info "Installing prerequisites..."
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    print_info "Adding Docker's official GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    print_info "Setting up Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    print_info "Installing Docker Engine..."
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    print_success "Docker installed successfully"
}

install_docker_opensuse() {
    print_header "Installing Docker (openSUSE)"
    
    print_info "Installing Docker and Docker Compose..."
    zypper install -y docker docker-compose
    
    print_success "Docker installed successfully"
}

start_docker() {
    print_header "Starting Docker Service"
    
    print_info "Starting Docker daemon..."
    systemctl start docker
    
    print_info "Enabling Docker to start on boot..."
    systemctl enable docker
    
    if systemctl is-active --quiet docker; then
        print_success "Docker is running"
    else
        print_error "Failed to start Docker"
        exit 1
    fi
}

configure_docker_data_root() {
    print_header "Docker Data Directory Configuration"
    
    local default_data_root="/var/lib/docker"
    local custom_data_root=""
    
    # Helper function to create daemon.json
    create_daemon_json() {
        local data_root="$1"
        mkdir -p /etc/docker
        cat > /etc/docker/daemon.json <<EOF
{
  "data-root": "${data_root}"
}
EOF
    }
    
    if [ "$AUTO_MODE" = false ]; then
        echo ""
        print_info "Docker stores all container data, volumes, and images in a data directory."
        print_info "Default location: ${default_data_root}"
        print_info "Recommended: Use a separate drive with more storage capacity."
        echo ""
        print_info "Examples:"
        print_info "  /mnt/4tb-ssd/docker    - Custom mounted drive"
        print_info "  /home/docker           - Home partition"
        print_info "  ${default_data_root}   - System default (press Enter)"
        echo ""
        
        read -p "Docker data directory [${default_data_root}]: " custom_data_root
        custom_data_root=${custom_data_root:-$default_data_root}
        
        # Validate and create directory
        if [ "$custom_data_root" != "$default_data_root" ]; then
            print_info "Using custom data directory: ${custom_data_root}"
            
            # Check if directory exists
            if [ ! -d "$custom_data_root" ]; then
                if confirm "Directory does not exist. Create it?"; then
                    if ! mkdir -p "$custom_data_root" 2>/dev/null; then
                        print_error "Failed to create directory: ${custom_data_root}"
                        print_error "Please check permissions and try again"
                        exit 1
                    fi
                    print_success "Directory created: ${custom_data_root}"
                else
                    print_error "Cannot proceed without a valid directory"
                    exit 1
                fi
            fi
            
            # Check available space
            if available_gb=$(df -BG "$custom_data_root" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//'); then
                # Handle edge cases: empty, non-numeric, or fractional values
                if [[ "$available_gb" =~ ^[0-9]+$ ]]; then
                    print_info "Available space: ${available_gb} GB"
                    
                    if [ "$available_gb" -lt 50 ]; then
                        print_warning "Warning: Less than 50 GB available. Recommended: 100+ GB"
                        if ! confirm "Continue anyway?"; then
                            exit 1
                        fi
                    fi
                else
                    print_warning "Could not determine available disk space"
                    if ! confirm "Continue anyway?"; then
                        exit 1
                    fi
                fi
            else
                print_warning "Could not determine available disk space"
                if ! confirm "Continue anyway?"; then
                    exit 1
                fi
            fi
            
            # Configure Docker daemon
            print_info "Configuring Docker daemon..."
            create_daemon_json "$custom_data_root"
            
            print_success "Docker configured to use: ${custom_data_root}"
            print_info "All server files, volumes, and backups will be stored here."
        else
            print_info "Using default Docker data directory"
        fi
    else
        # Auto mode - use environment variable if set
        if [ -n "${DOCKER_DATA_ROOT:-}" ]; then
            if ! mkdir -p "$DOCKER_DATA_ROOT" 2>/dev/null; then
                print_error "Failed to create Docker data directory: ${DOCKER_DATA_ROOT}"
                print_error "Please check the path and permissions"
                exit 1
            fi
            create_daemon_json "$DOCKER_DATA_ROOT"
            print_info "Docker configured to use: ${DOCKER_DATA_ROOT}"
        fi
    fi
}

create_server_directory() {
    print_header "Creating Server Directory"
    
    local install_dir="/opt/asa-server"
    
    if [ "$AUTO_MODE" = false ]; then
        read -p "Installation directory [$install_dir]: " custom_dir
        install_dir=${custom_dir:-$install_dir}
    fi
    
    print_info "Creating directory: $install_dir"
    mkdir -p "$install_dir"
    cd "$install_dir"
    
    print_success "Directory created: $install_dir"
    echo "$install_dir"
}

download_docker_compose() {
    print_header "Downloading Docker Compose Configuration"
    
    local compose_url="https://raw.githubusercontent.com/slick200201-hub/ark-survival-ascended-linux-container-image/main/docker-compose.yml"
    
    print_info "Downloading docker-compose.yml..."
    if curl -fsSL "$compose_url" -o docker-compose.yml; then
        print_success "docker-compose.yml downloaded"
    else
        print_error "Failed to download docker-compose.yml"
        exit 1
    fi
}

configure_server() {
    print_header "Server Configuration"
    
    if [ "$AUTO_MODE" = true ]; then
        print_info "Skipping configuration in auto mode"
        return
    fi
    
    print_info "Current start parameters in docker-compose.yml:"
    grep "ASA_START_PARAMS=" docker-compose.yml | head -1
    echo ""
    
    if confirm "Would you like to customize the server settings now?"; then
        echo ""
        print_info "You can edit the docker-compose.yml file to change:"
        print_info "  - Server name (SessionName)"
        print_info "  - Map (TheIsland_WP, ScorchedEarth_WP, etc.)"
        print_info "  - Ports (Port, RCONPort)"
        print_info "  - Player limit (WinLiveMaxPlayers)"
        print_info "  - Admin password (in GameUserSettings.ini after first start)"
        echo ""
        
        if command -v nano &> /dev/null; then
            if confirm "Would you like to edit docker-compose.yml now with nano?"; then
                nano docker-compose.yml
            fi
        else
            print_warning "Text editor 'nano' not found"
            print_info "You can edit docker-compose.yml manually with your preferred editor"
        fi
    fi
}

start_server() {
    print_header "Starting ARK Server"
    
    print_info "Starting server for the first time..."
    print_info "This will download:"
    print_info "  - ARK: Survival Ascended server files (~11 GB)"
    print_info "  - Proton compatibility layer"
    print_info "  - Steam runtime"
    echo ""
    print_warning "First startup may take 15-30 minutes depending on your internet connection"
    echo ""
    
    if [ "$AUTO_MODE" = false ]; then
        if ! confirm "Start the server now?" "y"; then
            print_info "Skipping server start"
            print_info "To start later, run: docker compose up -d"
            return
        fi
    fi
    
    print_info "Starting server..."
    docker compose up -d
    
    print_success "Server container started"
    echo ""
    print_info "Follow server startup progress with:"
    print_info "  docker logs -f asa-server-1"
    echo ""
    print_info "Once started, find your server name with:"
    print_info "  docker exec asa-server-1 cat server-files/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini | grep SessionName"
}

install_management_scripts() {
    print_header "Installing Management Scripts"
    
    if [ ! -d "scripts" ]; then
        print_info "Management scripts not found in current directory"
        return
    fi
    
    print_info "Installing management scripts to /usr/local/bin..."
    
    if [ -f "scripts/asa-server-manager.sh" ]; then
        cp scripts/asa-server-manager.sh /usr/local/bin/asa-server-manager
        chmod +x /usr/local/bin/asa-server-manager
        print_success "Installed: asa-server-manager"
    fi
    
    if [ -f "scripts/asa-watchdog.sh" ]; then
        cp scripts/asa-watchdog.sh /usr/local/bin/asa-watchdog
        chmod +x /usr/local/bin/asa-watchdog
        print_success "Installed: asa-watchdog"
    fi
    
    if [ -f "scripts/asa-scheduled-restart.sh" ]; then
        cp scripts/asa-scheduled-restart.sh /usr/local/bin/asa-scheduled-restart
        chmod +x /usr/local/bin/asa-scheduled-restart
        print_success "Installed: asa-scheduled-restart"
    fi
    
    if [ -f "scripts/asa-backup.sh" ]; then
        cp scripts/asa-backup.sh /usr/local/bin/asa-backup
        chmod +x /usr/local/bin/asa-backup
        print_success "Installed: asa-backup"
    fi
    
    echo ""
    print_success "Management scripts installed"
    print_info "You can now use these commands:"
    print_info "  asa-server-manager  - Main server management"
    print_info "  asa-watchdog        - Server monitoring"
    print_info "  asa-scheduled-restart - Graceful restarts"
    print_info "  asa-backup          - Backup management"
}

show_final_info() {
    print_header "Setup Complete!"
    
    print_success "ARK: Survival Ascended server setup is complete"
    echo ""
    print_info "Next steps:"
    print_info "1. Wait for server to finish downloading and starting"
    print_info "2. Configure your server in GameUserSettings.ini"
    print_info "3. Set up port forwarding if needed (7777/UDP, 27020/TCP)"
    print_info "4. Configure RCON password for remote management"
    echo ""
    print_info "Useful commands:"
    print_info "  docker logs -f asa-server-1              # View server logs"
    print_info "  docker compose stop asa-server-1         # Stop server"
    print_info "  docker compose start asa-server-1        # Start server"
    print_info "  docker compose restart asa-server-1      # Restart server"
    print_info "  docker exec asa-server-1 asa-ctrl rcon --exec 'saveworld'  # RCON command"
    echo ""
    print_info "Server files location:"
    print_info "  /var/lib/docker/volumes/asa-server_server-files-1/_data"
    echo ""
    print_info "Configuration files:"
    print_info "  GameUserSettings.ini: /var/lib/docker/volumes/asa-server_server-files-1/_data/ShooterGame/Saved/Config/WindowsServer/"
    echo ""
    print_info "Documentation:"
    print_info "  https://github.com/slick200201-hub/ark-survival-ascended-linux-container-image"
    echo ""
}

################################################################################
# Main
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                AUTO_MODE=true
                shift
                ;;
            --skip-docker)
                SKIP_DOCKER=true
                shift
                ;;
            --help|-h)
                cat << EOF
ARK: Survival Ascended - Setup Helper Script

Usage: $0 [options]

Options:
    --auto         Run in automatic mode (non-interactive)
    --skip-docker  Skip Docker installation
    --help         Show this help message

Environment Variables:
    DOCKER_DATA_ROOT    Set custom Docker data directory (for --auto mode)

This script will:
    1. Install Docker and Docker Compose (if needed)
    2. Configure Docker data directory (optional - recommended for separate drives)
    3. Create installation directory
    4. Download docker-compose.yml configuration
    5. Start the ARK server container
    6. Install management scripts

Examples:
    # Interactive setup with prompts
    sudo ./asa-setup.sh

    # Automated setup with custom Docker location
    sudo DOCKER_DATA_ROOT=/mnt/4tb-ssd/docker ./asa-setup.sh --auto

    # Skip Docker installation (already installed)
    sudo ./asa-setup.sh --skip-docker

Storage Locations After Setup:
    (Where <data-root> is your configured Docker data directory)
    - Server files: <data-root>/volumes/asa-server_server-files-1/_data
    - Backups: <data-root>/volumes/backups
    - Steam/Proton: <data-root>/volumes/asa-server_steam-1/
    
    Example with default: /var/lib/docker/volumes/asa-server_server-files-1/_data
    Example with custom: /mnt/4tb-ssd/docker/volumes/asa-server_server-files-1/_data

EOF
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Print welcome message
    print_header "ARK: Survival Ascended - Linux Setup"
    
    print_info "This script will help you set up an ARK: Survival Ascended dedicated server"
    print_info "on your Linux system using Docker."
    echo ""
    
    if [ "$AUTO_MODE" = false ]; then
        if ! confirm "Do you want to continue?"; then
            print_info "Setup cancelled"
            exit 0
        fi
    fi
    
    # Check if running as root
    check_root
    
    # Detect OS
    local os_id=$(detect_os)
    print_info "Detected OS: $os_id"
    press_enter
    
    # Install Docker if needed
    if [ "$SKIP_DOCKER" = false ]; then
        if command -v docker &> /dev/null; then
            print_success "Docker is already installed"
        else
            case "$os_id" in
                debian)
                    install_docker_debian
                    ;;
                ubuntu)
                    install_docker_ubuntu
                    ;;
                opensuse*)
                    install_docker_opensuse
                    ;;
                *)
                    print_warning "Unsupported OS: $os_id"
                    print_info "Please install Docker manually"
                    exit 1
                    ;;
            esac
        fi
        
        # Configure Docker data directory BEFORE starting Docker
        configure_docker_data_root
        press_enter
        
        # Start Docker service
        start_docker
        press_enter
    else
        print_info "Skipping Docker installation"
    fi
    
    # Create server directory
    local install_dir=$(create_server_directory)
    press_enter
    
    # Download docker-compose.yml
    download_docker_compose
    press_enter
    
    # Configure server
    configure_server
    press_enter
    
    # Install management scripts if available
    install_management_scripts
    press_enter
    
    # Start server
    start_server
    press_enter
    
    # Show final information
    show_final_info
}

main "$@"
