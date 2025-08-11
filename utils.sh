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

# Helper untuk handle APT lock
safe_apt_update() {
    echo -e "\e[1;36m[INFO]\e[0m Akan menjalankan: apt-get update"
    while true; do
        apt-get update 2>&1 | tee /tmp/aptlog
        if grep -q "Could not get lock" /tmp/aptlog; then
            pid=$(grep -oP 'held by process \\K[0-9]+' /tmp/aptlog | head -n1)
            pname=$(ps -p $pid -o comm=)
            echo -e "\e[1;33m[LOCK]\e[0m Lock APT sedang dipegang oleh proses: $pname (PID: $pid)"
            echo "1. Tunggu dan coba lagi"
            echo "2. Matikan proses $pid"
            echo "3. Batal"
            read -p "Pilih [1-3]: " opt
            case $opt in
                1) sleep 5;;
                2) kill -9 $pid; echo "Proses $pid dimatikan. Ulangi perintah apt...";;
                3) return 1;;
                *) echo "Pilihan tidak valid, ulangi.";;
            esac
        elif grep -q "E: " /tmp/aptlog; then
            echo -e "\e[1;31m[ERROR]\e[0m apt-get update gagal:"
            grep "E: " /tmp/aptlog
            return 1
        else
            echo -e "\e[1;32m[SUKSES]\e[0m apt-get update selesai."
            break
        fi
    done
}

safe_apt_upgrade() {
    echo -e "\e[1;36m[INFO]\e[0m Akan menjalankan: apt-get upgrade -y"
    while true; do
        apt-get upgrade -y 2>&1 | tee /tmp/aptlog
        if grep -q "Could not get lock" /tmp/aptlog; then
            pid=$(grep -oP 'held by process \\K[0-9]+' /tmp/aptlog | head -n1)
            pname=$(ps -p $pid -o comm=)
            echo -e "\e[1;33m[LOCK]\e[0m Lock APT sedang dipegang oleh proses: $pname (PID: $pid)"
            echo "1. Tunggu dan coba lagi"
            echo "2. Matikan proses $pid"
            echo "3. Batal"
            read -p "Pilih [1-3]: " opt
            case $opt in
                1) sleep 5;;
                2) kill -9 $pid; echo "Proses $pid dimatikan. Ulangi perintah apt...";;
                3) return 1;;
                *) echo "Pilihan tidak valid, ulangi.";;
            esac
        elif grep -q "E: " /tmp/aptlog; then
            echo -e "\e[1;31m[ERROR]\e[0m apt-get upgrade gagal:"
            grep "E: " /tmp/aptlog
            return 1
        else
            echo -e "\e[1;32m[SUKSES]\e[0m apt-get upgrade selesai."
            break
        fi
    done
}

safe_apt_install() {
    # $@ = paket yang ingin diinstall
    echo -e "\e[1;36m[INFO]\e[0m Akan menginstall: $*"
    while true; do
        apt-get install -y "$@" 2>&1 | tee /tmp/aptlog
        if grep -q "Could not get lock" /tmp/aptlog; then
            pid=$(grep -oP 'held by process \\K[0-9]+' /tmp/aptlog | head -n1)
            pname=$(ps -p $pid -o comm=)
            echo -e "\e[1;33m[LOCK]\e[0m Lock APT sedang dipegang oleh proses: $pname (PID: $pid)"
            echo "1. Tunggu dan coba lagi"
            echo "2. Matikan proses $pid"
            echo "3. Batal"
            read -p "Pilih [1-3]: " opt
            case $opt in
                1) sleep 5;;
                2) kill -9 $pid; echo "Proses $pid dimatikan. Ulangi perintah apt...";;
                3) return 1;;
                *) echo "Pilihan tidak valid, ulangi.";;
            esac
        elif grep -q "E: " /tmp/aptlog; then
            echo -e "\e[1;31m[ERROR]\e[0m apt-get install gagal:"
            grep "E: " /tmp/aptlog
            return 1
        else
            echo -e "\e[1;32m[SUKSES]\e[0m Berhasil menginstall: $*"
            break
        fi
    done
} 