# rebootScript
[![GitHub Release (latest by date)](https://img.shields.io/github/v/release/minkim26/rebootScript)](https://github.com/minkim26/rebootScript/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)](https://github.com/minkim26/rebootScript)

This script will SSH into a remote server and reboot it at specified intervals with monitoring capabilities.

## 📋 Overview

This repository includes three scripts that work together to provide a complete solution for remote system rebooting:

- **`reboot.sh`** - Core script that performs periodic SSH reboots with comprehensive logging
- **`manageScreen.sh`** - Session manager for running the reboot script in detached screen sessions  
- **`viewLogs.sh`** - Log viewer and analyzer for monitoring reboot activities

## 🚀 Features

- **Automated Periodic Reboots**: Configurable intervals for systematic rebooting
- **Comprehensive Logging**: Both text logs and CSV tracking with detailed metrics
- **Session Management**: Run scripts in detached screen sessions with easy management
- **Reboot Verification**: Validates successful reboots using uptime checks
- **Multiple Fallback Methods**: Tries different reboot commands for compatibility
- **Real-time Monitoring**: Live log viewing and detailed statistics
- **Session Switching**: Manage multiple logging sessions
- **Graceful Error Handling**: Detailed error reporting and recovery suggestions

## 📁 File Structure

```
ssh-reboot-suite/
├── reboot.sh           # Main reboot execution script
├── manageScreen.sh     # Screen session manager
├── viewLogs.sh         # Log viewer and analyzer
├── logs/               # Auto-created log directory
│   ├── .current_session    # Current active session reference
│   └── YYYYMMDD_HHMMSS/    # Session directories
│       ├── ssh_reboot.log  # Detailed text logs
│       └── ssh_reboot.csv  # Structured reboot data
└── README.md
```

## 🛠️ Installation & Setup

### Prerequisites

- Bash shell environment
- SSH access to target remote system
- `screen` utility installed
- `ping` command available
- Basic utilities: `awk`, `bc`, `wc`, `tail`

### Initial Setup

1. Clone or download all three scripts to the same directory
2. Make scripts executable:
   ```bash
   chmod +x reboot.sh manageScreen.sh viewLogs.sh
   ```

3. Configure SSH key authentication for passwordless access:
   ```bash
   ssh-keygen -t rsa
   ssh-copy-id user@your-remote-host
   ```

4. **IMPORTANT**: Configure passwordless sudo for reboot on the remote system:
   ```bash
   # On remote system, run:
   echo 'username ALL=(ALL) NOPASSWD: /sbin/reboot' | sudo tee /etc/sudoers.d/reboot
   ```

5. Edit configuration in `reboot.sh`:
   ```bash
   REMOTE_HOST="10.23.66.81"        # Your target IP/hostname
   REBOOT_INTERVAL=600              # Interval in seconds (600 = 10 minutes)
   REBOOT_WAIT_TIME=120             # Wait time for system recovery
   PING_TIMEOUT=30                  # Timeout for connectivity checks
   ```

## 📖 Usage Guide

### Starting the Reboot Script

#### Method 1: Using Screen Manager (Recommended)
```bash
# Start in a managed screen session
./manageScreen.sh start

# Check status
./manageScreen.sh status

# Attach to running session
./manageScreen.sh attach

# Stop the script
./manageScreen.sh stop
```

#### Method 2: Direct Execution
```bash
# Run in foreground
./reboot.sh

# Run as background daemon
./reboot.sh --daemon
```

### Managing Screen Sessions

**`manageScreen.sh`** provides these commands:

| Command | Description |
|---------|-------------|
| `start` | Start the reboot script in a detached screen session |
| `stop` | Stop the running reboot script |
| `status` | Check if script is currently running |
| `attach` | Attach to the screen session (Ctrl+A, D to detach) |
| `logs` | Show recent log entries from current session |
| `session-info` | Display current session directory and file information |

**Examples:**
```bash
# Start monitoring
./manageScreen.sh start

# Check what's happening
./manageScreen.sh status
./manageScreen.sh logs

# Get detailed session info
./manageScreen.sh session-info

# Connect to live session (exit with Ctrl+A, D)
./manageScreen.sh attach
```

### Viewing and Analyzing Logs

**`viewLogs.sh`** provides comprehensive log analysis:

| Command | Description |
|---------|-------------|
| `summary` | Quick overview of reboot attempts and success rate |
| `recent` | Show last 10 reboot attempts with full details |
| `all` | Display all reboot attempts in current session |
| `successful` | Show only successful reboots |
| `failed` | Show only failed reboot attempts |
| `stats` | Detailed statistics including averages and failure analysis |
| `tail` | Follow live log file in real-time |
| `sessions` | List all available log sessions |
| `switch` | Switch to a different log session |

**Examples:**
```bash
# Quick status check
./viewLogs.sh summary

# Detailed statistics
./viewLogs.sh stats

# Monitor live activity
./viewLogs.sh tail

# View recent failures
./viewLogs.sh failed

# Switch between different sessions
./viewLogs.sh sessions
./viewLogs.sh switch
```

## 📊 Log Format & Data

### CSV Log Fields

The CSV log (`ssh_reboot.csv`) contains these fields:

| Field | Description | Values |
|-------|-------------|---------|
| `Timestamp` | When reboot cycle started | YYYY-MM-DD HH:MM:SS |
| `Reboot_Initiated` | Was reboot command sent | Yes/No |
| `System_Down_Detected` | Did system go offline | Yes/No |
| `System_Back_Online` | Did system come back online | Yes/No |
| `Reboot_Success` | Overall reboot success | Yes/No |
| `Downtime_Seconds` | System downtime duration | Numeric (seconds) |
| `Notes` | Additional details/error info | Text description |

### Text Log Format

The text log (`ssh_reboot.log`) provides detailed timestamped entries:
```
[2024-01-15 14:30:00] Starting periodic SSH reboot script for 10.23.66.81
[2024-01-15 14:30:00] === Starting reboot cycle for 10.23.66.81 ===
[2024-01-15 14:30:00] System uptime before reboot: 86400 seconds
[2024-01-15 14:30:01] Attempting to reboot 10.23.66.81...
[2024-01-15 14:30:02] Reboot command sent successfully
[2024-01-15 14:30:15] System is down - reboot initiated successfully
[2024-01-15 14:30:45] SUCCESS: System rebooted successfully (downtime: 30s)
```

## ⚙️ Configuration Options

### Core Configuration (`reboot.sh`)

```bash
# Network Configuration
REMOTE_HOST="10.23.66.81"      # Target system IP/hostname

# Timing Configuration  
REBOOT_INTERVAL=600            # Time between reboots (seconds)
REBOOT_WAIT_TIME=120          # Recovery wait time (seconds)
PING_TIMEOUT=30               # Network timeout (seconds)

# Logging Configuration
ENABLE_LOGGING=true           # Enable/disable file logging
LOG_BASE_DIR="./logs"         # Log directory location
```

## 🔧 Troubleshooting

### Common Issues & Solutions

#### 1. "sudo password required" Error
```bash
# On remote system:
echo 'username ALL=(ALL) NOPASSWD: /sbin/reboot' | sudo tee /etc/sudoers.d/reboot
```

#### 2. "Host unreachable" Error
- Verify network connectivity: `ping target-host`
- Check SSH configuration: `ssh target-host`
- Ensure SSH keys are properly configured

#### 3. "System did not go down" Warning
- Remote system may not have proper sudo permissions
- System might be configured to ignore reboot commands
- Check remote system logs: `/var/log/syslog` or `/var/log/messages`

#### 4. Screen Session Issues
```bash
# List all screen sessions
screen -list

# Kill stuck session manually
screen -S ssh_reboot -X quit

# Force kill if needed
pkill screen
```

#### 5. Log Permission Issues
```bash
# Fix log directory permissions
chmod -R 755 logs/
chown -R $USER logs/
```

## 📈 Monitoring & Alerts

Check success rates regularly:
```bash
# Quick success rate check
./viewLogs.sh summary

# Detailed failure analysis  
./viewLogs.sh stats
./viewLogs.sh failed
```

## 🔒 Security Considerations

- Use SSH key authentication instead of passwords
- Limit sudo permissions to only `/sbin/reboot` command
- Monitor logs for unusual activity
- Rotate SSH keys periodically

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---