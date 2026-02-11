# Windows .bat to Linux Migration Guide

This guide helps Windows server administrators migrate their ARK: Survival Ascended server management scripts from Windows batch files to Linux shell scripts.

## Overview

If you've been running ARK ASA servers on Windows using `.bat` files for automation, this guide will help you transition to the Linux Docker-based setup with equivalent functionality.

## Quick Comparison

### What Changed

| Windows Setup | Linux Docker Setup |
|--------------|-------------------|
| Windows Server OS | Linux (Debian/Ubuntu/openSUSE) |
| `.bat` batch files | `.sh` shell scripts |
| Task Scheduler | cron + systemd timers |
| Direct .exe execution | Docker containers |
| 7-Zip for backups | tar.gz compression |
| Windows services | systemd services |
| Direct RCON tools | Built-in `asa-ctrl` RCON |

### What Stayed the Same

- RCON protocol and commands
- Server configuration files (GameUserSettings.ini, etc.)
- Save game format and structure
- Mod and plugin support  
- Networking and port requirements

## Feature-by-Feature Migration

### 1. Server Start/Stop/Restart

**Windows (.bat):**
```batch
@echo off
start "" "C:\ArkServer\ShooterGame\Binaries\Win64\ArkAscendedServer.exe" TheIsland_WP?listen
```

**Linux (Shell Script):**
```bash
#!/bin/bash
asa-server-manager start
# or
docker start asa-server-1
```

---

### 2. Watchdog / Auto-Restart

**Windows (.bat):**
```batch
:CheckServer
tasklist | find /I "ArkAscendedServer.exe" >nul
if errorlevel 1 goto StartServer
timeout /T 60
goto CheckServer

:StartServer
echo Server crashed, restarting...
start "" "C:\ArkServer\...\ArkAscendedServer.exe" TheIsland_WP?listen
goto CheckServer
```

**Linux (Shell Script + Systemd):**
```bash
# Install watchdog service
sudo cp examples/systemd/asa-watchdog@.service /etc/systemd/system/
sudo systemctl enable asa-watchdog@asa-server-1.service
sudo systemctl start asa-watchdog@asa-server-1.service
```

**Features:**
- Monitors container health
- Restart loop prevention (max 3 in 5 min)
- Automatic world save before restart
- Logs to systemd journal

---

### 3. Backup Creation

**Windows (.bat):**
```batch
SET "BACKUP_DIR=C:\ArkServer\backups"
SET "SAVE_DIR=C:\ArkServer\ShooterGame\Saved"
"%SEVENZIP_PATH%" a -t7z "%BACKUP_FILE%" "%SAVE_DIR%\*"
```

**Linux (Shell Script):**
```bash
# Create backup
asa-backup create asa-server-1

# Create labeled backup
asa-backup create asa-server-1 "pre-update"

# List backups
asa-backup list asa-server-1

# Cleanup old backups
asa-backup cleanup asa-server-1 10
```

---

### 4. Scheduled Restarts with RCON

**Windows (.bat):**
```batch
mcrcon -H 127.0.0.1 -P %RCON_PORT% -p %ADMIN_PASSWORD% "serverchat Server restart in 15 minutes"
timeout /t 900
mcrcon -H 127.0.0.1 -P %RCON_PORT% -p %ADMIN_PASSWORD% "saveworld"
taskkill /F /IM ArkAscendedServer.exe
```

**Linux (Shell Script):**
```bash
# Restart with 30-minute warning
asa-scheduled-restart asa-server-1 30
```

---

### 5. Multi-Map Servers

**Windows (.bat):**
```batch
SET "MAP1=TheIsland_WP"
SET "MAP2=ScorchedEarth_WP"
start "" "...\ArkAscendedServer.exe" %MAP1%?listen?Port=7777 -userdir="C:\instances\map1"
start "" "...\ArkAscendedServer.exe" %MAP2%?listen?Port=7778 -userdir="C:\instances\map2"
```

**Linux (Shell Script):**
```bash
# Generate multi-map configuration
./scripts/asa-multimap.sh generate --maps "TheIsland_WP,ScorchedEarth_WP"

# Start all servers
docker compose -f docker-compose.multi.yml up -d
```

---

## Task Scheduling

### Windows Task Scheduler → Linux cron

**Windows:** GUI-based scheduling

**Linux (cron):**
```bash
# Edit crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * /usr/local/bin/asa-backup create asa-server-1 daily

# Daily restart at 4 AM with 30-min warning
30 3 * * * /usr/local/bin/asa-scheduled-restart asa-server-1 30

# Weekly cleanup
0 3 * * 0 /usr/local/bin/asa-backup cleanup asa-server-1 14
```

### Linux systemd Timers (Alternative)

```bash
# Install timers
sudo cp examples/systemd/asa-backup.timer /etc/systemd/system/asa-backup@asa-server-1.timer
sudo cp examples/systemd/asa-backup.service /etc/systemd/system/asa-backup@.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable asa-backup@asa-server-1.timer
sudo systemctl start asa-backup@asa-server-1.timer

# Check status
sudo systemctl list-timers
```

---

## Command Reference

| Windows Command | Linux Equivalent |
|----------------|------------------|
| `start server.bat` | `asa-server-manager start` |
| `taskkill /F /IM ArkServer.exe` | `asa-server-manager stop` |
| `timeout /T 60` | `sleep 60` |
| `tasklist \| find "ArkServer"` | `docker ps \| grep asa-server` |
| `mcrcon -p pass "cmd"` | `asa-server-manager rcon asa-server-1 "cmd"` |
| `7z a backup.7z files` | `asa-backup create asa-server-1` |
| Windows Service | `systemctl start asa-watchdog@asa-server-1` |
| Task Scheduler | `crontab -e` or systemd timers |

---

## Migration Checklist

### Pre-Migration
- [ ] Back up all server data and configs
- [ ] Document current settings (ports, passwords, mods)
- [ ] Note automated tasks and schedules
- [ ] Export save files

### Linux Setup
- [ ] Install Linux OS (Debian/Ubuntu recommended)
- [ ] Install Docker
  ```bash
  sudo ./scripts/asa-setup.sh
  ```
- [ ] Configure firewall

### Server Migration
- [ ] Create docker-compose.yml
- [ ] Transfer GameUserSettings.ini
- [ ] Transfer save files to Docker volume
- [ ] Test server startup
- [ ] Verify RCON connectivity

### Automation Setup
- [ ] Install management scripts
  ```bash
  sudo cp scripts/*.sh /usr/local/bin/
  sudo chmod +x /usr/local/bin/asa-*.sh
  ```
- [ ] Set up watchdog service
- [ ] Configure backup schedule
- [ ] Configure restart schedule
- [ ] Test all automation

### Validation
- [ ] Verify servers start successfully
- [ ] Test RCON commands
- [ ] Verify player connections
- [ ] Test backup/restore
- [ ] Monitor for 24-48 hours

---

## Troubleshooting

### Server Won't Start
```bash
docker logs asa-server-1
docker ps -a
systemctl status docker
```

### RCON Not Working
```bash
# Check RCON configuration
docker exec asa-server-1 cat /home/gameserver/server-files/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini | grep -i rcon

# Test RCON
docker exec asa-server-1 asa-ctrl rcon --exec "listplayers"
```

### Backups Failing
```bash
# Check disk space
df -h

# Check permissions
ls -la /var/lib/docker/volumes/backups/

# Test manual backup
asa-backup create asa-server-1 test
```

### Scheduled Tasks Not Running

**Cron:**
```bash
# Check cron service
systemctl status cron

# View logs
grep CRON /var/log/syslog
```

**Systemd Timers:**
```bash
# Check timers
systemctl list-timers

# View logs
journalctl -u asa-backup@asa-server-1.service
```

---

## Configuration Files

### Windows Paths
```
C:\ArkServer\
├── ShooterGame\
│   ├── Saved\Config\Windows\
│   │   ├── GameUserSettings.ini
│   │   └── Game.ini
│   └── SavedArks\
```

### Linux Docker Paths
```
/var/lib/docker/volumes/asa-server_server-files-1/_data/
└── ShooterGame/
    ├── Saved/Config/WindowsServer/
    │   ├── GameUserSettings.ini
    │   └── Game.ini
    └── SavedArks/
```

### Editing Config Files

```bash
# Method 1: Edit in volume directly (as root)
sudo nano /var/lib/docker/volumes/asa-server_server-files-1/_data/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini

# Method 2: Copy out, edit, copy back
docker cp asa-server-1:/home/gameserver/server-files/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini .
nano GameUserSettings.ini
docker cp GameUserSettings.ini asa-server-1:/home/gameserver/server-files/ShooterGame/Saved/Config/WindowsServer/
docker restart asa-server-1
```

---

## Performance Benefits

### Resource Usage
- **Windows:** ~13 GB RAM + Windows overhead
- **Linux:** ~13 GB RAM + minimal container overhead (~50 MB)

### Advantages
✅ Lower idle CPU usage  
✅ Better multi-server density  
✅ No antivirus overhead  
✅ Better filesystem performance  
✅ Free operating system  

---

## Getting Help

### Documentation
- [Main README](../README.md)
- [Quick Start Guide](../QUICKSTART.md)
- [Scripts Documentation](../scripts/README.md)
- [Examples](../examples/README.md)

### Support
- GitHub Issues: Bug reports and features
- ARK Forums: General server help
- Linux Communities: OS-specific questions

---

## Conclusion

Migrating to Linux provides:

✅ Better automation with systemd and cron  
✅ Improved reliability with Docker  
✅ Lower resource usage and costs  
✅ Easier multi-server management  
✅ Professional-grade tools  

Welcome to Linux server administration! 🐧🦖
