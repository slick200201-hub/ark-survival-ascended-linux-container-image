# ARK: Survival Ascended - Configuration Examples

This directory contains examples and templates to help you set up and maintain your ARK: Survival Ascended server.

## Directory Structure

```
examples/
├── cron/               # Automated task scheduling examples
│   ├── README.md
│   ├── daily-maintenance.cron
│   └── advanced-schedule.cron
└── systemd/            # System service examples
    ├── README.md
    └── asa-watchdog@.service
```

## What's Included

### Cron Examples
Automated scheduling for:
- Server backups (daily, weekly, monthly)
- Scheduled restarts with player notifications
- Regular world saves
- Maintenance tasks (dino wipes, announcements)
- Backup cleanup and rotation

See [cron/README.md](cron/README.md) for details.

### Systemd Services
System service definitions for:
- Watchdog service (automatic crash recovery)
- Auto-start on system boot
- Centralized logging via systemd journal

See [systemd/README.md](systemd/README.md) for details.

## Quick Setup Guide

### 1. Install Management Scripts

First, install the management scripts system-wide:

```bash
cd /path/to/repo
sudo cp scripts/*.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/asa-*.sh

# Create convenient symlinks
sudo ln -s /usr/local/bin/asa-server-manager.sh /usr/local/bin/asa-server-manager
sudo ln -s /usr/local/bin/asa-watchdog.sh /usr/local/bin/asa-watchdog
sudo ln -s /usr/local/bin/asa-scheduled-restart.sh /usr/local/bin/asa-scheduled-restart
sudo ln -s /usr/local/bin/asa-backup.sh /usr/local/bin/asa-backup
```

### 2. Set Up Watchdog Service (Optional but Recommended)

The watchdog service monitors your server and automatically restarts it if it crashes:

```bash
# Copy service file
sudo cp examples/systemd/asa-watchdog@.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable and start for your server
sudo systemctl enable asa-watchdog@asa-server-1.service
sudo systemctl start asa-watchdog@asa-server-1.service

# Check status
sudo systemctl status asa-watchdog@asa-server-1.service
```

### 3. Set Up Automated Maintenance

Schedule regular backups and restarts:

```bash
# Edit your crontab
crontab -e

# Add contents from examples/cron/daily-maintenance.cron
# Adjust server names and times as needed
```

Basic schedule:
```cron
# Daily backup at 2:00 AM
0 2 * * * /usr/local/bin/asa-backup create asa-server-1 daily

# Weekly cleanup - keep 14 backups
0 3 * * 0 /usr/local/bin/asa-backup cleanup asa-server-1 14

# Daily restart at 4:00 AM with 30-min warning
30 3 * * * /usr/local/bin/asa-scheduled-restart asa-server-1 30
```

## Common Setups

### Home Server (Casual)
```bash
# Watchdog for crash recovery
sudo systemctl enable asa-watchdog@asa-server-1.service

# Daily backup + weekly restart
crontab -e
# Add:
# 0 3 * * * /usr/local/bin/asa-backup create asa-server-1
# 30 3 * * 0 /usr/local/bin/asa-scheduled-restart asa-server-1 30
```

### Dedicated Server (Active Community)
```bash
# Watchdog service
sudo systemctl enable asa-watchdog@asa-server-1.service

# Multiple daily backups, daily restarts
crontab -e
# Add:
# 0 2,8,14,20 * * * /usr/local/bin/asa-backup create asa-server-1
# 0 3 * * 0 /usr/local/bin/asa-backup cleanup asa-server-1 20
# 30 3 * * * /usr/local/bin/asa-scheduled-restart asa-server-1 30
```

### Production Server (24/7 High Traffic)
```bash
# Watchdog service
sudo systemctl enable asa-watchdog@asa-server-1.service

# Hourly backups during peak, twice-daily restarts
crontab -e
# Use advanced-schedule.cron as template
```

## Testing Your Setup

### Test Backup
```bash
# Create a test backup
asa-backup create asa-server-1 test

# List backups
asa-backup list asa-server-1

# Clean up test backup
rm /var/lib/docker/volumes/backups/asa-server-1_backup_*_test.tar.gz
```

### Test Scheduled Restart
```bash
# Test with short warning time
asa-scheduled-restart asa-server-1 5
```

### Test Watchdog
```bash
# Run watchdog in foreground for testing
asa-watchdog asa-server-1 30

# In another terminal, stop the container
docker stop asa-server-1

# Watch watchdog detect and restart it
```

### Test Cron Job
```bash
# Run a cron command manually
/usr/local/bin/asa-backup create asa-server-1 manual-test

# Check it worked
asa-backup list asa-server-1
```

## Monitoring

### Check Watchdog Service
```bash
# Status
sudo systemctl status asa-watchdog@asa-server-1.service

# Logs
sudo journalctl -u asa-watchdog@asa-server-1.service -f
```

### Check Cron Jobs
```bash
# View scheduled jobs
crontab -l

# View recent cron activity
sudo grep CRON /var/log/syslog | tail -n 20
```

### Server Status
```bash
# Quick status
asa-server-manager status asa-server-1

# Live logs
asa-server-manager logs asa-server-1

# Resource usage
docker stats asa-server-1 --no-stream
```

## Troubleshooting

### Watchdog not starting
```bash
# Check service status
sudo systemctl status asa-watchdog@asa-server-1.service

# View detailed logs
sudo journalctl -u asa-watchdog@asa-server-1.service -n 50 --no-pager

# Verify script exists
ls -l /usr/local/bin/asa-watchdog
```

### Cron jobs not running
```bash
# Check cron service
sudo systemctl status cron

# Test command manually
/usr/local/bin/asa-backup create asa-server-1 test

# Add logging to cron commands
0 2 * * * /usr/local/bin/asa-backup create asa-server-1 >> /var/log/asa-backup.log 2>&1
```

### Backup failures
```bash
# Check backup directory permissions
ls -ld /var/lib/docker/volumes/backups

# Create directory if missing
sudo mkdir -p /var/lib/docker/volumes/backups
sudo chmod 755 /var/lib/docker/volumes/backups

# Check disk space
df -h
```

## Customization

### Change Backup Location
```bash
# Set environment variable
export ASA_BACKUP_DIR=/mnt/backups/asa

# Or add to crontab
echo "ASA_BACKUP_DIR=/mnt/backups/asa" >> ~/.bashrc

# Or modify scripts directly
```

### Adjust Watchdog Check Interval
Edit the systemd service file:
```ini
ExecStart=/usr/local/bin/asa-watchdog %i 30
#                                          ^^ Change this number
```

Then reload:
```bash
sudo systemctl daemon-reload
sudo systemctl restart asa-watchdog@asa-server-1.service
```

### Multiple Servers
All scripts support multiple servers. Just change the server name:

```bash
# Server 1
asa-backup create asa-server-1
sudo systemctl enable asa-watchdog@asa-server-1.service

# Server 2  
asa-backup create asa-server-2
sudo systemctl enable asa-watchdog@asa-server-2.service
```

## Best Practices

1. **Always test changes** on a test server first
2. **Monitor logs** after implementing automation
3. **Backup before updates** - use labeled backups
4. **Set up alerts** for failed cron jobs (via email or monitoring tools)
5. **Document your schedule** - note why restarts happen at specific times
6. **Review and update** - regularly check if schedules still make sense
7. **Test restores** - periodically verify backups can be restored

## Additional Resources

- [Scripts Documentation](../scripts/README.md)
- [Cron Examples](cron/README.md)
- [Systemd Examples](systemd/README.md)
- [Main README](../README.md)
