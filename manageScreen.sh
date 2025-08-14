#!/bin/bash

# Screen Session Manager for SSH Reboot Script
# This script helps manage the SSH reboot script running in a screen session

SCRIPT_NAME="reboot.sh"
SCREEN_SESSION="ssh_reboot"
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")/$SCRIPT_NAME"

# Shared configuration for log paths
LOG_BASE_DIR="./logs"
CURRENT_SESSION_FILE="$LOG_BASE_DIR/.current_session"

# Function to get or create current session directory
get_session_dir() {
    # Create base log directory if it doesn't exist
    mkdir -p "$LOG_BASE_DIR"
    
    # Check if there's an active session
    if [ -f "$CURRENT_SESSION_FILE" ]; then
        local existing_session=$(cat "$CURRENT_SESSION_FILE")
        local session_dir="$LOG_BASE_DIR/$existing_session"
        
        # Check if the session directory still exists and has logs
        if [ -d "$session_dir" ]; then
            echo "$session_dir"
            return 0
        fi
    fi
    
    # Create new session
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local session_dir="$LOG_BASE_DIR/$timestamp"
    mkdir -p "$session_dir"
    echo "$timestamp" > "$CURRENT_SESSION_FILE"
    echo "$session_dir"
}

# Get current session directory
SESSION_DIR=$(get_session_dir)
LOG_FILE="$SESSION_DIR/ssh_reboot.log"
REBOOT_LOG_CSV="$SESSION_DIR/ssh_reboot.csv"

show_usage() {
    echo "Usage: $0 {start|stop|status|attach|logs|session-info}"
    echo ""
    echo "Commands:"
    echo "  start        - Start the SSH reboot script in a screen session"
    echo "  stop         - Stop the running SSH reboot script"
    echo "  status       - Check if the script is running"
    echo "  attach       - Attach to the screen session (Ctrl+A, D to detach)"
    echo "  logs         - Show recent log entries"
    echo "  session-info - Show current session directory and files"
}

show_session_info() {
    echo "=== Current Session Information ==="
    echo "Session directory: $SESSION_DIR"
    echo "Log file: $LOG_FILE"
    echo "CSV file: $REBOOT_LOG_CSV"
    echo ""
    
    if [ -f "$LOG_FILE" ]; then
        echo "Log file exists ($(wc -l < "$LOG_FILE") lines)"
    else
        echo "Log file does not exist yet"
    fi
    
    if [ -f "$REBOOT_LOG_CSV" ]; then
        local csv_lines=$(wc -l < "$REBOOT_LOG_CSV")
        echo "CSV file exists ($((csv_lines - 1)) reboot attempts logged)"
    else
        echo "CSV file does not exist yet"
    fi
    
    echo ""
    echo "Available log sessions:"
    if [ -d "$LOG_BASE_DIR" ]; then
        ls -la "$LOG_BASE_DIR" | grep "^d" | grep -E "[0-9]{8}_[0-9]{6}" || echo "No previous sessions found"
    fi
}

start_script() {
    if screen -list | grep -q "$SCREEN_SESSION"; then
        echo "SSH reboot script is already running in screen session '$SCREEN_SESSION'"
        echo "Current session: $SESSION_DIR"
        return 1
    fi
    
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "Error: Script not found at $SCRIPT_PATH"
        echo "Please ensure $SCRIPT_NAME is in the same directory as this manager script"
        return 1
    fi
    
    # Ensure session directory exists
    mkdir -p "$SESSION_DIR"
    
    echo "Starting SSH reboot script in screen session '$SCREEN_SESSION'..."
    echo "Session directory: $SESSION_DIR"
    
    # Export the session directory to the reboot script
    export REBOOT_SESSION_DIR="$SESSION_DIR"
    
    # Start screen with the session directory as an environment variable
    screen -dmS "$SCREEN_SESSION" bash -c "export REBOOT_SESSION_DIR='$SESSION_DIR'; bash '$SCRIPT_PATH'"
    
    sleep 2
    if screen -list | grep -q "$SCREEN_SESSION"; then
        echo "Successfully started SSH reboot script in screen session"
        echo "Logs will be saved to: $SESSION_DIR"
        echo ""
        echo "Use '$0 attach' to connect to the session"
        echo "Use '$0 logs' to view logs"
        echo "Use './viewLogs.sh summary' to view reboot tracking"
    else
        echo "Failed to start screen session"
        return 1
    fi
}

stop_script() {
    if ! screen -list | grep -q "$SCREEN_SESSION"; then
        echo "No screen session '$SCREEN_SESSION' found"
        return 1
    fi
    
    echo "Stopping SSH reboot script..."
    screen -S "$SCREEN_SESSION" -X quit
    
    sleep 2
    if ! screen -list | grep -q "$SCREEN_SESSION"; then
        echo "SSH reboot script stopped successfully"
        echo "Logs preserved in: $SESSION_DIR"
    else
        echo "Failed to stop the script, you may need to attach and exit manually"
        return 1
    fi
}

check_status() {
    if screen -list | grep -q "$SCREEN_SESSION"; then
        echo "SSH reboot script is running in screen session '$SCREEN_SESSION'"
        echo "Current session: $SESSION_DIR"
        screen -list | grep "$SCREEN_SESSION"
        return 0
    else
        echo "SSH reboot script is not running"
        return 1
    fi
}

attach_session() {
    if ! screen -list | grep -q "$SCREEN_SESSION"; then
        echo "No screen session '$SCREEN_SESSION' found"
        echo "Use '$0 start' to start the script first"
        return 1
    fi
    
    echo "Attaching to screen session '$SCREEN_SESSION'..."
    echo "Current session: $SESSION_DIR"
    echo "Use Ctrl+A, then D to detach from the session"
    screen -r "$SCREEN_SESSION"
}

show_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "No log file found at $LOG_FILE"
        echo "Current session: $SESSION_DIR"
        
        # Try to find the most recent log file
        echo ""
        echo "Looking for recent log files..."
        find "$LOG_BASE_DIR" -name "ssh_reboot.log" -type f 2>/dev/null | head -5 | while read -r logfile; do
            echo "Found: $logfile"
        done
        return 1
    fi
    
    echo "Showing last 20 lines from $LOG_FILE:"
    echo "----------------------------------------"
    tail -20 "$LOG_FILE"
    echo "----------------------------------------"
    echo "Use 'tail -f $LOG_FILE' to follow logs in real-time"
}

case "$1" in
    start)
        start_script
        ;;
    stop)
        stop_script
        ;;
    status)
        check_status
        ;;
    attach)
        attach_session
        ;;
    logs)
        show_logs
        ;;
    session-info)
        show_session_info
        ;;
    *)
        show_usage
        exit 1
        ;;
esac