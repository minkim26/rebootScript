# rebootScript
[![GitHub Release (latest by date)](https://img.shields.io/github/v/release/minkim26/rebootScript)](https://github.com/minkim26/rebootScript/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)](https://github.com/minkim26/rebootScript)

This script will SSH into a remote server and reboot it at specified intervals with comprehensive monitoring capabilities and intelligent session management.

## 📋 Overview

This repository includes three scripts that work together to provide a complete solution for remote system rebooting:

- **`reboot.sh`** - Core script that performs periodic SSH reboots with comprehensive logging and verification
- **`manageScreen.sh`** - Session manager for running the reboot script in detached screen sessions with automatic session creation
- **`viewLogs.sh`** - Log viewer and analyzer for monitoring reboot activities across multiple sessions

## 🚀 Features

- **Automated Periodic Reboots**: Configurable intervals for systematic rebooting
- **Comprehensive Logging**: Both text logs and CSV tracking with detailed metrics
- **Intelligent Session Management**: Automatic creation of new logging sessions for each script run
- **Reboot Verification**: Validates successful reboots using uptime checks and system downtime measurement
- **Multiple Fallback Methods**: Tries different reboot commands for maximum compatibility
- **Real-time Monitoring**: Live log viewing and detailed statistics
- **Session Switching**: Manage and switch between multiple logging sessions
- **Graceful Error Handling**: Detailed error reporting and recovery suggestions
- **Configurable Timeouts**: Fine-tuned control over all timing parameters

## 📁 File Structure

```
rebootScript/
├── reboot.sh           # Main reboot execution script
├── manageScreen.sh     # Screen session manager
├── viewLogs.sh         # Log viewer and analyzer
├── logs/               # Auto-created log directory
│   ├── .current_session    # Current active session reference
│   └── YYYYMMDD_HHMMSS/    # Individual session directories (auto-created)
│       ├── ssh_reboot.csv  # Structured reboot data
│       └── ssh_reboot.log  # Detailed text logs
├── LICENSE
└── README.md
```

## 🛠️ Installation & Setup

### Prerequisites

- Bash shell environment (version 4.0+)
- SSH access to target remote system
- `screen` utility installed
- `ping` command available
- Basic utilities: `awk`, `bc`, `wc`, `tail`, `seq`

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

5. Edit configuration in `reboot.sh` (see Configuration section below for details):
   ```bash
   REMOTE_HOST="10.23.66.81"        # Your target IP/hostname
   REBOOT_INTERVAL=600              # Interval in seconds (600 = 10 minutes)
   REBOOT_WAIT_TIME=300             # Wait time for system recovery
   PING_TIMEOUT=5                   # Timeout for connectivity checks
   ```

## ⚙️ Configuration Options

### Core Network Configuration

```bash
REMOTE_HOST="10.23.66.81"          # Target system IP address or hostname
```
- **Purpose**: Specifies the remote server to reboot
- **Format**: IP address (192.168.1.100) or hostname (server.domain.com)
- **Note**: Must be reachable via SSH with key-based authentication

### Timing Configuration

#### Primary Interval Settings

```bash
REBOOT_INTERVAL=220                 # Time between reboot cycles (seconds)
```
- **Purpose**: Controls how often the system is rebooted
- **Default**: 220 seconds (~3.7 minutes)
- **Common Values**:
  - `300` = 5 minutes
  - `600` = 10 minutes  
  - `1800` = 30 minutes
  - `3600` = 1 hour
- **Range**: Minimum 60 seconds recommended

#### System Recovery Settings

```bash
REBOOT_WAIT_TIME=300               # Maximum wait for system to come back online
```
- **Purpose**: How long to wait for the system to boot and become accessible
- **Default**: 300 seconds (5 minutes)
- **Recommended Range**: 120-600 seconds depending on hardware
- **Impact**: Longer times accommodate slower systems but delay failure detection

```bash
PING_TIMEOUT=5                     # Individual ping attempt timeout
```
- **Purpose**: Timeout for each network connectivity test
- **Default**: 5 seconds
- **Recommended Range**: 3-10 seconds
- **Impact**: Lower values provide faster detection but may miss slow responses

#### Shutdown Detection Settings

```bash
SHUTDOWN_DETECTION_TIME=30         # Time to wait for system to go down
```
- **Purpose**: How long to monitor for system shutdown after reboot command
- **Default**: 30 seconds
- **Calculation**: Total checks = SHUTDOWN_DETECTION_TIME ÷ PING_TIMEOUT
- **Impact**: Must be long enough for graceful shutdown process

```bash
SSH_READY_WAIT=10                  # Wait time after ping success for SSH readiness
```
- **Purpose**: Buffer time for SSH service to become ready after network connectivity
- **Default**: 10 seconds
- **Recommended Range**: 5-20 seconds
- **Impact**: Prevents false negatives when SSH takes time to initialize

### Logging Configuration

```bash
ENABLE_LOGGING=true                # Enable/disable file logging
LOG_BASE_DIR="./logs"              # Base directory for all log sessions
```

#### Session Management

- **Automatic Session Creation**: Each script start creates a new timestamped directory
- **Session Format**: `YYYYMMDD_HHMMSS` (e.g., `20241201_143022`)
- **Session Isolation**: Each session has independent CSV and text log files

### Example Timing Scenarios

#### Fast Testing (Every 2 Minutes)
```bash
REBOOT_INTERVAL=120               # 2 minutes between reboots
REBOOT_WAIT_TIME=180              # 3 minutes recovery time
PING_TIMEOUT=3                    # Quick network checks
SHUTDOWN_DETECTION_TIME=20        # Expect fast shutdown
```

#### Production Monitoring (Every 30 Minutes)
```bash
REBOOT_INTERVAL=1800              # 30 minutes between reboots
REBOOT_WAIT_TIME=300              # 5 minutes recovery time
PING_TIMEOUT=5                    # Standard network checks
SHUTDOWN_DETECTION_TIME=45        # Allow graceful shutdown
```

#### Slow Hardware (Every Hour)
```bash
REBOOT_INTERVAL=3600              # 1 hour between reboots
REBOOT_WAIT_TIME=600              # 10 minutes recovery time
PING_TIMEOUT=8                    # Generous network timeout
SHUTDOWN_DETECTION_TIME=60        # Extended shutdown time
```

## 📖 Usage Guide

### Starting the Reboot Script

#### Method 1: Using Screen Manager (Recommended)
```bash
# Start in a managed screen session (creates new log session)
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
# Run in foreground (creates new log session)
./reboot.sh

# Run as background daemon
./reboot.sh --daemon
```

### Managing Screen Sessions

**`manageScreen.sh`** provides these commands:

| Command | Description |
|---------|-------------|
| `start` | Start the reboot script in a detached screen session (always creates new log session) |
| `stop` | Stop the running reboot script |
| `status` | Check if script is currently running |
| `attach` | Attach to the screen session (Ctrl+A, D to detach) |
| `logs` | Show recent log entries from current session |
| `session-info` | Display current session directory and file information |

**Key Features:**
- **Always Creates New Sessions**: Each start command creates a fresh log session
- **Session Persistence**: Sessions are preserved after stopping for historical analysis
- **Automatic Session Tracking**: Current active session is automatically tracked

**Examples:**
```bash
# Start monitoring (creates new session)
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
| `sessions` | List all available log sessions with statistics |
| `switch` | Interactive session switcher |

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

# Browse and switch between sessions
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
| `Downtime_Seconds` | Actual system downtime duration | Numeric (seconds) |
| `Notes` | Additional details/error info | Text description |

### Understanding Downtime Metrics

- **Actual Downtime**: Time from when system stops responding to when SSH is accessible
- **Not the Reboot Interval**: The `REBOOT_INTERVAL` is time between attempts, not downtime
- **Typical Downtime**: Usually 1-4 minutes depending on hardware and OS
- **Logged Precisely**: Measured from system-down detection to SSH readiness

### Text Log Format

The text log (`ssh_reboot.log`) provides detailed timestamped entries:
```
[2024-01-15 14:30:00] Starting periodic SSH reboot script for 10.23.66.81
[2024-01-15 14:30:00] Session directory: ./logs/20241201_143000
[2024-01-15 14:30:00] Reboot interval: 300 seconds
[2024-01-15 14:30:00] Max wait time for reboot: 300 seconds
[2024-01-15 14:30:00] === Starting reboot cycle for 10.23.66.81 ===
[2024-01-15 14:30:00] System uptime before reboot: 86400 seconds
[2024-01-15 14:30:01] Attempting to reboot 10.23.66.81...
[2024-01-15 14:30:02] Reboot command sent successfully
[2024-01-15 14:30:15] System is down - reboot initiated successfully
[2024-01-15 14:32:45] SUCCESS: System rebooted successfully (downtime: 150s)
[2024-01-15 14:32:45] Uptime before: 86400s, after: 30s
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
- Check `PING_TIMEOUT` setting in configuration

#### 3. "System did not go down" Warning
- Remote system may not have proper sudo permissions
- System might be configured to ignore reboot commands
- Increase `SHUTDOWN_DETECTION_TIME` for slower systems
- Check remote system logs: `/var/log/syslog` or `/var/log/messages`

#### 4. "System did not come back online" Error
- Hardware may be experiencing issues
- Increase `REBOOT_WAIT_TIME` for slower systems
- Check physical access to system
- Verify `PING_TIMEOUT` is appropriate for network conditions

#### 5. Screen Session Issues
```bash
# List all screen sessions
screen -list

# Kill stuck session manually
screen -S ssh_reboot -X quit

# Force kill if needed
pkill screen
```

#### 6. Log Permission Issues
```bash
# Fix log directory permissions
chmod -R 755 logs/
chown -R $USER logs/
```

#### 7. Session Management Issues
```bash
# View all sessions
./viewLogs.sh sessions

# Manually switch to different session
./viewLogs.sh switch

# Clean up old sessions (if needed)
rm -rf logs/old_session_directory
```

## 📈 Monitoring & Performance Optimization

### Regular Monitoring Tasks

```bash
# Daily success rate check
./viewLogs.sh summary

# Weekly detailed analysis
./viewLogs.sh stats

# Failure investigation
./viewLogs.sh failed
```

### Performance Tuning

#### For Fast Networks/Hardware
- Decrease `PING_TIMEOUT` to 3-5 seconds
- Reduce `REBOOT_WAIT_TIME` to 120-180 seconds
- Lower `SHUTDOWN_DETECTION_TIME` to 15-20 seconds

#### For Slow Networks/Hardware  
- Increase `PING_TIMEOUT` to 8-10 seconds
- Extend `REBOOT_WAIT_TIME` to 300-600 seconds
- Raise `SHUTDOWN_DETECTION_TIME` to 45-60 seconds

#### For High-Frequency Testing
- Set `REBOOT_INTERVAL` to 120-300 seconds
- Monitor system stress and adjust accordingly

#### for Production Monitoring
- Use longer `REBOOT_INTERVAL` (1800+ seconds)
- Ensure adequate `REBOOT_WAIT_TIME` for system services

## 🔒 Security Considerations

- **Use SSH key authentication** instead of passwords
- **Limit sudo permissions** to only `/sbin/reboot` command
- **Monitor logs regularly** for unusual activity or patterns
- **Rotate SSH keys periodically** for security
- **Secure log directory** with appropriate file permissions
- **Consider network isolation** for testing environments

## 💡 Best Practices

### Configuration Management
- Test configuration changes in a safe environment first
- Document custom timeout values and reasons
- Keep backup of working configurations

### Log Management  
- Regular cleanup of old session directories
- Monitor disk space usage in logs directory
- Archive important sessions before cleanup

### Operational Procedures
- Always use `./manageScreen.sh start` for production runs
- Check `./viewLogs.sh summary` regularly
- Use `./viewLogs.sh switch` to analyze historical data

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---