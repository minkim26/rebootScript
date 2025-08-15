#!/bin/bash
# Screen Session Manager for SSH Reboot Script
# This script helps manage the SSH reboot script running in a screen session

SCRIPT_NAME="reboot.sh"
SCREEN_SESSION="ssh_reboot"
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")/$SCRIPT_NAME"

# Shared configuration for log paths
LOG_BASE_DIR="./logs"
CURRENT_SESSION_FILE="$LOG_BASE_DIR/.current_session"

# Function to create a new session directory (always create new)
create_new_session() {
    # Create base log directory if it doesn't exist
    mkdir -p "$LOG_BASE_DIR"
    
    # Always create new session with timestamp
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local session_dir="$LOG_BASE_DIR/$timestamp"
    mkdir -p "$session_dir"
    echo "$timestamp" > "$CURRENT_SESSION_FILE"
    echo "$session_dir"
}

# Function to get current session directory (for viewing logs)
get_current_session_dir() {
    if [ -f "$CURRENT_SESSION_FILE" ]; then
        local session_name=$(cat "$CURRENT_SESSION_FILE")
        local session_dir="$LOG_BASE_DIR/$session_name"
        
        if [ -d "$session_dir" ]; then
            echo "$session_dir"
            return 0
        fi
    fi
    
    # If no current session, try to find the most recent one
    local latest_dir=$(find "$LOG_BASE_DIR" -maxdepth 1 -type d -name "*_*" 2>/dev/null | sort | tail -1)
    if [ -n "$latest_dir" ]; then
        echo "$latest_dir"
        return 0
    fi
    
    return 1
}

show_usage() {
    echo "Usage: $0 {start|stop|status|attach|logs|session-info}"
    echo ""
    echo "Commands:"
    echo "  start        - Start the SSH reboot script in a screen session (creates new log session)"
    echo "  stop         - Stop the running SSH reboot script"
    echo "  status       - Check if the script is running"
    echo "  attach       - Attach to the screen session (Ctrl+A, D to detach)"
    echo "  logs         - Show recent log entries"
    echo "  session-info - Show current session directory and files"
}

show_session_info() {
    local session_dir=$(get_current_session_dir)
    
    echo "=== Current Session Information ==="
    if [ -n "$session_dir" ]; then
        echo "Session directory: $session_dir"
        echo "Log file: $session_dir/ssh_reboot.log"
        echo "CSV file: $session_dir/ssh_reboot.csv"
        echo ""
        
        if [ -f "$session_dir/ssh_reboot.log" ]; then
            echo "Log file exists ($(wc -l < "$session_dir/ssh_reboot.log") lines)"
        else
            echo "Log file does not exist yet"
        fi
        
        if [ -f "$session_dir/ssh_reboot.csv" ]; then
            local csv_lines=$(wc -l < "$session_dir/ssh_reboot.csv")
            echo "CSV file exists ($((csv_lines - 1)) reboot attempts logged)"
        else
            echo "CSV file does not exist yet"
        fi
    else
        echo "No active session found"
    fi
    
    echo ""
    echo "Available log sessions:"
    if [ -d "$LOG_BASE_DIR" ]; then
        find "$LOG_BASE_DIR" -maxdepth 1 -type d -name "*_*" 2>/dev/null | sort -r | head -10 | while read -r session_path; do
            local session_name=$(basename "$session_path")
            local log_file="$session_path/ssh_reboot.log"
            local csv_file="$session_path/ssh_reboot.csv"
            
            local log_lines=0
            local csv_entries=0
            
            if [ -f "$log_file" ]; then
                log_lines=$(wc -l < "$log_file")
            fi
            
            if [ -f "$csv_file" ]; then
                csv_entries=$(($(wc -l < "$csv_file") - 1))
                [ $csv_entries -lt 0 ] && csv_entries=0
            fi
            
            printf "  %-16s (log: %d lines, csv: %d entries)\n" "$session_name" "$log_lines" "$csv_entries"
        done
    else
        echo "  No sessions found"
    fi
}

start_script() {
    if screen -list | grep -q "$SCREEN_SESSION"; then
        echo "SSH reboot script is already running in screen session '$SCREEN_SESSION'"
        echo "Use '$0 stop' to stop it first, then start again for a new session"
        return 1
    fi
    
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "Error: Script not found at $SCRIPT_PATH"
        echo "Please ensure $SCRIPT_NAME is in the same directory as this manager script"
        return 1
    fi
    
    # Always create a new session when starting
    SESSION_DIR=$(create_new_session)
    
    echo "Starting SSH reboot script in screen session '$SCREEN_SESSION'..."
    echo "New session directory: $SESSION_DIR"
    
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
    
    local session_dir=$(get_current_session_dir)
    
    echo "Stopping SSH reboot script..."
    screen -S "$SCREEN_SESSION" -X quit
    
    sleep 2
    if ! screen -list | grep -q "$SCREEN_SESSION"; then
        echo "SSH reboot script stopped successfully"
        if [ -n "$session_dir" ]; then
            echo "Logs preserved in: $session_dir"
        fi
    else
        echo "Failed to stop the script, you may need to attach and exit manually"
        return 1
    fi
}

check_status() {
    if screen -list | grep -q "$SCREEN_SESSION"; then
        local session_dir=$(get_current_session_dir)
        echo "SSH reboot script is running in screen session '$SCREEN_SESSION'"
        if [ -n "$session_dir" ]; then
            echo "Current session: $session_dir"
        fi
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
    
    local session_dir=$(get_current_session_dir)
    
    echo "Attaching to screen session '$SCREEN_SESSION'..."
    if [ -n "$session_dir" ]; then
        echo "Current session: $session_dir"
    fi
    echo "Use Ctrl+A, then D to detach from the session"
    screen -r "$SCREEN_SESSION"
}

show_logs() {
    local session_dir=$(get_current_session_dir)
    
    if [ -z "$session_dir" ] || [ ! -f "$session_dir/ssh_reboot.log" ]; then
        echo "No log file found"
        
        if [ -n "$session_dir" ]; then
            echo "Expected location: $session_dir/ssh_reboot.log"
        fi
        
        # Try to find the most recent log file
        echo ""
        echo "Looking for recent log files..."
        find "$LOG_BASE_DIR" -name "ssh_reboot.log" -type f 2>/dev/null | sort -r | head -5 | while read -r logfile; do
            echo "Found: $logfile"
        done
        return 1
    fi
    
    echo "Showing last 20 lines from $session_dir/ssh_reboot.log:"
    echo "----------------------------------------"
    tail -20 "$session_dir/ssh_reboot.log"
    echo "----------------------------------------"
    echo "Use 'tail -f $session_dir/ssh_reboot.log' to follow logs in real-time"
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