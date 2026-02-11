#!/bin/bash
################################################################################
# ARK: Survival Ascended - Multi-Map Server Management Script
# 
# This script helps manage multiple ARK ASA servers running different maps
# from a single installation. It generates docker-compose configurations
# for multiple map servers with proper port allocation.
#
# Usage: ./asa-multimap.sh [command] [options]
#
# Commands:
#   generate    - Generate docker-compose configuration for multiple maps
#   list        - List configured map servers
#   help        - Show this help message
################################################################################

set -e

# Default configuration
DEFAULT_BASE_PORT=7777
DEFAULT_BASE_RCON_PORT=27020
DEFAULT_MAX_PLAYERS=50
DEFAULT_CLUSTER_ID="default"

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
ARK: Survival Ascended - Multi-Map Server Management Script

Usage: $0 [command] [options]

Commands:
    generate    Generate docker-compose configuration for multiple maps
    list        List available map names
    example     Show example multi-map setup
    help        Show this help message

Generate Command Options:
    --maps "map1,map2,map3"     Comma-separated list of map names
    --base-port PORT            Starting game port (default: ${DEFAULT_BASE_PORT})
    --base-rcon PORT            Starting RCON port (default: ${DEFAULT_BASE_RCON_PORT})
    --max-players NUM           Max players per server (default: ${DEFAULT_MAX_PLAYERS})
    --cluster-id ID             Cluster ID for server transfers (default: ${DEFAULT_CLUSTER_ID})
    --output FILE               Output file (default: docker-compose.multi.yml)

Examples:
    # Generate config for 3 maps
    $0 generate --maps "TheIsland_WP,ScorchedEarth_WP,Aberration_WP"

    # Custom ports and players
    $0 generate --maps "TheIsland_WP,TheCenter_WP" --base-port 7780 --max-players 70

    # List available maps
    $0 list

Features:
    - Automatic port allocation (increments for each server)
    - Shared cluster storage for server transfers
    - Individual volumes for each map server
    - Proper Docker networking setup

Map Names (Official):
    - TheIsland_WP           - The Island
    - ScorchedEarth_WP       - Scorched Earth
    - Aberration_WP          - Aberration
    - Extinction_WP          - Extinction
    - Genesis_WP             - Genesis Part 1
    - Genesis2_WP            - Genesis Part 2
    - TheCenter_WP           - The Center
    - Ragnarok_WP            - Ragnarok
    - Valguero_WP            - Valguero
    - CrystalIsles_WP        - Crystal Isles
    - LostIsland_WP          - Lost Island
    - Fjordur_WP             - Fjordur

After generating the config:
    1. Review the generated docker-compose.multi.yml file
    2. Start servers: docker compose -f docker-compose.multi.yml up -d
    3. Manage servers: asa-server-manager start asa-server-TheIsland
    4. Enable watchdogs: systemctl enable asa-watchdog@asa-server-TheIsland

Port Allocation:
    Each server gets unique ports:
    - Server 1: Game 7777, RCON 27020
    - Server 2: Game 7778, RCON 27021
    - Server 3: Game 7779, RCON 27022
    etc.

Container Naming:
    Container names are derived from map names by removing the '_WP' suffix:
    - TheIsland_WP      → asa-server-TheIsland
    - ScorchedEarth_WP  → asa-server-ScorchedEarth
    - CustomMap         → asa-server-CustomMap
    
    For mod maps without '_WP', the full name is used.

EOF
    exit 0
}

# Available official map names
OFFICIAL_MAPS=(
    "TheIsland_WP"
    "ScorchedEarth_WP"
    "Aberration_WP"
    "Extinction_WP"
    "Genesis_WP"
    "Genesis2_WP"
    "TheCenter_WP"
    "Ragnarok_WP"
    "Valguero_WP"
    "CrystalIsles_WP"
    "LostIsland_WP"
    "Fjordur_WP"
)

################################################################################
# Command Functions
################################################################################

cmd_list() {
    print_info "Available Official Map Names:"
    echo ""
    printf "%-25s %s\n" "Map Name" "Display Name"
    printf "%-25s %s\n" "--------" "------------"
    printf "%-25s %s\n" "TheIsland_WP" "The Island"
    printf "%-25s %s\n" "ScorchedEarth_WP" "Scorched Earth"
    printf "%-25s %s\n" "Aberration_WP" "Aberration"
    printf "%-25s %s\n" "Extinction_WP" "Extinction"
    printf "%-25s %s\n" "Genesis_WP" "Genesis Part 1"
    printf "%-25s %s\n" "Genesis2_WP" "Genesis Part 2"
    printf "%-25s %s\n" "TheCenter_WP" "The Center"
    printf "%-25s %s\n" "Ragnarok_WP" "Ragnarok"
    printf "%-25s %s\n" "Valguero_WP" "Valguero"
    printf "%-25s %s\n" "CrystalIsles_WP" "Crystal Isles"
    printf "%-25s %s\n" "LostIsland_WP" "Lost Island"
    printf "%-25s %s\n" "Fjordur_WP" "Fjordur"
    echo ""
    print_info "You can also use mod map names if you have them installed"
}

cmd_example() {
    cat << 'EOF'
Example Multi-Map Setup
========================

1. Generate configuration for 3 maps:

    ./asa-multimap.sh generate --maps "TheIsland_WP,ScorchedEarth_WP,TheCenter_WP"

2. Review the generated file:

    cat docker-compose.multi.yml

3. Start all servers:

    docker compose -f docker-compose.multi.yml up -d

4. Or start individual servers:

    docker compose -f docker-compose.multi.yml up -d asa-server-TheIsland
    docker compose -f docker-compose.multi.yml up -d asa-server-ScorchedEarth

5. Set up watchdog for each server:

    sudo systemctl enable asa-watchdog@asa-server-TheIsland.service
    sudo systemctl enable asa-watchdog@asa-server-ScorchedEarth.service
    sudo systemctl enable asa-watchdog@asa-server-TheCenter.service
    
    sudo systemctl start asa-watchdog@asa-server-TheIsland.service
    sudo systemctl start asa-watchdog@asa-server-ScorchedEarth.service
    sudo systemctl start asa-watchdog@asa-server-TheCenter.service

6. Set up automated backups (add to crontab -e):

    # Daily backups for all servers
    0 2 * * * /usr/local/bin/asa-backup create asa-server-TheIsland daily
    0 2 * * * /usr/local/bin/asa-backup create asa-server-ScorchedEarth daily
    0 2 * * * /usr/local/bin/asa-backup create asa-server-TheCenter daily

    # Daily restarts
    30 3 * * * /usr/local/bin/asa-scheduled-restart asa-server-TheIsland 30
    30 3 * * * /usr/local/bin/asa-scheduled-restart asa-server-ScorchedEarth 30
    30 3 * * * /usr/local/bin/asa-scheduled-restart asa-server-TheCenter 30

Network Ports:
--------------
Make sure to forward these ports in your firewall:

TheIsland:       7777 UDP (game), 27020 TCP (RCON)
ScorchedEarth:   7778 UDP (game), 27021 TCP (RCON)
TheCenter:       7779 UDP (game), 27022 TCP (RCON)

Cluster Setup:
--------------
All servers share the same cluster storage, allowing players to transfer
characters and items between maps. Make sure all servers have the same
cluster ID in their configuration.

EOF
}

cmd_generate() {
    local maps=""
    local base_port=$DEFAULT_BASE_PORT
    local base_rcon_port=$DEFAULT_BASE_RCON_PORT
    local max_players=$DEFAULT_MAX_PLAYERS
    local cluster_id=$DEFAULT_CLUSTER_ID
    local output_file="docker-compose.multi.yml"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --maps)
                maps="$2"
                shift 2
                ;;
            --base-port)
                base_port="$2"
                shift 2
                ;;
            --base-rcon)
                base_rcon_port="$2"
                shift 2
                ;;
            --max-players)
                max_players="$2"
                shift 2
                ;;
            --cluster-id)
                cluster_id="$2"
                shift 2
                ;;
            --output)
                output_file="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    if [ -z "$maps" ]; then
        print_error "No maps specified. Use --maps 'map1,map2,map3'"
        echo ""
        echo "Example:"
        echo "  $0 generate --maps 'TheIsland_WP,ScorchedEarth_WP'"
        echo ""
        echo "Run '$0 list' to see available map names"
        exit 1
    fi
    
    print_info "Generating multi-map docker-compose configuration..."
    print_info "Maps: $maps"
    print_info "Base port: $base_port"
    print_info "Base RCON port: $base_rcon_port"
    print_info "Max players: $max_players"
    print_info "Cluster ID: $cluster_id"
    print_info "Output file: $output_file"
    echo ""
    
    # Check if output file exists and warn
    if [ -f "$output_file" ]; then
        print_warning "Output file already exists: $output_file"
        read -p "Overwrite? (yes/no): " -r
        echo
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            print_info "Generation cancelled"
            exit 0
        fi
    fi
    
    # Start generating the compose file
    cat > "$output_file" << 'EOF'
version: "3.3"
services:
EOF
    
    # Convert comma-separated maps to array
    IFS=',' read -ra MAP_ARRAY <<< "$maps"
    
    local server_index=0
    
    for map_name in "${MAP_ARRAY[@]}"; do
        # Trim whitespace
        map_name=$(echo "$map_name" | xargs)
        
        # Calculate ports
        local game_port=$((base_port + server_index))
        local rcon_port=$((base_rcon_port + server_index))
        
        # Generate container name from map name (remove _WP suffix)
        local container_name="asa-server-${map_name%_WP}"
        
        print_info "Configuring: $container_name ($map_name) - Port $game_port, RCON $rcon_port"
        
        # Add service definition
        cat >> "$output_file" << EOF
  ${container_name}:
    container_name: ${container_name}
    hostname: ${container_name}
    entrypoint: "/usr/bin/start_server"
    user: gameserver
    image: "mschnitzer/asa-linux-server:latest"
    tty: true
    environment:
      - ASA_START_PARAMS=${map_name}?listen?Port=${game_port}?RCONPort=${rcon_port}?RCONEnabled=True -WinLiveMaxPlayers=${max_players} -clusterid=${cluster_id} -ClusterDirOverride="/home/gameserver/cluster-shared"
      - ENABLE_DEBUG=0
    ports:
      # Game port for player connections through the server browser
      - 0.0.0.0:${game_port}:${game_port}/udp
      # RCON port for remote server administration
      - 0.0.0.0:${rcon_port}:${rcon_port}/tcp
    depends_on:
      - set-permissions-${server_index}
    volumes:
      - steam-${server_index}:/home/gameserver/Steam:rw
      - steamcmd-${server_index}:/home/gameserver/steamcmd:rw
      - server-files-${server_index}:/home/gameserver/server-files:rw
      - cluster-shared:/home/gameserver/cluster-shared:rw
      - /etc/localtime:/etc/localtime:ro
    networks:
      asa-network:
  set-permissions-${server_index}:
    entrypoint: "/bin/bash -c 'chown -R 25000:25000 /steam ; chown -R 25000:25000 /steamcmd ; chown -R 25000:25000 /server-files ; chown -R 25000:25000 /cluster-shared'"
    user: root
    image: "opensuse/leap"
    volumes:
      - steam-${server_index}:/steam:rw
      - steamcmd-${server_index}:/steamcmd:rw
      - server-files-${server_index}:/server-files:rw
      - cluster-shared:/cluster-shared:rw
EOF
        
        server_index=$((server_index + 1))
    done
    
    # Add volumes section
    cat >> "$output_file" << 'EOF'
volumes:
  cluster-shared:
EOF
    
    for ((i=0; i<server_index; i++)); do
        cat >> "$output_file" << EOF
  steam-${i}:
  steamcmd-${i}:
  server-files-${i}:
EOF
    done
    
    # Add backups volume
    cat >> "$output_file" << 'EOF'
  backups:
EOF
    
    # Add networks section
    cat >> "$output_file" << 'EOF'
networks:
  asa-network:
    attachable: true
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: 'asanet'
EOF
    
    print_success "Configuration generated: $output_file"
    echo ""
    print_info "Next steps:"
    echo "  1. Review the configuration: cat $output_file"
    echo "  2. Start all servers: docker compose -f $output_file up -d"
    echo "  3. Check status: docker compose -f $output_file ps"
    echo ""
    print_info "Port forwarding required:"
    
    server_index=0
    for map_name in "${MAP_ARRAY[@]}"; do
        map_name=$(echo "$map_name" | xargs)
        local game_port=$((base_port + server_index))
        local rcon_port=$((base_rcon_port + server_index))
        echo "  - ${map_name}: ${game_port}/UDP (game), ${rcon_port}/TCP (RCON)"
        server_index=$((server_index + 1))
    done
    echo ""
    print_info "For cluster transfers, all servers must have the same cluster ID: $cluster_id"
}

################################################################################
# Main
################################################################################

main() {
    # Parse command
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        generate)
            cmd_generate "$@"
            ;;
        list)
            cmd_list
            ;;
        example)
            cmd_example
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
