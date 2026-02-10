#!/bin/bash

# =============================================================================
# Linux System Monitor - Enhanced Version
# =============================================================================
# A comprehensive system monitoring tool that tracks CPU, memory, disk,
# and network usage with colorized output, configurable thresholds,
# and optional logging capabilities.
# =============================================================================

# ============================================
# Configuration
# ============================================
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=80
NETWORK_THRESHOLD=1000  # KB/s
LOG_FILE=""
LOG_ENABLED=false
REFRESH_INTERVAL=2

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ============================================
# Helper Functions
# ============================================

# Print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Print header with border
print_header() {
    local title=$1
    local width=${#title}
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${BOLD}${WHITE}${title}${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════════════╣${NC}"
}

# Draw a progress bar
draw_progress_bar() {
    local current=$1
    local max=$2
    local bar_width=30

    # Use integer arithmetic (truncate decimals if present)
    current=${current%.*}
    if [[ -z "$current" || "$current" -lt 0 ]]; then
        current=0
    fi
    if [[ "$current" -gt "$max" ]]; then
        current=$max
    fi

    local filled=$(( (current * bar_width) / max ))
    local empty=$(( bar_width - filled ))
    local color=$3

    local bar=""
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        bar+="░"
    done

    echo -e "${color}[${bar}] ${current}%${NC}"
}

# Send alert notification
send_alert() {
    local resource=$1
    local value=$2
    local threshold=$3
    print_color "$RED" "  ⚠ ALERT: ${resource} usage exceeded threshold! (${value}% >= ${threshold}%)"
}

# Log to file if logging is enabled
log_message() {
    if [[ "$LOG_ENABLED" == true ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[${timestamp}] $1" >> "$LOG_FILE"
    fi
}

# Get CPU usage (returns integer percentage)
get_cpu_usage() {
    # Try multiple methods for CPU detection
    if command -v top &>/dev/null; then
        cpu_usage=$(top -bn1 2>/dev/null | grep -E "Cpu\(s\)|%Cpu" | awk '{print int($2 + $4)}' | head -1)
    elif [[ -f /proc/stat ]]; then
        cpu_line=$(grep '^cpu ' /proc/stat)
        cpu_total=$(echo "$cpu_line" | awk '{print $2+$3+$4+$5+$6+$7+$8}')
        cpu_idle=$(echo "$cpu_line" | awk '{print $5}')
        cpu_usage=$(echo "scale=0; ($cpu_total - $cpu_idle) * 100 / $cpu_total" | bc 2>/dev/null)
    else
        cpu_usage=0
    fi
    # Handle empty or invalid values
    if [[ -z "$cpu_usage" || "$cpu_usage" == "0" ]]; then
        cpu_usage=$(awk '{u=$2+$4; t=$2+$4+$5; print int(u/t*100)}' /proc/stat 2>/dev/null)
    fi
    # Ensure we return an integer
    echo "${cpu_usage%.*:-0}"
}

# Get memory usage (returns integer percentage)
get_memory_usage() {
    local mem_info=$(free -b | awk '/Mem:/ {print $3 "/" $2}')
    if [[ -n "$mem_info" ]]; then
        echo "$mem_info" | awk -F'/' '{printf "%.0f", ($1/$2)*100}'
    else
        echo "0"
    fi
}

# Get memory usage as float for display
get_memory_usage_float() {
    local mem_info=$(free -b | awk '/Mem:/ {print $3 "/" $2}')
    if [[ -n "$mem_info" ]]; then
        echo "$mem_info" | awk -F'/' '{printf "%.1f", ($1/$2)*100}'
    else
        echo "0.0"
    fi
}

# Get memory details
get_memory_details() {
    free -h | awk '/Mem:/ {printf "Used: %s / Total: %s", $3, $2}'
}

# Get disk usage (returns integer percentage)
get_disk_usage() {
    df -h / 2>/dev/null | awk 'NR==2 {gsub(/%/, "", $5); print int($5)}'
}

# Get disk details
get_disk_details() {
    df -h / 2>/dev/null | awk 'NR==2 {printf "Used: %s / Total: %s (Available: %s)", $3, $2, $4}'
}

# Get network statistics
get_network_stats() {
    local rx_bytes=0
    local tx_bytes=0

    # Try to get stats from /sys/class/net
    for iface in /sys/class/net/*/; do
        if [[ -f "${iface}statistics/rx_bytes" ]] && [[ -f "${iface}statistics/tx_bytes" ]]; then
            # Skip loopback interface
            local if_name=$(basename "$iface")
            if [[ "$if_name" != "lo" ]] && [[ -f "${iface}operstate" ]] && [[ $(cat "${iface}operstate") == "up" ]]; then
                rx_bytes=$((rx_bytes + $(cat "${iface}statistics/rx_bytes" 2>/dev/null || echo 0)))
                tx_bytes=$((tx_bytes + $(cat "${iface}statistics/tx_bytes" 2>/dev/null || echo 0)))
            fi
        fi
    done

    # Convert to KB/s (estimate over 1 second)
    local rx_kbps=$((rx_bytes / 1024))
    local tx_kbps=$((tx_bytes / 1024))

    echo "$rx_kbps $tx_kbps"
}

# Get top processes
get_top_processes() {
    if command -v ps &>/dev/null; then
        ps aux --sort=-%cpu 2>/dev/null | head -6 | tail -5
    fi
}

# Get system uptime
get_uptime() {
    if [[ -f /proc/uptime ]]; then
        local uptime_seconds=$(cut -d. -f1 /proc/uptime)
        local days=$((uptime_seconds / 86400))
        local hours=$(( (uptime_seconds % 86400) / 3600 ))
        local minutes=$(( (uptime_seconds % 3600) / 60 ))
        printf "%d days, %d hours, %d minutes" "$days" "$hours" "$minutes"
    else
        uptime -p 2>/dev/null || echo "Unknown"
    fi
}

# Get hostname
get_hostname() {
    hostname 2>/dev/null || echo "Unknown"
}

# Get OS information
get_os_info() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${NAME} ${VERSION_ID}"
    else
        uname -s -r
    fi
}

# ============================================
# Display Functions
# ============================================

# Display system information
display_system_info() {
    print_header " System Information "
    echo -e "${CYAN}Hostname:${NC} $(get_hostname)"
    echo -e "${CYAN}OS:${NC} $(get_os_info)"
    echo -e "${CYAN}Kernel:${NC} $(uname -r)"
    echo -e "${CYAN}Uptime:${NC} $(get_uptime)"
    echo -e "${CYAN}Thresholds:${NC} CPU=${CPU_THRESHOLD}% | MEM=${MEMORY_THRESHOLD}% | DISK=${DISK_THRESHOLD}%"
    echo ""
}

# Display resource usage with progress bars
display_resources() {
    print_header " Resource Usage "

    # CPU Usage
    local cpu_usage=$(get_cpu_usage)
    local cpu_usage_int=${cpu_usage%.*}
    if [[ -z "$cpu_usage_int" || "$cpu_usage_int" -lt 0 ]]; then
        cpu_usage_int=0
    fi
    printf "${WHITE}CPU Usage:${NC} %3s%%\n" "$cpu_usage"
    draw_progress_bar "$cpu_usage_int" "100" "$RED"
    echo ""

    # Memory Usage
    local mem_usage=$(get_memory_usage)
    printf "${WHITE}Memory:${NC}  %3s%%\n" "$mem_usage"
    draw_progress_bar "$mem_usage" "100" "$BLUE"
    echo -e "${CYAN}       ${NC} $(get_memory_details)"
    echo ""

    # Disk Usage
    local disk_usage=$(get_disk_usage)
    local disk_usage_float=$(df -h / 2>/dev/null | awk 'NR==2 {gsub(/%/, "", $5); print $5}')
    printf "${WHITE}Disk:${NC}    %3s%%\n" "$disk_usage_float"
    draw_progress_bar "$disk_usage" "100" "$GREEN"
    echo -e "${CYAN}       ${NC} $(get_disk_details)"
    echo ""

    # Network Usage
    local net_stats=$(get_network_stats)
    local rx_kbps=$(echo "$net_stats" | awk '{print $1}')
    local tx_kbps=$(echo "$net_stats" | awk '{print $2}')
    printf "${WHITE}Network:${NC} RX: %6d KB/s  TX: %6d KB/s\n" "$rx_kbps" "$tx_kbps"
    echo ""
}

# Display alerts
display_alerts() {
    local has_alerts=false

    local cpu_usage=$(get_cpu_usage)
    if [[ "$cpu_usage" -ge "$CPU_THRESHOLD" ]]; then
        send_alert "CPU" "$cpu_usage" "$CPU_THRESHOLD"
        has_alerts=true
    fi

    local mem_usage=$(get_memory_usage)
    if [[ "$mem_usage" -ge "$MEMORY_THRESHOLD" ]]; then
        send_alert "Memory" "$mem_usage" "$MEMORY_THRESHOLD"
        has_alerts=true
    fi

    local disk_usage=$(get_disk_usage)
    if [[ "$disk_usage" -ge "$DISK_THRESHOLD" ]]; then
        send_alert "Disk" "$disk_usage" "$DISK_THRESHOLD"
        has_alerts=true
    fi

    if [[ "$has_alerts" == false ]]; then
        print_color "$GREEN" "  ✓ All systems operating normally"
    fi
    echo ""
}

# Display top processes
display_processes() {
    print_header " Top 5 Processes by CPU "
    echo -e "${WHITE}  USER       PID  %CPU  %MEM  COMMAND${NC}"
    get_top_processes | while read -r line; do
        # Format the line nicely
        printf "  %-10s %5s %5s %5s  %s\n" \
            "$(echo "$line" | awk '{print $1}')" \
            "$(echo "$line" | awk '{print $2}')" \
            "$(echo "$line" | awk '{print $3}')" \
            "$(echo "$line" | awk '{print $4}')" \
            "$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')"
    done
    echo ""
}

# Display status bar
display_status_bar() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}═════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Last updated:${NC} $timestamp"
    echo -e "${BLUE}═════════════════════════════════════════════════════════════════════${NC}"
}

# Main display function
display_monitor() {
    clear
    display_system_info
    display_resources
    display_alerts
    display_processes
    display_status_bar
}

# Usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --cpu-threshold <n>    Set CPU alert threshold (default: 80)"
    echo "  -m, --mem-threshold <n>    Set memory alert threshold (default: 80)"
    echo "  -d, --disk-threshold <n>   Set disk alert threshold (default: 80)"
    echo "  -i, --interval <n>         Set refresh interval in seconds (default: 2)"
    echo "  -l, --log <file>           Enable logging to file"
    echo "  -s, --single               Single run mode (no continuous monitoring)"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -c 90 -m 85 -d 70 -i 5"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--cpu-threshold)
                CPU_THRESHOLD="$2"
                shift 2
                ;;
            -m|--mem-threshold)
                MEMORY_THRESHOLD="$2"
                shift 2
                ;;
            -d|--disk-threshold)
                DISK_THRESHOLD="$2"
                shift 2
                ;;
            -i|--interval)
                REFRESH_INTERVAL="$2"
                shift 2
                ;;
            -l|--log)
                LOG_ENABLED=true
                LOG_FILE="$2"
                # Create log file if it doesn't exist
                touch "$LOG_FILE" 2>/dev/null
                shift 2
                ;;
            -s|--single)
                SINGLE_RUN=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# ============================================
# Main Execution
# ============================================

# Parse command line arguments
parse_args "$@"

# Check for prerequisites
check_prerequisites() {
    local missing=()
    for cmd in top free df awk; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_color "$RED" "Error: Missing required commands: ${missing[*]}"
        exit 1
    fi
}

# Initialize
check_prerequisites
log_message "System monitor started with thresholds: CPU=${CPU_THRESHOLD}%, MEM=${MEMORY_THRESHOLD}%, DISK=${DISK_THRESHOLD}%"

# Main loop
if [[ "${SINGLE_RUN}" == true ]]; then
    display_monitor
else
    trap 'echo -e "\n${YELLOW}Monitor stopped.${NC}"; log_message "System monitor stopped"; exit 0' INT TERM

    while true; do
        display_monitor
        sleep "$REFRESH_INTERVAL"
    done
fi
