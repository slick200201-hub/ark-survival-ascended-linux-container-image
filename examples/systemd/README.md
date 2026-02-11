# ARK: Survival Ascended - Systemd Service Examples

This directory contains example systemd service files for running ARK ASA management scripts as system services.

## Watchdog Service

The watchdog service monitors your ARK server container and automatically restarts it if it crashes.

### Installation

1. Copy the service file to systemd directory:
```bash
sudo cp asa-watchdog@.service /etc/systemd/system/
```

2. Reload systemd:
```bash
sudo systemctl daemon-reload
```

3. Enable and start the watchdog for your server:
```bash
# For asa-server-1
sudo systemctl enable asa-watchdog@asa-server-1.service
sudo systemctl start asa-watchdog@asa-server-1.service

# For asa-server-2
sudo systemctl enable asa-watchdog@asa-server-2.service
sudo systemctl start asa-watchdog@asa-server-2.service
```

### Management

Check status:
```bash
sudo systemctl status asa-watchdog@asa-server-1.service
```

View logs:
```bash
sudo journalctl -u asa-watchdog@asa-server-1.service -f
```

Stop the watchdog:
```bash
sudo systemctl stop asa-watchdog@asa-server-1.service
```

Restart the watchdog:
```bash
sudo systemctl restart asa-watchdog@asa-server-1.service
```

Disable auto-start:
```bash
sudo systemctl disable asa-watchdog@asa-server-1.service
```

## Benefits of Using Systemd Services

1. **Automatic Startup**: Services start automatically on system boot
2. **Crash Recovery**: If the watchdog script itself crashes, systemd will restart it
3. **Centralized Logging**: All output goes to systemd journal
4. **Service Management**: Use standard systemctl commands for control
5. **Resource Limits**: Can set CPU/memory limits via systemd

## Customization

You can customize the service file by editing it before installation:

- Change the check interval by modifying the `ExecStart` line
- Add resource limits with `MemoryLimit=` or `CPUQuota=`
- Change the restart policy with `Restart=` and `RestartSec=`

Example with custom interval (30 seconds instead of 60):
```ini
ExecStart=/usr/local/bin/asa-watchdog %i 30
```

## Multiple Servers

The `@` in the service filename makes it a template. You can run multiple instances:

```bash
# Enable watchdog for multiple servers
sudo systemctl enable asa-watchdog@asa-server-1.service
sudo systemctl enable asa-watchdog@asa-server-2.service
sudo systemctl enable asa-watchdog@asa-server-3.service

# Start all at once
sudo systemctl start asa-watchdog@*.service

# Check status of all
sudo systemctl status asa-watchdog@*.service
```

## Troubleshooting

If the service fails to start:

1. Check logs:
```bash
sudo journalctl -u asa-watchdog@asa-server-1.service -n 50
```

2. Verify the script is installed:
```bash
ls -l /usr/local/bin/asa-watchdog
```

3. Test the script manually:
```bash
/usr/local/bin/asa-watchdog asa-server-1 60
```

4. Verify Docker is running:
```bash
sudo systemctl status docker
```

---

## Backup Timer Service

Automate backups using systemd timers instead of cron.

### Installation

1. Copy the timer and service files:
```bash
sudo cp asa-backup.timer /etc/systemd/system/asa-backup@asa-server-1.timer
sudo cp asa-backup.service /etc/systemd/system/asa-backup@.service
```

2. Reload systemd:
```bash
sudo systemctl daemon-reload
```

3. Enable and start the timer:
```bash
sudo systemctl enable asa-backup@asa-server-1.timer
sudo systemctl start asa-backup@asa-server-1.timer
```

### Management

Check timer status:
```bash
# List all timers
sudo systemctl list-timers

# Check specific timer
sudo systemctl status asa-backup@asa-server-1.timer
```

View backup logs:
```bash
sudo journalctl -u asa-backup@asa-server-1.service -f
```

Manually trigger backup:
```bash
sudo systemctl start asa-backup@asa-server-1.service
```

### Default Schedule

The timer runs daily at 2:00 AM with a 5-minute random delay to prevent all servers from backing up simultaneously.

To customize the schedule, edit the timer file before installation:
```ini
[Timer]
OnCalendar=*-*-* 03:00:00  # Change to 3:00 AM
```

---

## Restart Timer Service

Automate server restarts with player warnings using systemd timers.

### Installation

1. Copy the timer and service files:
```bash
sudo cp asa-restart.timer /etc/systemd/system/asa-restart@asa-server-1.timer
sudo cp asa-restart.service /etc/systemd/system/asa-restart@.service
```

2. Reload systemd:
```bash
sudo systemctl daemon-reload
```

3. Enable and start the timer:
```bash
sudo systemctl enable asa-restart@asa-server-1.timer
sudo systemctl start asa-restart@asa-server-1.timer
```

### Management

Check timer status:
```bash
sudo systemctl list-timers
sudo systemctl status asa-restart@asa-server-1.timer
```

View restart logs:
```bash
sudo journalctl -u asa-restart@asa-server-1.service -f
```

Manually trigger restart:
```bash
sudo systemctl start asa-restart@asa-server-1.service
```

### Default Schedule

The timer runs daily at 4:00 AM. The restart script uses a 30-minute warning period, so the actual restart happens at 4:30 AM.

### Customizing Warning Time

To change the warning time, create an override:
```bash
sudo systemctl edit asa-restart@asa-server-1.service
```

Add:
```ini
[Service]
ExecStart=
ExecStart=/usr/local/bin/asa-scheduled-restart %i 60
```

This changes the warning time to 60 minutes.

---

## Systemd Timers vs Cron

### Advantages of Systemd Timers:

1. **Better Logging**: Integrated with journalctl
2. **Dependencies**: Can depend on other services
3. **Failure Handling**: Built-in retry mechanisms
4. **Calendar Events**: More flexible scheduling syntax
5. **Monitoring**: Easy to check timer status

### When to Use Each:

**Use Systemd Timers:**
- Production servers
- Need dependency management
- Want centralized logging
- Prefer systemctl interface

**Use Cron:**
- Simple schedules
- Familiar with crontab
- Need user-level scheduling
- Lightweight servers

---

## Complete Multi-Server Example

Set up watchdog, backups, and restarts for 3 servers:

```bash
# Install service files
sudo cp asa-watchdog@.service /etc/systemd/system/
sudo cp asa-backup.timer /etc/systemd/system/
sudo cp asa-backup.service /etc/systemd/system/
sudo cp asa-restart.timer /etc/systemd/system/
sudo cp asa-restart.service /etc/systemd/system/
sudo systemctl daemon-reload

# Configure server 1
sudo systemctl enable asa-watchdog@asa-server-1.service
sudo systemctl enable asa-backup@asa-server-1.timer
sudo systemctl enable asa-restart@asa-server-1.timer

# Configure server 2
sudo systemctl enable asa-watchdog@asa-server-2.service
sudo systemctl enable asa-backup@asa-server-2.timer
sudo systemctl enable asa-restart@asa-server-2.timer

# Configure server 3
sudo systemctl enable asa-watchdog@asa-server-3.service
sudo systemctl enable asa-backup@asa-server-3.timer
sudo systemctl enable asa-restart@asa-server-3.timer

# Start all services
sudo systemctl start asa-watchdog@asa-server-{1,2,3}.service
sudo systemctl start asa-backup@asa-server-{1,2,3}.timer
sudo systemctl start asa-restart@asa-server-{1,2,3}.timer

# Check status
sudo systemctl status asa-watchdog@asa-server-*.service
sudo systemctl list-timers
```

