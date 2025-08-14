#!/bin/bash

# Reboot Log Viewer Script
# This script helps view and analyze the reboot tracking logs

# REBOOT_LOG_CSV="$HOME/rebootScript/ssh_reboot_tracking.csv"
# LOG_FILE="$HOME/rebootScript/ssh_reboot.log"


TIMESTAMP=$(date +%Y%m%d_%H%M%S) 
OUTPUT_DIR="./logs/$TIMESTAMP"     
LOG_FILE="$OUTPUT_DIR/ssh_reboot.log" 
REBOOT_LOG_CSV="$OUTPUT_DIR/ssh_reboot.csv"



show_usage() {
    echo "Usage: $0 {summary|recent|all|successful|failed|stats|tail}"
    echo ""
    echo "Commands:"
    echo "  summary    - Show summary of recent reboot attempts"
    echo "  recent     - Show last 10 reboot attempts"
    echo "  all        - Show all reboot attempts"
    echo "  successful - Show only successful reboots"
    echo "  failed     - Show only failed reboots"
    echo "  stats      - Show reboot statistics"
    echo "  tail       - Follow the main log file in real-time"
}

check_files() {
    if [ ! -f "$REBOOT_LOG_CSV" ]; then
        echo "Error: Reboot tracking file not found: $REBOOT_LOG_CSV"
        echo "Run a reboot script first to create the tracking log."
        exit 1
    fi
}

show_summary() {
    check_files
    echo "=== Reboot Summary ==="
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
    echo ""
    
    local count=$(tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' '$5=="Yes"' | wc -l)
    if [ "$count" -eq 0 ]; then
        echo "No successful reboots logged yet."
        return
    fi
    
    echo "Time                | Downtime | Notes"
    echo "--------------------+----------+---------------------------"
    tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' '$5=="Yes" {
        gsub(/"/, "", $7);  # Remove quotes from notes
        printf "%-19s | %-8s | %-25s\n", $1, $6"s", $7
    }'
}

show_failed() {
    check_files
    echo "=== Failed Reboots Only ==="
    echo ""
    
    local count=$(tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' '$5!="Yes"' | wc -l)
    if [ "$count" -eq 0 ]; then
        echo "No failed reboots logged."
        return
    fi
    
    echo "Time                | Init | Down | Back | Notes"
    echo "--------------------+------+------+------+---------------------------"
    tail -n +2 "$REBOOT_LOG_CSV" | awk -F',' '$5!="Yes" {
        gsub(/"/, "", $7);  # Remove quotes from notes
        printf "%-19s | %-4s | %-4s | %-4s | %-25s\n", $1, $2, $3, $4, $7
    }'
}

show_stats() {
    check_files
    echo "=== Reboot Statistics ==="
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
        exit 1
    fi
    
    echo "Following log file: $LOG_FILE"
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
    *)
        show_usage
        exit 1
        ;;
esac