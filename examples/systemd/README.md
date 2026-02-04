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
