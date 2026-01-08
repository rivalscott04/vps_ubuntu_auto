#!/bin/bash

# Warna
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
NC='\033[0m'
BOLD='\033[1m'

LINE="${CYAN}──────────────────────────────────────────────────────────────${NC}"

show_general_info() {
    START_TIME=$(date +%s)
    clear
    
    # CPU Info
    CPU_MODEL=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ //')
    CPU_CORES=$(nproc)
    CPU_FREQ=$(lscpu 2>/dev/null | grep "CPU MHz" | awk '{print $3}' | head -1)
    if [ -z "$CPU_FREQ" ]; then
        CPU_FREQ=$(grep -m1 "cpu MHz" /proc/cpuinfo | awk '{printf "%.3f", $4}')
    fi
    CPU_CACHE=$(lscpu 2>/dev/null | grep "L3 cache" | awk '{print $3, $4}' | head -1)
    if [ -z "$CPU_CACHE" ]; then
        CPU_CACHE=$(grep -m1 "cache size" /proc/cpuinfo | awk -F: '{print $2}' | sed 's/^ //')
    fi
    
    # Disk Info
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}' | sed 's/G/ GB/')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}' | sed 's/G/ GB/')
    
    # Memory Info
    MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    
    # System Uptime
    UPTIME_DAYS=$(uptime -p | awk '{for(i=1;i<=NF;i++) if($i=="days," || $i=="day,") print $(i-1)}')
    UPTIME_HOURS=$(uptime -p | awk '{for(i=1;i<=NF;i++) if($i=="hours," || $i=="hour,") print $(i-1)}')
    UPTIME_MINS=$(uptime -p | awk '{for(i=1;i<=NF;i++) if($i=="minutes," || $i=="min,") print $(i-1)}')
    if [ -z "$UPTIME_DAYS" ]; then UPTIME_DAYS="0"; fi
    if [ -z "$UPTIME_HOURS" ]; then UPTIME_HOURS="0"; fi
    if [ -z "$UPTIME_MINS" ]; then UPTIME_MINS="0"; fi
    
    # Load Average
    LOAD_AVG=$(uptime | awk -F'load average:' '{ print $2 }' | sed 's/^ //')
    
    # OS Info
    OS=$(lsb_release -ds 2>/dev/null || cat /etc/*release | grep PRETTY_NAME | cut -d '"' -f2)
    ARCH=$(uname -m)
    KERNEL=$(uname -r)
    BIT=$(getconf LONG_BIT)
    
    # TCP Congestion Control
    TCP_CC=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    if [ -z "$TCP_CC" ]; then TCP_CC="N/A"; fi
    
    # Virtualization
    VIRT=$(systemd-detect-virt 2>/dev/null || echo "Unknown")
    if [ "$VIRT" = "none" ]; then
        VIRT="Dedicated"
    fi
    
    # IPv4/IPv6 Status
    IPV4_STATUS=$(ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 && echo "Online" || echo "Offline")
    IPV6_STATUS=$(ping6 -c 1 -W 2 2001:4860:4860::8888 >/dev/null 2>&1 && echo "Online" || echo "Offline")
    if [ "$IPV4_STATUS" = "Online" ]; then
        IPV4_ICON="${GREEN}✓${NC}"
    else
        IPV4_ICON="${RED}✗${NC}"
    fi
    if [ "$IPV6_STATUS" = "Online" ]; then
        IPV6_ICON="${GREEN}✓${NC}"
    else
        IPV6_ICON="${RED}✗${NC}"
    fi
    
    # IP Info (Organization & Location)
    ORG=""
    CITY=""
    REGION=""
    COUNTRY=""
    if command -v curl >/dev/null 2>&1; then
        PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 ipinfo.io/ip 2>/dev/null)
        if [ ! -z "$PUBLIC_IP" ]; then
            IP_INFO=$(curl -s --max-time 5 "https://ipinfo.io/$PUBLIC_IP/json" 2>/dev/null)
            if [ ! -z "$IP_INFO" ]; then
                ORG=$(echo "$IP_INFO" | grep -o '"org":[^,]*' | cut -d'"' -f4)
                CITY=$(echo "$IP_INFO" | grep -o '"city":[^,]*' | cut -d'"' -f4)
                REGION=$(echo "$IP_INFO" | grep -o '"region":[^,]*' | cut -d'"' -f4)
                COUNTRY=$(echo "$IP_INFO" | grep -o '"country":[^,]*' | cut -d'"' -f4)
            fi
        fi
    fi
    
    # Display System Information
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}        ${MAGENTA}🌐  VPS SYSTEM INFORMATION  ${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "$LINE"
    
    # Format konsisten dengan printf untuk alignment
    printf "${YELLOW}%-18s${NC} %s\n" "CPU Model:" "$CPU_MODEL"
    printf "${YELLOW}%-18s${NC} %s @ %s MHz\n" "CPU Cores:" "$CPU_CORES" "$CPU_FREQ"
    if [ ! -z "$CPU_CACHE" ]; then
        printf "${YELLOW}%-18s${NC} %s\n" "CPU Cache:" "$CPU_CACHE"
    fi
    
    # AES-NI Check
    if grep -q "^flags.*aes" /proc/cpuinfo; then
        printf "${YELLOW}%-18s${NC} ${GREEN}✓${NC} %s\n" "AES-NI:" "Enabled"
    else
        printf "${YELLOW}%-18s${NC} ${RED}✗${NC} %s\n" "AES-NI:" "Disabled"
    fi
    
    # VM-x/AMD-V Check
    if grep -q "^flags.*vmx\|^flags.*svm" /proc/cpuinfo; then
        printf "${YELLOW}%-18s${NC} ${GREEN}✓${NC} %s\n" "VM-x/AMD-V:" "Enabled"
    else
        printf "${YELLOW}%-18s${NC} ${RED}✗${NC} %s\n" "VM-x/AMD-V:" "Disabled"
    fi
    
    printf "${YELLOW}%-18s${NC} %s (%s Used)\n" "Total Disk:" "$DISK_TOTAL" "$DISK_USED"
    printf "${YELLOW}%-18s${NC} %s (%s Used)\n" "Total Mem:" "$MEM_TOTAL" "$MEM_USED"
    printf "${YELLOW}%-18s${NC} %s days, %s hour %s min\n" "System uptime:" "$UPTIME_DAYS" "$UPTIME_HOURS" "$UPTIME_MINS"
    printf "${YELLOW}%-18s${NC} %s\n" "Load average:" "$LOAD_AVG"
    printf "${YELLOW}%-18s${NC} %s\n" "OS:" "$OS"
    printf "${YELLOW}%-18s${NC} %s (%s Bit)\n" "Arch:" "$ARCH" "$BIT"
    printf "${YELLOW}%-18s${NC} %s\n" "Kernel:" "$KERNEL"
    printf "${YELLOW}%-18s${NC} %s\n" "TCP CC:" "$TCP_CC"
    printf "${YELLOW}%-18s${NC} %s\n" "Virtualization:" "$VIRT"
    # Format IPv4/IPv6 dengan icon yang benar
    if [ "$IPV4_STATUS" = "Online" ] && [ "$IPV6_STATUS" = "Online" ]; then
        printf "${YELLOW}%-18s${NC} ${GREEN}✓${NC} %s / ${GREEN}✓${NC} %s\n" "IPv4/IPv6:" "$IPV4_STATUS" "$IPV6_STATUS"
    elif [ "$IPV4_STATUS" = "Online" ]; then
        printf "${YELLOW}%-18s${NC} ${GREEN}✓${NC} %s / ${RED}✗${NC} %s\n" "IPv4/IPv6:" "$IPV4_STATUS" "$IPV6_STATUS"
    elif [ "$IPV6_STATUS" = "Online" ]; then
        printf "${YELLOW}%-18s${NC} ${RED}✗${NC} %s / ${GREEN}✓${NC} %s\n" "IPv4/IPv6:" "$IPV4_STATUS" "$IPV6_STATUS"
    else
        printf "${YELLOW}%-18s${NC} ${RED}✗${NC} %s / ${RED}✗${NC} %s\n" "IPv4/IPv6:" "$IPV4_STATUS" "$IPV6_STATUS"
    fi
    
    if [ ! -z "$ORG" ]; then
        printf "${YELLOW}%-18s${NC} %s\n" "Organization:" "$ORG"
    fi
    if [ ! -z "$CITY" ] && [ ! -z "$COUNTRY" ]; then
        printf "${YELLOW}%-18s${NC} %s / %s\n" "Location:" "$CITY" "$COUNTRY"
        if [ ! -z "$REGION" ]; then
            printf "${YELLOW}%-18s${NC} %s\n" "Region:" "$REGION"
        fi
    fi
    
    echo ""
    echo ""
    
    # I/O Speed Test
    echo -e "${CYAN}I/O Speed Test${NC}"
    echo "----------------------------------------"
    echo ""
    
    # Check if bc is installed
    if ! command -v bc >/dev/null 2>&1; then
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y bc >/dev/null 2>&1
    fi
    
    # Function to test I/O speed
    test_io_speed() {
        local test_file="/tmp/benchmark_io_test_$$"
        local test_size=1024  # 1GB in MB
        local output=$(dd if=/dev/zero of="$test_file" bs=1M count=$test_size conv=fdatasync 2>&1)
        rm -f "$test_file"
        
        local speed=$(echo "$output" | tail -1 | awk '{print $(NF-1)}')
        local unit=$(echo "$output" | tail -1 | awk '{print $NF}')
        
        if [ "$unit" = "GB/s" ] || [ "$unit" = "GB/s," ]; then
            speed=$(echo "$speed * 1024" | bc)
        fi
        
        printf "%.0f" "$speed" 2>/dev/null || echo "0"
    }
    
    printf "${YELLOW}%-18s${NC} %s\n" "Testing I/O speed:" "(this may take a while...)"
    IO_SPEED_1=$(test_io_speed)
    IO_SPEED_2=$(test_io_speed)
    IO_SPEED_3=$(test_io_speed)
    
    IO_AVG=$(echo "scale=1; ($IO_SPEED_1 + $IO_SPEED_2 + $IO_SPEED_3) / 3" | bc)
    
    printf "${YELLOW}%-18s${NC} ${GREEN}%s MB/s${NC}\n" "I/O Speed (1st run):" "$IO_SPEED_1"
    printf "${YELLOW}%-18s${NC} ${GREEN}%s MB/s${NC}\n" "I/O Speed (2nd run):" "$IO_SPEED_2"
    printf "${YELLOW}%-18s${NC} ${GREEN}%s MB/s${NC}\n" "I/O Speed (3rd run):" "$IO_SPEED_3"
    printf "${YELLOW}%-18s${NC} ${GREEN}%s MB/s${NC}\n" "I/O Speed (average):" "$IO_AVG"
    
    echo ""
    echo ""
    
    # Network Speedtest
    echo -e "${CYAN}Network Speedtest${NC}"
    echo "----------------------------------------"
    echo ""
    
    # Check if speedtest-cli is installed
    if ! command -v speedtest-cli >/dev/null 2>&1; then
        echo -e "${YELLOW}Installing speedtest-cli...${NC}"
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y speedtest-cli >/dev/null 2>&1
    fi
    
    # Function to find server by location
    find_server_by_location() {
        local location=$1
        # Get server list and find by location name
        local server_list=$(speedtest-cli --list 2>/dev/null)
        if [ -z "$server_list" ]; then
            echo ""
            return
        fi
        
        # Try to find server - format: "ID) Server Name (Location)"
        local found=$(echo "$server_list" | grep -i "$location" | head -1)
        if [ ! -z "$found" ]; then
            # Extract server ID (number before closing parenthesis)
            echo "$found" | sed -n 's/^[[:space:]]*\([0-9]*\))[[:space:]].*/\1/p' | head -1
        else
            echo ""
        fi
    }
    
    # Function to run speedtest
    run_speedtest() {
        local server_id=$1
        local server_name=$2
        
        if [ -z "$server_id" ] || [ "$server_id" = "auto" ]; then
            # Auto-select best server
            result=$(timeout 90 speedtest-cli --simple --secure 2>/dev/null)
        else
            # Test specific server
            result=$(timeout 90 speedtest-cli --server "$server_id" --simple --secure 2>/dev/null)
        fi
        
        local exit_code=$?
        
        if [ $exit_code -eq 0 ] && [ ! -z "$result" ]; then
            local upload=$(echo "$result" | grep -i Upload | awk '{print $2}')
            local download=$(echo "$result" | grep -i Download | awk '{print $2}')
            local ping=$(echo "$result" | grep -i Ping | awk '{print $2}')
            
            if [ ! -z "$upload" ] && [ ! -z "$download" ] && [ ! -z "$ping" ]; then
                # Format dengan printf untuk alignment yang benar
                printf "%-20s" "$server_name"
                printf " ${GREEN}%-19s${NC}" "${upload} Mbps"
                printf " ${RED}%-19s${NC}" "${download} Mbps"
                printf " %-15s\n" "${ping} ms"
                return 0
            fi
        fi
        
        printf "%-20s %-20s %-20s %-15s\n" "$server_name" "Failed" "Failed" "Failed"
        return 1
    }
    
    # Print table header with consistent format
    printf "${YELLOW}%-20s${NC} ${YELLOW}%-20s${NC} ${YELLOW}%-20s${NC} ${YELLOW}%-15s${NC}\n" "Node Name:" "Upload Speed:" "Download Speed:" "Latency:"
    echo "------------------------------------------------------------------------"
    
    printf "${YELLOW}%-18s${NC} %s\n" "Running speedtests:" "(this may take a while...)"
    echo ""
    
    # Default speedtest (auto-select best server)
    run_speedtest "" "Speedtest.net"
    
    # Try to find and test servers in different locations
    # Paris, France
    PARIS_SERVER=$(find_server_by_location "Paris")
    if [ ! -z "$PARIS_SERVER" ] && [ "$PARIS_SERVER" != "" ]; then
        run_speedtest "$PARIS_SERVER" "Paris, FR"
    else
        # Try known server IDs for Paris
        for server_id in 4817 21569 16348 16349; do
            if run_speedtest "$server_id" "Paris, FR"; then
                break
            fi
        done
    fi
    
    # Singapore
    SINGAPORE_SERVER=$(find_server_by_location "Singapore")
    if [ ! -z "$SINGAPORE_SERVER" ] && [ "$SINGAPORE_SERVER" != "" ]; then
        run_speedtest "$SINGAPORE_SERVER" "Singapore, SG"
    else
        # Try known server IDs for Singapore
        for server_id in 7311 13623 13624 13625; do
            if run_speedtest "$server_id" "Singapore, SG"; then
                break
            fi
        done
    fi
    
    # Tokyo, Japan
    TOKYO_SERVER=$(find_server_by_location "Tokyo")
    if [ ! -z "$TOKYO_SERVER" ] && [ "$TOKYO_SERVER" != "" ]; then
        run_speedtest "$TOKYO_SERVER" "Tokyo, JP"
    else
        # Try known server IDs for Tokyo
        for server_id in 8438 7510 7511 7512; do
            if run_speedtest "$server_id" "Tokyo, JP"; then
                break
            fi
        done
    fi
    
    echo ""
    
    # Footer
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    MINUTES=$((ELAPSED / 60))
    SECONDS=$((ELAPSED % 60))
    
    echo "----------------------------------------"
    echo -e "${CYAN}Finished in:${NC} ${MINUTES} min ${SECONDS} sec"
    echo -e "${CYAN}Timestamp:${NC} $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo ""
    echo -e "$LINE"
    read -p "Tekan Enter untuk kembali ke menu... "
}

show_webserver_info() {
    clear
    echo -e "${CYAN}${BOLD}Webserver Detected:${NC}"
    echo -e "$LINE"
    for svc in nginx apache2 caddy frankenphp; do
        if systemctl list-units --type=service | grep -q "$svc"; then
            status=$(systemctl is-active $svc)
            version=$($svc -v 2>&1 | head -n1 | sed 's/^[^0-9]*//')
            if [ "$svc" = "apache2" ]; then
                version=$(apache2 -v 2>/dev/null | grep version | awk '{print $3}')
            fi
            if [ "$svc" = "frankenphp" ]; then
                version=$(frankenphp --version 2>/dev/null | head -n1)
            fi
            color=$([ "$status" = "active" ] && echo "$GREEN" || echo "$RED")
            printf "${color}%-12s${NC} | %-8s | %s\n" "$svc" "$status" "$version"
        fi
    done
    echo -e "$LINE"
    echo -e "${CYAN}Tekan Enter untuk kembali ke menu...${NC}"
    read
}

show_disk_info() {
    clear
    echo -e "${CYAN}${BOLD}Disk Usage:${NC}"
    echo -e "$LINE"
    printf "${BOLD}%-20s %-10s %-10s %-10s %-6s${NC}\n" "Mount" "Total" "Used" "Avail" "%Use"
    df -h --output=target,size,used,avail,pcent | tail -n +2 | while read mnt size used avail pcent; do
        pval=$(echo $pcent | tr -d '%')
        color=$([ $pval -ge 80 ] && echo "$RED" || echo "$GREEN")
        printf "%-20s %-10s %-10s %-10s ${color}%-6s${NC}\n" "$mnt" "$size" "$used" "$avail" "$pcent"
    done
    echo -e "$LINE"
    echo -e "${CYAN}Tekan Enter untuk kembali ke menu...${NC}"
    read
}

show_memory_info() {
    clear
    echo -e "${CYAN}${BOLD}Memory & Top RAM Usage:${NC}"
    echo -e "$LINE"
    free -h
    echo -e "$LINE"
    echo -e "${BOLD}Top 5 Proses Pemakai RAM:${NC}"
    ps -eo pid,comm,%mem,%cpu --sort=-%mem | head -n 6 | awk '{printf "%-8s %-20s %-8s %-8s\n", $1, $2, $3"%", $4"%"}'
    echo -e "$LINE"
    echo -e "${CYAN}Tekan Enter untuk kembali ke menu...${NC}"
    read
}

while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}        ${MAGENTA}🌐  VPS SYSTEM INFORMATION  ${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "$LINE"
    echo -e "${BOLD}1.${NC} Info Umum VPS"
    echo -e "${BOLD}2.${NC} Info Webserver"
    echo -e "${BOLD}3.${NC} Info Disk"
    echo -e "${BOLD}4.${NC} Info Memory"
    echo -e "${BOLD}0.${NC} Keluar"
    echo -e "$LINE"
    read -p "Pilih menu [0-4]: " menu
    case $menu in
        1) show_general_info; read -p "Tekan Enter untuk kembali ke menu...";;
        2) show_webserver_info;;
        3) show_disk_info;;
        4) show_memory_info;;
        0) exit 0;;
        *) echo "Pilihan tidak valid!"; sleep 1;;
    esac
done 