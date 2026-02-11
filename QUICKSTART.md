# Quick Start Guide - ARK ASA Server Management Scripts

This guide helps you quickly get started with the new Linux management scripts.

## 5-Minute Setup

### 1. Clone or Download Repository
```bash
git clone https://github.com/slick200201-hub/ark-survival-ascended-linux-container-image.git
cd ark-survival-ascended-linux-container-image
```

### 2. Automated Setup (Recommended for New Servers)
```bash
sudo ./scripts/asa-setup.sh
```

This will:
- Install Docker (if needed)
- Configure Docker data directory (optional)
- Create server directory
- Download configuration
- Start your server
- Install management scripts

#### Choosing Docker Data Directory (Optional)

By default, Docker stores all data in `/var/lib/docker`. If you have multiple drives, you can configure Docker to use a different location during setup.

**Benefits:**
- Keep OS and system files on a smaller, faster SSD
- Store large game/server files on a larger storage drive
- Better disk space management

**During interactive setup:**
You'll be prompted to enter a custom path, for example:
- `/mnt/storage/docker` - if you have a separate drive mounted at /mnt/storage
- `/home/docker` - to use your home partition
- Press Enter to use default `/var/lib/docker`

**For automated setup:**
```bash
sudo DOCKER_DATA_ROOT=/mnt/storage/docker ./scripts/asa-setup.sh --auto
```

**Storage requirements:**
- Minimum: 50 GB free space
- Recommended: 100+ GB free space
- Actual usage: ~11 GB (server files) + ~13 GB (runtime) + backups

### 3. Or Install Scripts Manually (For Existing Servers)
```bash
sudo cp scripts/*.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/asa-*.sh

# Create convenient aliases
sudo ln -s /usr/local/bin/asa-server-manager.sh /usr/local/bin/asa-server-manager
sudo ln -s /usr/local/bin/asa-watchdog.sh /usr/local/bin/asa-watchdog
sudo ln -s /usr/local/bin/asa-scheduled-restart.sh /usr/local/bin/asa-scheduled-restart
sudo ln -s /usr/local/bin/asa-backup.sh /usr/local/bin/asa-backup
```

## Essential Commands

### Server Control
```bash
asa-server-manager start              # Start server
asa-server-manager stop               # Stop server
asa-server-manager restart            # Restart server
asa-server-manager status             # Show status
asa-server-manager logs               # View logs (Ctrl+C to exit)
```

### Updates
```bash
asa-server-manager update             # Update with 5-min player warnings
```

### Backups
```bash
asa-backup create asa-server-1                   # Create backup
asa-backup list asa-server-1                     # List backups
asa-backup restore asa-server-1 backup_file.tar.gz  # Restore backup
```

### RCON Commands
```bash
asa-server-manager rcon asa-server-1 "saveworld"
asa-server-manager rcon asa-server-1 "listplayers"
asa-server-manager rcon asa-server-1 "serverchat Hello everyone!"
```

## Set Up Automatic Crash Recovery

```bash
# Copy service file
sudo cp examples/systemd/asa-watchdog@.service /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable asa-watchdog@asa-server-1.service
sudo systemctl start asa-watchdog@asa-server-1.service

# Check status
sudo systemctl status asa-watchdog@asa-server-1.service
```

## Set Up Daily Restarts and Backups

```bash
# Edit crontab
crontab -e

# Add these lines:
# Daily backup at 2 AM
0 2 * * * /usr/local/bin/asa-backup create asa-server-1 daily

# Daily restart at 4 AM with 30-min warning (starts at 3:30 AM)
30 3 * * * /usr/local/bin/asa-scheduled-restart asa-server-1 30

# Weekly cleanup - keep 14 backups
0 3 * * 0 /usr/local/bin/asa-backup cleanup asa-server-1 14
```

## Troubleshooting

### Server won't start
```bash
# Check logs
asa-server-manager logs

# Check Docker
sudo systemctl status docker

# Check container exists
docker ps -a | grep asa-server
```

### Scripts not found
```bash
# Make sure they're installed
ls -l /usr/local/bin/asa-*

# Or run from scripts directory
cd /path/to/repo/scripts
./asa-server-manager.sh help
```

### RCON not working
Edit your GameUserSettings.ini:
```ini
[ServerSettings]
RCONEnabled=True
ServerAdminPassword=your_password
RCONPort=27020
```

Then restart server:
```bash
asa-server-manager restart
```

## Need More Help?

- **Full Documentation**: See [scripts/README.md](scripts/README.md)
- **Examples**: See [examples/README.md](examples/README.md)
- **Main README**: See [README.md](README.md)
- **Technical Details**: See [IMPLEMENTATION.md](IMPLEMENTATION.md)

## Common Workflows

### Before Update
```bash
# 1. Create backup
asa-backup create asa-server-1 pre-update

# 2. Notify players (if server is running)
asa-server-manager rcon asa-server-1 "serverchat Server will restart for updates in 5 minutes"

# 3. Wait then update
sleep 300
asa-server-manager update
```

### After Crash
```bash
# If watchdog is not running, manually check and restart:
asa-server-manager status
asa-server-manager start
```

### Multiple Servers
```bash
# Just change the server name in commands:
asa-server-manager start asa-server-1
asa-server-manager start asa-server-2
asa-backup create asa-server-1
asa-backup create asa-server-2
```

## Running Multiple Map Servers

Want to run multiple maps (cluster)?

```bash
# Generate multi-map configuration
./scripts/asa-multimap.sh generate --maps "TheIsland_WP,ScorchedEarth_WP,TheCenter_WP"

# Start all servers
docker compose -f docker-compose.multi.yml up -d

# Set up watchdog for each
sudo systemctl enable asa-watchdog@asa-server-TheIsland.service
sudo systemctl enable asa-watchdog@asa-server-ScorchedEarth.service
sudo systemctl enable asa-watchdog@asa-server-TheCenter.service

sudo systemctl start asa-watchdog@asa-server-TheIsland.service
sudo systemctl start asa-watchdog@asa-server-ScorchedEarth.service
sudo systemctl start asa-watchdog@asa-server-TheCenter.service
```

Each server gets unique ports (7777, 7778, 7779, etc.) and shares cluster data for player transfers.

See [Multi-Map Documentation](scripts/asa-multimap.sh) for full details.

## What Replaced Windows .bat Files

| What You Used to Do | Now Do This |
|-------------------|-------------|
| Run `start_server.bat` | `asa-server-manager start` |
| Run `stop_server.bat` | `asa-server-manager stop` |
| Run `restart_server.bat` | `asa-server-manager restart` |
| Run `backup.bat` | `asa-backup create asa-server-1` |
| Run `update.bat` | `asa-server-manager update` |
| Task Scheduler restarts | `crontab -e` + add schedule |
| Watchdog .bat | `systemctl start asa-watchdog@...` |
| Multi-map .bat files | `./scripts/asa-multimap.sh generate` |

**For complete Windows to Linux migration guide, see [docs/BATCH_MIGRATION.md](docs/BATCH_MIGRATION.md)**

That's it! You're now managing your ARK ASA server with Linux shell scripts.
