# === Logging Utilities ===
log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# === Utilities ===
check_and_install_package() {
    if ! dpkg -l | grep -q "^ii  $1 "; then
        log_warning "Paket $1 belum terinstal. Menginstal..."
        apt update > /dev/null 2>&1
        apt install -y $1 > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_info "Paket $1 berhasil diinstal"
        else
            log_error "Gagal menginstal paket $1"
            exit 1
        fi
    fi
}

add_ppa_if_needed() {
    local ppa_name=$1
    local ppa_list="/etc/apt/sources.list.d/${ppa_name}*.list"

    if ls $ppa_list 1> /dev/null 2>&1; then
        log_info "PPA $ppa_name sudah ditambahkan"
    else
        log_info "Menambahkan PPA $ppa_name..."
        add-apt-repository -y ppa:$ppa_name > /dev/null 2>&1
        apt update > /dev/null 2>&1
    fi
}

# Spinner/progress bar sederhana untuk proses background
show_progress() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\\'
    tput civis 2>/dev/null
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%$temp}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    tput cnorm 2>/dev/null
    printf "    \b\b\b\b"
} 