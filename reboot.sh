#!/bin/bash

# Periodic SSH Reboot Script
# This script will SSH into a remote server and reboot it at specified intervals

# Configuration
REMOTE_HOST="10.23.66.81"
REBOOT_INTERVAL=500  # Interval in seconds (3600 = 1 hour, 1800 = 30 min, 7200 = 2 hours)
# REBOOT_LOG_CSV="$HOME/rebootScript/ssh_reboot_tracking.csv"
# LOG_FILE="$HOME/rebootScript/ssh_reboot.log"
ENABLE_LOGGING=true
REBOOT_WAIT_TIME=120  # Time to wait before checking if system is back online (seconds)
PING_TIMEOUT=30       # How long to wait for system to go down before considering reboot failed

TIMESTAMP=$(date +%Y%m%d_%H%M%S) 
OUTPUT_DIR="./logs/$TIMESTAMP"     
LOG_FILE="$OUTPUT_DIR/ssh_reboot.log" 
REBOOT_LOG_CSV="$OUTPUT_DIR/ssh_reboot.csv"


# Create log files if they don't exist
touch "$LOG_FILE" 2>/dev/null || {
    echo "Warning: Cannot create log file at $LOG_FILE, logging to stdout only"
    ENABLE_LOGGING=false
}

# Create CSV header if file doesn't exist
if [ ! -f "$REBOOT_LOG_CSV" ]; then
    echo "Timestamp,Reboot_Initiated,System_Down_Detected,System_Back_Online,Reboot_Success,Downtime_Seconds,Notes" > "$REBOOT_LOG_CSV"
fi

# Function to log messages
log_message() {
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    fi
}

# Function to check if remote host is reachable
check_host_reachable() {
    ping -c 1 -W 5 "$REMOTE_HOST" >/dev/null 2>&1
    return $?
}

# Function to get system uptime from remote host
get_remote_uptime() {
    ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$REMOTE_HOST" 'cat /proc/uptime | cut -d" " -f1' 2>/dev/null
}

# Function to log to CSV
log_to_csv() {
    local timestamp="$1"
    local reboot_initiated="$2"
    local system_down="$3"
    local system_back="$4"
    local success="$5"
    local downtime="$6"
    local notes="$7"
    
    echo "$timestamp,$reboot_initiated,$system_down,$system_back,$success,$downtime,\"$notes\"" >> "$REBOOT_LOG_CSV"
}

# Function to perform SSH reboot with verification
ssh_reboot() {
    local start_time=$(date '+%Y-%m-%d %H:%M:%S')
    local start_epoch=$(date +%s)
    local reboot_initiated="No"
    local system_down="No"
    local system_back="No"
    local success="No"
    local downtime=0
    local notes=""
    
    log_message "=== Starting reboot cycle for $REMOTE_HOST ==="
    
    # Check initial connectivity
    if ! check_host_reachable; then
        notes="Host unreachable before reboot attempt"
        log_message "ERROR: Cannot reach $REMOTE_HOST - host unreachable"
        log_to_csv "$start_time" "$reboot_initiated" "$system_down" "$system_back" "$success" "$downtime" "$notes"
        return 1
    fi
    
    # Get uptime before reboot (for verification later)
    local uptime_before=$(get_remote_uptime)
    log_message "System uptime before reboot: ${uptime_before:-unknown} seconds"
    
    # Attempt to reboot
    log_message "Attempting to reboot $REMOTE_HOST..."
    
    # Try different reboot methods
    if ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no "$REMOTE_HOST" 'sudo reboot' 2>/dev/null; then
        reboot_initiated="Yes"
        log_message "Reboot command sent successfully"
    elif ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no "$REMOTE_HOST" 'reboot' 2>/dev/null; then
        reboot_initiated="Yes"
        log_message "Reboot command sent successfully (without sudo)"
    elif ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no "$REMOTE_HOST" '/sbin/reboot' 2>/dev/null; then
        reboot_initiated="Yes"
        log_message "Reboot command sent successfully (direct /sbin/reboot)"
    else
        notes="Failed to execute reboot command - sudo password required or insufficient permissions"
        log_message "ERROR: Failed to execute reboot command"
        log_message "SOLUTION: Configure passwordless sudo for reboot on $REMOTE_HOST"
        log_message "Run on $REMOTE_HOST: echo 'gpac ALL=(ALL) NOPASSWD: /sbin/reboot' | sudo tee /etc/sudoers.d/reboot"
        log_to_csv "$start_time" "$reboot_initiated" "$system_down" "$system_back" "$success" "$downtime" "$notes"
        return 1
    fi
    
    # Wait a moment for reboot to start
    sleep 10
    
    # Check if system actually went down
    log_message "Checking if system is going down..."
    local down_detected=false
    for i in {1..6}; do  # Check for 30 seconds (6 * 5 seconds)
        if ! check_host_reachable; then
            system_down="Yes"
            down_detected=true
            local down_time=$(date +%s)
            log_message "System is down - reboot initiated successfully"
            break
        fi
        sleep 5
    done
    
    if [ "$down_detected" = false ]; then
        notes="System did not go down after reboot command"
        log_message "WARNING: System appears to still be up after reboot command"
        log_to_csv "$start_time" "$reboot_initiated" "$system_down" "$system_back" "$success" "$downtime" "$notes"
        return 1
    fi
    
    # Wait for system to come back online
    log_message "Waiting for system to come back online..."
    local back_online=false
    local check_start=$(date +%s)
    
    # Wait up to 5 minutes for system to come back
    for i in {1..60}; do  # 60 * 5 seconds = 5 minutes
        sleep 5
        if check_host_reachable; then
            # System is reachable, wait a bit more for SSH to be ready
            sleep 10
            if get_remote_uptime >/dev/null 2>&1; then
                system_back="Yes"
                back_online=true
                local back_time=$(date +%s)
                downtime=$((back_time - down_time))
                
                # Verify it actually rebooted by checking uptime
                local uptime_after=$(get_remote_uptime)
                if [ -n "$uptime_before" ] && [ -n "$uptime_after" ]; then
                    # Convert to integers for comparison (remove decimals)
                    local uptime_before_int=${uptime_before%.*}
                    local uptime_after_int=${uptime_after%.*}
                    
                    if [ "$uptime_after_int" -lt "$uptime_before_int" ]; then
                        success="Yes"
                        notes="Successful reboot verified by uptime check"
                        log_message "SUCCESS: System rebooted successfully (downtime: ${downtime}s)"
                        log_message "Uptime before: ${uptime_before}s, after: ${uptime_after}s"
                    else
                        notes="System came back but uptime suggests no reboot occurred"
                        log_message "WARNING: System back online but uptime suggests no reboot"
                    fi
                else
                    success="Yes"
                    notes="System rebooted successfully (uptime verification unavailable)"
                    log_message "SUCCESS: System appears to have rebooted (downtime: ${downtime}s)"
                fi
                break
            fi
        fi
    done
    
    if [ "$back_online" = false ]; then
        notes="System did not come back online within 5 minutes"
        log_message "ERROR: System did not come back online within 5 minutes"
        log_to_csv "$start_time" "$reboot_initiated" "$system_down" "$system_back" "$success" "$downtime" "$notes"
        return 1
    fi
    
    log_to_csv "$start_time" "$reboot_initiated" "$system_down" "$system_back" "$success" "$downtime" "$notes"
    return 0
}

# Function to handle script termination
cleanup() {
    log_message "Script terminated. Cleaning up..."
    exit 0
}

# Set up signal handlers for graceful shutdown
trap cleanup SIGINT SIGTERM

# Main loop
main() {
    log_message "Starting periodic SSH reboot script for $REMOTE_HOST"
    log_message "Reboot interval: $REBOOT_INTERVAL seconds"
    
    while true; do
        ssh_reboot
        
        log_message "Waiting $REBOOT_INTERVAL seconds until next reboot..."
        sleep "$REBOOT_INTERVAL"
    done
}

# Check if running as background process
if [ "$1" = "--daemon" ]; then
    # Run as daemon (background process)
    main &
    DAEMON_PID=$!
    echo "Started SSH reboot daemon with PID: $DAEMON_PID"
    echo "$DAEMON_PID" > /tmp/ssh_reboot.pid
else
    # Run in foreground
    main
fi
