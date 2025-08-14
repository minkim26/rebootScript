#!/bin/bash

# Reboot Log Viewer Script
# This script helps view and analyze the reboot tracking logs

# Configuration
LOG_BASE_DIR="./logs"
CURRENT_SESSION_FILE="$LOG_BASE_DIR/.current_session"

# Function to get current session directory
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

# Set up paths
SESSION_DIR=$(get_current_session_dir)
if [ $? -eq 0 ]; then
    LOG_FILE="$SESSION_DIR/ssh_reboot.log"
    REBOOT_LOG_CSV="$SESSION_DIR/ssh_reboot.csv"
else
    SESSION_DIR=""
    LOG_FILE=""
    REBOOT_LOG_CSV=""
fi

show_usage() {
    echo "Usage: $0 {summary|recent|all|successful|failed|stats|tail|sessions|switch}"
    echo ""
    echo "Commands:"
    echo "  summary    - Show summary of recent reboot attempts"
    echo "  recent     - Show last 10 reboot attempts"
    echo "  all        - Show all reboot attempts"
    echo "  successful - Show only successful reboots"
    echo "  failed     - Show only failed reboots"
    echo "  stats      - Show reboot statistics"
    echo "  tail       - Follow the main log file in real-time"
    echo "  sessions   - List all available log sessions"
    echo "  switch     - Switch to a different log session"
    echo ""
    if [ -n "$SESSION_DIR" ]; then
        echo "Current session: $(basename "$SESSION_DIR")"
    else
        echo "No active session found"
    fi
}

show_sessions() {
    echo "=== Available Log Sessions ==="
    echo ""
    
    if [ ! -d "$LOG_BASE_DIR" ]; then
        echo "No log directory found at $LOG_BASE_DIR"
        return 1
    fi
    
    local current_session=""
    if [ -f "$CURRENT_SESSION_FILE" ]; then
        current_session=$(cat "$CURRENT_SESSION_FILE")
    fi
    
    echo "Session ID       | Created           | Log Lines | CSV Entries | Status"
    echo "-----------------+-------------------+-----------+-------------+--------"
    
    find "$LOG_BASE_DIR" -maxdepth 1 -type d -name "*_*" 2>/dev/null | sort -r | while read -r session_path; do
        local session_name=$(basename "$session_path")
        local log_file="$session_path/ssh_reboot.log"
        local csv_file="$session_path/ssh_reboot.csv"
        
        # Parse timestamp for readable date
        local year=${session_name:0:4}
        local month=${session_name:4:2}
        local day=${session_name:6:2}
        local hour=${session_name:9:2}
        local min=${session_name:11:2}
        local sec=${session_name:13:2}
        local readable_date="$year-$month-$day $hour:$min:$sec"
        
        # Count log lines and CSV entries
        local log_lines=0
        local csv_entries=0
        
        if [ -f "$log_file" ]; then
            log_lines=$(wc -l < "$log_file")
        fi
        
        if [ -f "$csv_file" ]; then
            csv_entries=$(($(wc -l < "$csv_file") - 1))  # Subtract header
            [ $csv_entries -lt 0 ] && csv_entries=0
        fi
        
        # Determine status
        local status="Inactive"
        if [ "$session_name" = "$current_session" ]; then
            status="Current"
        fi
        
        printf "%-16s | %-17s | %-9d | %-11d | %-7s\n" \
            "$session_name" "$readable_date" "$log_lines" "$csv_entries" "$status"
    done
}

switch_session() {
    echo "Available sessions:"
    echo ""
    
    # List sessions with numbers
    local sessions=($(find "$LOG_BASE_DIR" -maxdepth 1 -type d -name "*_*" 2>/dev/null | sort -r))
    
    if [ ${#sessions[@]} -eq 0 ]; then
        echo "No log sessions found"
        return 1
    fi
    
    local i=1
    for session_path in "${sessions[@]}"; do
        local session_name=$(basename "$session_path")
        local csv_file="$session_path/ssh_reboot.csv"
        local csv_entries=0
        
        if [ -f "$csv_file" ]; then
            csv_entries=$(($(wc -l < "$csv_file") - 1))
            [ $csv_entries -lt 0 ] && csv_entries=0
        fi
        
        echo "$i) $session_name ($csv_entries reboot attempts)"
        ((i++))
    done
    
    echo ""
    echo -n "Select session number (1-${#sessions[@]}): "
    read -r selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#sessions[@]} ]; then
        local selected_path="${sessions[$((selection-1))]}"
        local selected_name=$(basename "$selected_path")
        
        echo "$selected_name" > "$CURRENT_SESSION_FILE"
        echo "Switched to session: $selected_name"
        echo "Use any command to view logs from this session"
    else
        echo "Invalid selection"
        return 1
    fi
}

check_files() {
    if [ -z "$SESSION_DIR" ] || [ ! -f "$REBOOT_LOG_CSV" ]; then
        echo "Error: No active session or reboot tracking file not found"
        echo ""
        echo "Available sessions:"
        find "$LOG_BASE_DIR" -maxdepth 1 -type d -name "*_*" 2>/dev/null | sort -r | head -5 | while read -r session_path; do
            echo "  $(basename "$session_path")"
        done
        echo ""
        echo "Use '$0 switch' to select a session or run the reboot script first"
        exit 1
    fi
}

show_summary() {
    check_files
    echo "=== Reboot Summary ==="
    echo "Session: $(basename "$SESSION_DIR")"
    echo ""
    
    # Count total attempts
    local total=$(tail -n +2 "$REBOOT_LOG_CSV" | wc -l)
    echo "Total reboot attempts: $total"
    
    if [ "$total" -eq 0 ]; then
        echo "No reboot attempts logged yet."
        return
    fi
    
    # Count successful reboots
    local successful=$(tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' '$5=="Yes"' | wc -l)
    echo "Successful reboots: $successful"
    echo "Failed reboots: $((total - successful))"
    
    if [ "$total" -gt 0 ]; then
        local success_rate=$(echo "scale=1; $successful * 100 / $total" | bc 2>/dev/null || echo "N/A")
        echo "Success rate: ${success_rate}%"
    fi
    
    echo ""
    echo "Recent attempts (last 5):"
    echo "Time                | Success | Downtime | Notes"
    echo "--------------------+---------+----------+---------------------------"
    tail -n 5 "$REBOOT_LOG_CSV" | awk -F',' '{
        gsub(/"/, "", $7);  # Remove quotes from notes
        printf "%-19s | %-7s | %-8s | %-25s\n", $1, $5, $6"s", $7
    }'
}

show_recent() {
    check_files
    echo "=== Recent Reboot Attempts (Last 10) ==="
    echo "Session: $(basename "$SESSION_DIR")"
    echo ""
    
    if [ $(wc -l < "$REBOOT_LOG_CSV") -le 1 ]; then
        echo "No reboot attempts logged yet."
        return
    fi
    
    echo "Time                | Init | Down | Back | Success | Downtime | Notes"
    echo "--------------------+------+------+------+---------+----------+---------------------------"
    tail -n 10 "$REBOOT_LOG_CSV" | awk -F',' '{
        if (NR > 1 || NF > 1) {  # Skip header if it appears
            gsub(/"/, "", $7);  # Remove quotes from notes
            printf "%-19s | %-4s | %-4s | %-4s | %-7s | %-8s | %-25s\n", $1, $2, $3, $4, $5, $6"s", $7
        }
    }'
}

show_all() {
    check_files
    echo "=== All Reboot Attempts ==="
    echo "Session: $(basename "$SESSION_DIR")"
    echo ""
    
    if [ $(wc -l < "$REBOOT_LOG_CSV") -le 1 ]; then
        echo "No reboot attempts logged yet."
        return
    fi
    
    cat "$REBOOT_LOG_CSV" | awk -F',' '
    NR==1 {
        print "Time                | Init | Down | Back | Success | Downtime | Notes"
        print "--------------------+------+------+------+---------+----------+---------------------------"
    }
    NR>1 {
        gsub(/"/, "", $7);  # Remove quotes from notes
        printf "%-19s | %-4s | %-4s | %-4s | %-7s | %-8s | %-25s\n", $1, $2, $3, $4, $5, $6"s", $7
    }'
}

show_successful() {
    check_files
    echo "=== Successful Reboots Only ==="
    echo "Session: $(basename "$SESSION_DIR")"
    echo ""
    
    local count=$(tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' '$5=="Yes"' | wc -l)
    if [ "$count" -eq 0 ]; then
        echo "No successful reboots logged yet."
        return
    fi
    
    echo "Time                | Downtime | Notes"
    echo "--------------------+----------+---------------------------"
    tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' '$5!="Yes" {
        gsub(/"/, "", $7);  # Remove quotes from notes
        printf "%-19s | %-4s | %-4s | %-4s | %-25s\n", $1, $2, $3, $4, $7
    }'
}

show_stats() {
    check_files
    echo "=== Reboot Statistics ==="
    echo "Session: $(basename "$SESSION_DIR")"
    echo ""
    
    local total=$(tail -n +2 "$REBOOT_LOG_CSV" | wc -l)
    if [ "$total" -eq 0 ]; then
        echo "No reboot attempts logged yet."
        return
    fi
    
    # Basic stats
    local successful=$(tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' '$5=="Yes"' | wc -l)
    local failed=$((total - successful))
    
    echo "Total attempts: $total"
    echo "Successful: $successful"
    echo "Failed: $failed"
    
    if [ "$total" -gt 0 ]; then
        local success_rate=$(echo "scale=1; $successful * 100 / $total" | bc 2>/dev/null || echo "N/A")
        echo "Success rate: ${success_rate}%"
    fi
    
    echo ""
    
    # Average downtime for successful reboots
    if [ "$successful" -gt 0 ]; then
        local avg_downtime=$(tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' '$5=="Yes" && $6>0 {sum+=$6; count++} END {if(count>0) printf "%.1f", sum/count; else print "N/A"}')
        echo "Average downtime (successful reboots): ${avg_downtime}s"
        
        # Min/Max downtime
        local min_downtime=$(tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' '$5=="Yes" && $6>0 {if(min=="" || $6<min) min=$6} END {print (min=="" ? "N/A" : min)}')
        local max_downtime=$(tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' '$5=="Yes" && $6>0 {if($6>max) max=$6} END {print (max=="" ? "N/A" : max)}')
        echo "Min downtime: ${min_downtime}s"
        echo "Max downtime: ${max_downtime}s"
    fi
    
    echo ""
    echo "Failure reasons:"
    tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' '$5!="Yes" {
        gsub(/"/, "", $7);
        reasons[$7]++
    } END {
        for (reason in reasons) {
            printf "  %s: %d times\n", reason, reasons[reason]
        }
    }'
    
    echo ""
    echo "Last 24 hours activity:"
    local yesterday=$(date -d "yesterday" '+%Y-%m-%d' 2>/dev/null || date -v-1d '+%Y-%m-%d' 2>/dev/null || echo "N/A")
    if [ "$yesterday" != "N/A" ]; then
        local recent_total=$(tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' -v date="$yesterday" '$1 >= date' | wc -l)
        local recent_success=$(tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' -v date="$yesterday" '$1 >= date && $5=="Yes"' | wc -l)
        echo "  Attempts in last 24h: $recent_total"
        echo "  Successful in last 24h: $recent_success"
    fi
}

tail_log() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "Error: Main log file not found: $LOG_FILE"
        echo "Current session: $(basename "$SESSION_DIR" 2>/dev/null || echo "None")"
        
        # Show available sessions
        echo ""
        echo "Available sessions with logs:"
        find "$LOG_BASE_DIR" -name "ssh_reboot.log" -type f 2>/dev/null | while read -r logfile; do
            local session_name=$(basename "$(dirname "$logfile")")
            echo "  $session_name"
        done
        echo ""
        echo "Use '$0 switch' to select a different session"
        exit 1
    fi
    
    echo "Following log file: $LOG_FILE"
    echo "Session: $(basename "$SESSION_DIR")"
    echo "Press Ctrl+C to stop"
    echo "----------------------------------------"
    tail -f "$LOG_FILE"
}

case "$1" in
    summary)
        show_summary
        ;;
    recent)
        show_recent
        ;;
    all)
        show_all
        ;;
    successful)
        show_successful
        ;;
    failed)
        show_failed
        ;;
    stats)
        show_stats
        ;;
    tail)
        tail_log
        ;;
    sessions)
        show_sessions
        ;;
    switch)
        switch_session
        ;;
    *)
        show_usage
        exit 1
        ;;
esac" | awk -F',' '$5=="Yes" {
        gsub(/"/, "", $7);  # Remove quotes from notes
        printf "%-19s | %-8s | %-25s\n", $1, $6"s", $7
    }'
}

show_failed() {
    check_files
    echo "=== Failed Reboots Only ==="
    echo "Session: $(basename "$SESSION_DIR")"
    echo ""
    
    local count=$(tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' '$5!="Yes"' | wc -l)
    if [ "$count" -eq 0 ]; then
        echo "No failed reboots logged."
        return
    fi
    
    echo "Time                | Init | Down | Back | Notes"
    echo "--------------------+------+------+------+---------------------------"
    tail -n +2 "$REBOOT_LOG_CSV