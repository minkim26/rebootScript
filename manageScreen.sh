#!/bin/bash

# Screen Session Manager for SSH Reboot Script
# This script helps manage the SSH reboot script running in a screen session

SCRIPT_NAME="reboot.sh"
SCREEN_SESSION="ssh_reboot"
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")/$SCRIPT_NAME"

# LOG_FILE="$HOME/rebootScript/ssh_reboot.log"

TIMESTAMP=$(date +%Y%m%d_%H%M%S) 
OUTPUT_DIR="./logs/$TIMESTAMP"     
LOG_FILE="$OUTPUT_DIR/ssh_reboot.log" 
REBOOT_LOG_CSV="$OUTPUT_DIR/ssh_reboot.csv"


show_usage() {
    echo "Usage: $0 {start|stop|status|attach|logs}"
    echo ""
    echo "Commands:"
    echo "  start   - Start the SSH reboot script in a screen session"
    echo "  stop    - Stop the running SSH reboot script"
    echo "  status  - Check if the script is running"
    echo "  attach  - Attach to the screen session (Ctrl+A, D to detach)"
    echo "  logs    - Show recent log entries"
}

start_script() {
    if screen -list | grep -q "$SCREEN_SESSION"; then
        echo "SSH reboot script is already running in screen session '$SCREEN_SESSION'"
        return 1
    fi
    
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "Error: Script not found at $SCRIPT_PATH"
        echo "Please ensure $SCRIPT_NAME is in the same directory as this manager script"
        return 1
    fi
    
    echo "Starting SSH reboot script in screen session '$SCREEN_SESSION'..."
    screen -dmS "$SCREEN_SESSION" bash "$SCRIPT_PATH"
    
    sleep 2
    if screen -list | grep -q "$SCREEN_SESSION"; then
        echo "Successfully started SSH reboot script in screen session"
        echo "Use '$0 attach' to connect to the session"
        echo "Use '$0 logs' to view logs"
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
    else
        echo "Failed to stop the script, you may need to attach and exit manually"
        return 1
    fi
}

check_status() {
    if screen -list | grep -q "$SCREEN_SESSION"; then
        echo "SSH reboot script is running in screen session '$SCREEN_SESSION'"
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
    echo "Use Ctrl+A, then D to detach from the session"
    screen -r "$SCREEN_SESSION"
}

show_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "No log file found at $LOG_FILE"
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
    *)
        show_usage
        exit 1
        ;;
esac
