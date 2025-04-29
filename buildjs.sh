#!/bin/bash

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fungsi untuk logging
log_error() {
    echo -e "${RED}ERROR: $1${NC}" | tee -a build-error.log
}

log_info() {
    echo -e "${GREEN}INFO: $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}WARN: $1${NC}"
}

# Fungsi untuk memvalidasi path
validate_path() {
    if [ ! -d "$1" ]; then
        log_error "Directory '$1' tidak ditemukan."
        return 1
    fi
    
    if [ ! -f "$1/package.json" ]; then
        log_error "package.json tidak ditemukan di '$1'"
        return 1
    fi
    
    return 0
}

# Fungsi untuk menampilkan system info
show_system_info() {
    log_info "System Information:"
    echo "Node Version: $(node -v)"
    echo "NPM Version: $(npm -v)"
    echo "Memory Info:"
    free -h
    echo "Disk Space:"
    df -h .
    echo "------------------------"
}

# Fungsi untuk build
do_build() {
    local build_path=$1
    local log_file="build-$(date +%Y%m%d_%H%M%S).log"
    
    log_info "Memulai proses build di: $build_path"
    log_info "Log akan disimpan di: $log_file"
    
    # Pindah ke directory project
    cd "$build_path" || exit 1

    # Simpan versi Node dan NPM ke log
    show_system_info >> "$log_file" 2>&1

    log_info "Membersihkan cache..."
    rm -rf dist node_modules/.vite
    npm cache clean --force >> "$log_file" 2>&1

    log_info "Menyiapkan swap memory..."
    if sudo dd if=/dev/zero of=/swapfile bs=1M count=1024 >> "$log_file" 2>&1; then
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile >> "$log_file" 2>&1
        sudo swapon /swapfile >> "$log_file" 2>&1
        
        log_info "Menginstall dependencies..."
        if npm install >> "$log_file" 2>&1; then
            log_info "Memulai proses build..."
            if NODE_ENV=production NODE_OPTIONS='--max-old-space-size=512' npm run build >> "$log_file" 2>&1; then
                log_info "Build berhasil! ?"
            else
                log_error "Build gagal! Cek error log di $log_file"
                log_error "Last 10 lines of error:"
                tail -n 10 "$log_file"
            fi
        else
            log_error "Instalasi dependencies gagal! Cek error log di $log_file"
            log_error "Last 10 lines of error:"
            tail -n 10 "$log_file"
        fi

        log_info "Membersihkan swap..."
        sudo swapoff /swapfile
        sudo rm /swapfile
    else
        log_warn "Gagal membuat swap file, melanjutkan tanpa swap..."
        if npm install >> "$log_file" 2>&1 && \
           NODE_ENV=production NODE_OPTIONS='--max-old-space-size=512' npm run build >> "$log_file" 2>&1; then
            log_info "Build berhasil! ?"
        else
            log_error "Build gagal! Cek error log di $log_file"
            log_error "Last 10 lines of error:"
            tail -n 10 "$log_file"
        fi
    fi

    # Tampilkan ukuran node_modules dan dist
    log_info "Directory sizes:"
    du -sh node_modules dist 2>/dev/null || true
}

# Tampilkan banner
echo "=================================="
echo "   React Project Builder Script   "
echo "=================================="
echo

# Cek apakah ada argument path
if [ $# -eq 1 ]; then
    BUILD_PATH=$1
else
    read -p "?? Masukkan path ke project React: " BUILD_PATH
fi

# Validasi path
if validate_path "$BUILD_PATH"; then
    read -p "?? Lanjutkan build di '$BUILD_PATH'? (y/n): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        do_build "$BUILD_PATH"
    else
        log_warn "Build dibatalkan."
        exit 0
    fi
else
    exit 1
fi