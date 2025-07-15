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
    OS=$(lsb_release -ds 2>/dev/null || cat /etc/*release | grep PRETTY_NAME | cut -d '"' -f2)
    HOSTNAME=$(hostname)
    KERNEL=$(uname -r)
    UPTIME=$(uptime -p)
    CPU=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ //')
    CORES=$(nproc)
    LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | sed 's/^ //')
    MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    MEM_FREE=$(free -h | awk '/^Mem:/ {print $4}')
    DISK_TOTAL=$(df -h / | awk 'END{print $2}')
    DISK_USED=$(df -h / | awk 'END{print $3}')
    DISK_AVAIL=$(df -h / | awk 'END{print $4}')
    IPV4=$(hostname -I | awk '{print $1}')
    IPV6=$(hostname -I | awk '{print $2}')
    PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
    USER=$(whoami)
    LOGGED_USERS=$(who | wc -l)
    LAST_LOGIN=$(last -n 1 -R -F $USER | head -n 1 | awk '{print $4, $5, $6, $7, $8}')
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}        ${MAGENTA}🌐  VPS SYSTEM INFORMATION  ${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "$LINE"
    echo -e "${YELLOW}OS         :${NC} $OS"
    echo -e "${YELLOW}Hostname   :${NC} $HOSTNAME"
    echo -e "${YELLOW}Kernel     :${NC} $KERNEL"
    echo -e "${YELLOW}Uptime     :${NC} $UPTIME"
    echo -e "$LINE"
    echo -e "${GREEN}CPU        :${NC} $CPU ($CORES cores)"
    echo -e "${GREEN}Load Avg   :${NC} $LOAD"
    echo -e "$LINE"
    echo -e "${BLUE}RAM Used   :${NC} $MEM_USED / $MEM_TOTAL"
    echo -e "${BLUE}RAM Free   :${NC} $MEM_FREE"
    echo -e "${BLUE}Disk Used  :${NC} $DISK_USED / $DISK_TOTAL (Avail: $DISK_AVAIL)"
    echo -e "$LINE"
    echo -e "${MAGENTA}IPv4       :${NC} $IPV4"
    echo -e "${MAGENTA}IPv6       :${NC} $IPV6"
    echo -e "${MAGENTA}Public IP  :${NC} $PUBLIC_IP"
    echo -e "$LINE"
    echo -e "${CYAN}User       :${NC} $USER ($LOGGED_USERS logged in)"
    echo -e "${CYAN}Last Login :${NC} $LAST_LOGIN"
    echo -e "$LINE"
    echo -e "${CYAN}Tanggal    :${NC} $(date)"
    echo -e "$LINE"
    echo -e "${GREEN}Tips:${NC} Gunakan VPS ini dengan bijak dan selalu cek resource!"
    echo -e "$LINE"
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