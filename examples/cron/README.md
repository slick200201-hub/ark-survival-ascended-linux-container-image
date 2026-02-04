# ARK: Survival Ascended - Cron Schedule Examples

This directory contains example cron schedules for automating ARK ASA server maintenance tasks.

## Quick Start

1. Choose a schedule file that fits your needs
2. Edit the file to match your server names and preferences
3. Install the cron jobs:

```bash
# View your current crontab
crontab -l

# Edit your crontab
crontab -e

# Copy the contents of your chosen schedule file into the editor
# Or use this command to append to existing crontab:
crontab -l | cat - daily-maintenance.cron | crontab -
```

## Available Schedules

### `daily-maintenance.cron`
Basic daily maintenance schedule suitable for most servers:
- Daily backup at 2:00 AM
- Weekly backup cleanup
- Daily restart at 4:00 AM with player warnings

### `advanced-schedule.cron`
Comprehensive schedule for high-traffic servers:
- Multiple backup schedules (hourly, daily, weekly, monthly)
- Multiple daily restarts
- Automated maintenance commands
- Resource monitoring examples

## Cron Syntax Reference

```
*    *    *    *    *    command
│    │    │    │    │
│    │    │    │    └─── Day of week (0-7, 0 and 7 = Sunday)
│    │    │    └──────── Month (1-12)
│    │    └───────────── Day of month (1-31)
│    └────────────────── Hour (0-23)
└─────────────────────── Minute (0-59)
```

### Examples
- `0 4 * * *` - Every day at 4:00 AM
- `*/30 * * * *` - Every 30 minutes
- `0 */6 * * *` - Every 6 hours
- `0 2 * * 0` - Every Sunday at 2:00 AM
- `0 3 1 * *` - First day of every month at 3:00 AM
- `30 3 * * 1-5` - Weekdays at 3:30 AM

## Best Practices

### Timing Considerations
1. **Backups**: Schedule during low-traffic hours (2-4 AM)
2. **Restarts**: Avoid player peak times
3. **Updates**: Check Steam update times (usually Tuesday/Thursday)
4. **World Saves**: Every 1-2 hours during active play

### Warning Times
- **Short sessions (2-4 hours)**: 10-15 minute warning
- **Long sessions (12-24 hours)**: 30-60 minute warning
- **Emergency restarts**: 5 minute warning minimum

### Backup Strategy
- **Frequent**: Hourly during peak hours (keeps last few hours)
- **Daily**: Keep 7-14 days
- **Weekly**: Keep 4-8 weeks
- **Monthly**: Keep 6-12 months
- **Pre-update**: Always backup before major updates

## Monitoring Cron Jobs

### View cron logs
```bash
# System-wide cron log
sudo grep CRON /var/log/syslog | tail -n 50

# Or on systems using journalctl
sudo journalctl -u cron -n 50
```

### Check if cron is running
```bash
sudo systemctl status cron
# or
sudo systemctl status cronie
```

### Test a cron command
Run the command manually to verify it works:
```bash
/usr/local/bin/asa-scheduled-restart asa-server-1 5
```

## Troubleshooting

### Jobs not running
1. Check cron service is running:
   ```bash
   sudo systemctl status cron
   ```

2. Check crontab syntax:
   ```bash
   crontab -l
   ```

3. Verify script permissions:
   ```bash
   ls -l /usr/local/bin/asa-*
   ```

4. Check script paths are absolute (cron doesn't use your PATH)

### Jobs run but fail
1. Check system logs for errors
2. Add output redirection to cron commands:
   ```
   0 4 * * * /usr/local/bin/asa-backup create asa-server-1 >> /var/log/asa-backup.log 2>&1
   ```
3. Run the command manually to see errors
4. Verify Docker is accessible (may need to add user to docker group)

### Email notifications
By default, cron sends output via email. To enable:
```bash
# Add this to the top of your crontab
MAILTO=your-email@example.com

# Or disable emails completely
MAILTO=""
```

## Example: Complete Server Automation

Here's a complete setup for a production server:

```bash
# Environment
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=admin@yourserver.com

# Daily backup at 2 AM
0 2 * * * /usr/local/bin/asa-backup create asa-server-1 daily >> /var/log/asa-backup.log 2>&1

# Weekly backup cleanup - keep 14 backups  
0 3 * * 0 /usr/local/bin/asa-backup cleanup asa-server-1 14

# Daily restart at 4 AM with 30-min warning
30 3 * * * /usr/local/bin/asa-scheduled-restart asa-server-1 30 >> /var/log/asa-restart.log 2>&1

# Save world every hour
0 * * * * docker exec asa-server-1 asa-ctrl rcon --exec 'saveworld'

# Weekly dino wipe on Sunday after restart
0 5 * * 0 docker exec asa-server-1 asa-ctrl rcon --exec 'destroywilddinos'

# Backup before Friday update (Fridays at 1 AM)
0 1 * * 5 /usr/local/bin/asa-backup create asa-server-1 pre-update
```

## Security Notes

- Run cron jobs as a non-root user when possible
- Store sensitive data (passwords, API keys) in environment files, not cron
- Use absolute paths for all commands and files
- Regularly review and audit cron jobs
- Monitor log files for suspicious activity

## Further Resources

- [Cron HowTo](https://help.ubuntu.com/community/CronHowto)
- [Crontab.guru](https://crontab.guru/) - Cron schedule expression editor
- [Docker exec documentation](https://docs.docker.com/engine/reference/commandline/exec/)
