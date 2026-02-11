# ARK: Survival Ascended - Management Scripts

This directory contains Linux shell scripts for managing ARK: Survival Ascended servers running in Docker containers. These scripts replace the functionality of Windows .bat files with Linux-compatible shell scripts.

## Scripts Overview

### 1. `asa-setup.sh` - Server Setup Helper
Interactive setup wizard for installing and configuring a new ARK ASA server.

**Features:**
- Automated Docker installation for Debian/Ubuntu/openSUSE
- Server directory creation
- Docker Compose configuration download
- Initial server startup
- Management scripts installation

**Usage:**
```bash
sudo ./asa-setup.sh              # Interactive setup
sudo ./asa-setup.sh --auto       # Automatic non-interactive setup
sudo ./asa-setup.sh --skip-docker # Skip Docker installation
```

---

### 2. `asa-server-manager.sh` - Main Server Management
Centralized server management script for common operations.

**Features:**
- Start/stop/restart server containers
- Server status monitoring with resource usage
- Update management with player notifications
- Live log viewing
- Backup creation
- RCON command execution
- List all server containers

**Usage:**
```bash
./asa-server-manager.sh start                    # Start server
./asa-server-manager.sh stop asa-server-1        # Stop specific server
./asa-server-manager.sh restart                  # Restart server
./asa-server-manager.sh status                   # Show server status
./asa-server-manager.sh update                   # Update and restart
./asa-server-manager.sh logs                     # View logs
./asa-server-manager.sh backup asa-server-1      # Create backup
./asa-server-manager.sh rcon asa-server-1 "saveworld"  # Execute RCON
./asa-server-manager.sh list                     # List all servers
```

**Environment Variables:**
- `ASA_COMPOSE_FILE` - Path to docker-compose.yml
- `ASA_BACKUP_DIR` - Backup directory location

---

### 3. `asa-watchdog.sh` - Server Monitoring & Auto-Restart
Monitors server health and automatically restarts crashed containers.

**Features:**
- Continuous container health monitoring
- Automatic restart on crash
- Restart loop prevention (max 3 restarts in 5 minutes)
- Automatic world save before restart
- Timestamped logging

**Usage:**
```bash
./asa-watchdog.sh                        # Monitor asa-server-1 (60s interval)
./asa-watchdog.sh asa-server-2           # Monitor asa-server-2
./asa-watchdog.sh asa-server-1 30        # 30-second check interval
```

**Run as Background Service:**
```bash
nohup ./asa-watchdog.sh asa-server-1 60 > /var/log/asa-watchdog.log 2>&1 &
```

**Systemd Service Example:**
```ini
[Unit]
Description=ARK ASA Watchdog for asa-server-1
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/usr/local/bin/asa-watchdog asa-server-1 60
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

---

### 4. `asa-scheduled-restart.sh` - Graceful Restart with Notifications
Performs scheduled server restarts with player notifications via RCON.

**Features:**
- Configurable warning times (5, 10, 15, 30, 60 minutes)
- Progressive countdown notifications
- Automatic world save before restart
- Update checking on restart

**Usage:**
```bash
./asa-scheduled-restart.sh                    # 30-min warning restart
./asa-scheduled-restart.sh asa-server-1 10   # 10-min warning
./asa-scheduled-restart.sh asa-server-2 60   # 60-min warning
```

**Crontab Examples:**
```bash
# Daily restart at 4:00 AM with 30-minute warning (starts at 3:30 AM)
30 3 * * * /usr/local/bin/asa-scheduled-restart asa-server-1 30

# Restart every 6 hours with 10-minute warning
50 */6 * * * /usr/local/bin/asa-scheduled-restart asa-server-1 10

# Weekly restart on Monday at 3:00 AM with 60-minute warning
0 2 * * 1 /usr/local/bin/asa-scheduled-restart asa-server-1 60
```

---

### 5. `asa-backup.sh` - Backup Management
Comprehensive backup creation, restoration, and management.

**Features:**
- Compressed tar.gz backups
- Automatic world save before backup
- Labeled backups for important saves
- Safe restoration with confirmation
- Automatic safety backup during restore
- Backup rotation/cleanup
- Backup listing with size and date

**Usage:**
```bash
# Create backups
./asa-backup.sh create                              # Backup asa-server-1
./asa-backup.sh create asa-server-1 "pre-update"   # Labeled backup

# List backups
./asa-backup.sh list asa-server-1

# Restore from backup
./asa-backup.sh restore asa-server-1 backup_20240204_120000.tar.gz

# Cleanup old backups
./asa-backup.sh cleanup asa-server-1 10  # Keep 10 most recent
```

**Crontab Example:**
```bash
# Daily backup at 3:00 AM
0 3 * * * /usr/local/bin/asa-backup create asa-server-1 daily

# Weekly cleanup, keep 14 backups
0 4 * * 0 /usr/local/bin/asa-backup cleanup asa-server-1 14
```

**Environment Variables:**
- `ASA_BACKUP_DIR` - Backup directory (default: `/var/lib/docker/volumes/backups`)
- `ASA_MAX_BACKUPS` - Maximum backups to keep (default: 10)

---

### 6. `asa-multimap.sh` - Multi-Map Server Management
Generate docker-compose configurations for running multiple map servers.

**Features:**
- Automatic port allocation for multiple servers
- Shared cluster storage for player transfers
- Individual volumes for each map server
- Support for all official maps
- Custom port ranges

**Usage:**
```bash
# List available maps
./asa-multimap.sh list

# Generate configuration for 3 maps
./asa-multimap.sh generate --maps "TheIsland_WP,ScorchedEarth_WP,TheCenter_WP"

# Custom ports and settings
./asa-multimap.sh generate --maps "TheIsland_WP,Aberration_WP" \
    --base-port 7780 \
    --base-rcon 27030 \
    --max-players 70 \
    --cluster-id mycluster

# Show example setup
./asa-multimap.sh example
```

**After Generating:**
```bash
# Start all servers
docker compose -f docker-compose.multi.yml up -d

# Or start individual servers
docker compose -f docker-compose.multi.yml up -d asa-server-TheIsland

# Enable watchdog for each server
sudo systemctl enable asa-watchdog@asa-server-TheIsland.service
sudo systemctl enable asa-watchdog@asa-server-ScorchedEarth.service
```

**Port Allocation:**
Each server automatically gets unique ports:
- Server 1: Game 7777, RCON 27020
- Server 2: Game 7778, RCON 27021
- Server 3: Game 7779, RCON 27022

**Available Official Maps:**
- TheIsland_WP, ScorchedEarth_WP, Aberration_WP
- Extinction_WP, Genesis_WP, Genesis2_WP
- TheCenter_WP, Ragnarok_WP, Valguero_WP
- CrystalIsles_WP, LostIsland_WP, Fjordur_WP

---


## Installation

### System-wide Installation
To install scripts system-wide (accessible from anywhere):

```bash
sudo cp scripts/*.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/asa-*.sh

# Create convenient aliases
sudo ln -s /usr/local/bin/asa-server-manager.sh /usr/local/bin/asa-server-manager
sudo ln -s /usr/local/bin/asa-watchdog.sh /usr/local/bin/asa-watchdog
sudo ln -s /usr/local/bin/asa-scheduled-restart.sh /usr/local/bin/asa-scheduled-restart
sudo ln -s /usr/local/bin/asa-backup.sh /usr/local/bin/asa-backup
```

Then you can use:
```bash
asa-server-manager start
asa-watchdog asa-server-1
asa-scheduled-restart asa-server-1 30
asa-backup create asa-server-1
```

### Local Installation
Scripts can also be run directly from the `scripts/` directory:

```bash
cd scripts/
./asa-server-manager.sh start
./asa-watchdog.sh asa-server-1
```

---

## Common Use Cases

### Daily Server Maintenance
Set up a complete daily maintenance routine:

```bash
# Edit crontab
crontab -e

# Add these lines:
# Backup at 2:00 AM
0 2 * * * /usr/local/bin/asa-backup create asa-server-1 daily

# Cleanup old backups weekly
0 3 * * 0 /usr/local/bin/asa-backup cleanup asa-server-1 14

# Daily restart at 4:00 AM with 30-minute warning
30 3 * * * /usr/local/bin/asa-scheduled-restart asa-server-1 30
```

### Quick Server Operations
```bash
# Start server
asa-server-manager start

# Check status
asa-server-manager status

# View live logs
asa-server-manager logs

# Execute RCON command
asa-server-manager rcon asa-server-1 "saveworld"
asa-server-manager rcon asa-server-1 "listplayers"
asa-server-manager rcon asa-server-1 "serverchat Hello players!"

# Update server
asa-server-manager update

# Stop server
asa-server-manager stop
```

### Backup Before Updates
```bash
# Create pre-update backup
asa-backup create asa-server-1 "pre-update"

# Perform update
asa-server-manager update

# If something goes wrong, restore
asa-backup restore asa-server-1 asa-server-1_backup_20240204_120000_pre-update.tar.gz
```

---

## Comparison to Windows .bat Files

These Linux shell scripts replace typical Windows .bat file functionality:

| Windows .bat Feature | Linux Script Equivalent |
|---------------------|------------------------|
| `taskkill /F /IM ArkServer.exe` | `docker stop asa-server-1` |
| `timeout /T 60` | `sleep 60` |
| Server restart loop | `asa-watchdog.sh` |
| SteamCMD updates | Built into container restart |
| RCON communication | `asa-ctrl rcon` (built-in) or `asa-server-manager rcon` |
| Scheduled restarts | `asa-scheduled-restart.sh` with cron |
| Backup creation | `asa-backup.sh create` |
| Process monitoring | `docker ps` + `asa-watchdog.sh` |
| Log viewing | `docker logs` or `asa-server-manager logs` |

---

## Requirements

- Docker and Docker Compose installed
- Root/sudo access for system-wide installation
- Bash 4.0 or higher
- Standard Linux utilities: `tar`, `grep`, `awk`, `sed`

---

## Troubleshooting

### Scripts don't execute
Make sure scripts are executable:
```bash
chmod +x scripts/*.sh
```

### Permission denied errors
Run with appropriate permissions:
```bash
sudo ./asa-server-manager.sh start
```

### Docker not found
Install Docker first:
```bash
sudo ./asa-setup.sh
```

### RCON commands fail
Ensure RCON is configured in `GameUserSettings.ini`:
```ini
[ServerSettings]
RCONEnabled=True
ServerAdminPassword=your_password
RCONPort=27020
```

---

## Contributing

Feel free to submit issues or pull requests to improve these scripts.

## License

These scripts are part of the ARK: Survival Ascended Linux Container Image project.
