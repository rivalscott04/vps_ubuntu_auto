#!/usr/bin/env bash
#
# MIKFAST — one-shot installer
#
# Fresh install (clone + setup):
#   sudo MIKFAST_DIR=/var/www/mikhfast bash scripts/install-mikhfast.sh
#
# From GitHub directly:
#   curl -fsSL https://raw.githubusercontent.com/rivalscott04/mikhfast/master/scripts/install-mikhfast.sh | sudo bash
#
# Update existing install (pull + protect config + permissions):
#   cd /var/www/mikhfast && sudo bash scripts/install-mikhfast.sh --update
#
set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_VPS_UTILS="${_SCRIPT_DIR}/../utils.sh"
if [[ -f "$_VPS_UTILS" ]]; then
  # shellcheck source=../utils.sh
  source "$_VPS_UTILS"
  ok()   { log_info "$*"; }
  warn() { log_warning "$*"; }
  fail() { log_error "$*"; }
  info() { log_info "$*"; }
else
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  NC='\033[0m'
  ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
  warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
  fail() { echo -e "${RED}[GAGAL]${NC} $*"; }
  info() { echo -e "${CYAN}==>${NC} $*"; }
fi

TOTAL_STEPS=6
step_msg() {
  local current="$1"
  local label="$2"
  info "[${current}/${TOTAL_STEPS}] ${label}"
}

mikhfast_helper_script() {
  local name="$1"
  local bundled="${_SCRIPT_DIR}/mikhfast/${name}"
  local deployed="${INSTALL_DIR}/scripts/${name}"

  if [[ -f "$bundled" ]]; then
    mkdir -p "${INSTALL_DIR}/scripts"
    cp "$bundled" "$deployed"
    chmod +x "$deployed"
    echo "$deployed"
    return 0
  fi

  if [[ -f "$deployed" ]]; then
    echo "$deployed"
    return 0
  fi

  return 1
}

REPO_URL="${MIKFAST_REPO:-https://github.com/rivalscott04/mikhfast.git}"
BRANCH="${MIKFAST_BRANCH:-master}"
INSTALL_DIR="${MIKFAST_DIR:-/var/www/mikhfast}"
DO_UPDATE=0
SKIP_PULL=0

usage() {
  cat <<EOF
Usage: sudo bash scripts/install-mikhfast.sh [options]

Options:
  --dir PATH       Install path (default: /var/www/mikhfast)
  --repo URL       Git repo URL
  --branch NAME    Git branch (default: master)
  --update         Git pull + re-apply permissions (config tidak ditimpa)
  --skip-pull      Skip git clone/pull (hanya setup config + permission)
  -h, --help       Show help

Environment:
  MIKFAST_DIR, MIKFAST_REPO, MIKFAST_BRANCH, MIKFAST_WEB_USER

After install, buka Admin UI:
  http://SERVER-IP/admin.php?id=login
  Login default: mikhmon / 1234
  Lalu Add Router dari Admin Settings.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    --repo) REPO_URL="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --update) DO_UPDATE=1; shift ;;
    --skip-pull) SKIP_PULL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1"; usage; exit 1 ;;
  esac
done

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    fail "Jalankan sebagai root: sudo bash $0"
    exit 1
  fi
}

require_git() {
  if ! command -v git &>/dev/null; then
    fail "git belum terinstall. Jalankan: apt install -y git"
    exit 1
  fi
}

script_app_root() {
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  if [[ -f "$dir/admin.php" && -f "$dir/index.php" ]]; then
    echo "$dir"
    return 0
  fi
  return 1
}

clone_or_update_repo() {
  local backup=""
  if [[ -f "$INSTALL_DIR/include/config.php" ]]; then
    backup="$(mktemp)"
    cp "$INSTALL_DIR/include/config.php" "$backup"
    ok "Backup config.php sementara: $backup"
  fi

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "Update repo di $INSTALL_DIR ..."
    git -C "$INSTALL_DIR" fetch origin "$BRANCH"
    git -C "$INSTALL_DIR" checkout "$BRANCH"
    git -C "$INSTALL_DIR" pull origin "$BRANCH" --ff-only || {
      warn "git pull --ff-only gagal — coba manual: cd $INSTALL_DIR && git pull"
    }
  elif [[ -d "$INSTALL_DIR" && -n "$(ls -A "$INSTALL_DIR" 2>/dev/null || true)" ]]; then
    fail "Folder $INSTALL_DIR sudah ada tapi bukan git repo."
    echo "       Pindahkan dulu atau pakai --dir path lain."
    exit 1
  else
    info "Clone $REPO_URL → $INSTALL_DIR ..."
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR"
  fi

  if [[ -n "$backup" && -f "$backup" ]]; then
    cp "$backup" "$INSTALL_DIR/include/config.php"
    rm -f "$backup"
    ok "config.php live dipulihkan (tidak ditimpa git pull)"
  fi
}

untrack_live_files() {
  local app="$1"
  cd "$app"

  if [[ ! -d .git ]]; then
    warn "Bukan git repo — skip git rm --cached"
    return 0
  fi

  local untracked=0
  for f in include/config.php include/config.php.bak include/quickbt.php; do
    if git ls-files --error-unmatch "$f" &>/dev/null; then
      git rm --cached -f "$f" >/dev/null 2>&1 || true
      untracked=1
      ok "Stop tracking git: $f"
    fi
  done

  if [[ "$untracked" -eq 1 ]]; then
    warn "Jalankan 'git commit' di server opsional — yang penting config tidak ke-overwrite pull."
  else
    ok "File live sudah tidak di-track git"
  fi
}

init_live_config() {
  local app="$1"
  local cfg="$app/include/config.php"
  local example="$app/include/config.php.example"

  if [[ -f "$cfg" && -s "$cfg" ]]; then
    ok "include/config.php sudah ada — tidak ditimpa"
    return 0
  fi

  if [[ -f "$example" ]]; then
    cp "$example" "$cfg"
    ok "include/config.php dibuat dari config.php.example"
  else
    cat > "$cfg" <<'EOF'
<?php 
if(substr($_SERVER["REQUEST_URI"], -10) == "config.php"){header("Location:./");}; 
$data['mikhmon'] = array ('1'=>'mikhmon<|<mikhmon','mikhmon>|>aWNlbA==','qrbt<|<disable');
EOF
    ok "include/config.php dibuat (default)"
  fi
}

print_nginx_hint() {
  local app="$1"
  cat <<EOF

${CYAN}--- Nginx (native PHP-FPM) ---${NC}
Buat site config, contoh:

  root $app;
  index index.php;
  location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php8.3-fpm.sock;
  }
  location / {
    try_files \$uri \$uri/ /index.php?\$query_string;
  }

Reload: nginx -t && systemctl reload nginx

${CYAN}--- Docker ---${NC}
  cd $app && docker compose up -d
  Akses: http://SERVER-IP:8080/admin.php?id=login
EOF
}

print_done() {
  local app="$1"
  local server_ip
  server_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  server_ip="${server_ip:-SERVER-ANDA}"

  echo ""
  info "=== MIKFAST SELESAI ==="
  info "Path instalasi : $app"
  info "Login          : http://${server_ip}/admin.php?id=login"
  info "User default   : mikhmon"
  info "Pass default   : 1234"
  echo ""
  info "Langkah berikutnya (lewat UI):"
  info "  1. Login"
  info "  2. Admin Settings → Add Router"
  info "  3. Isi IP, user, password MikroTik → Save"
  print_nginx_hint "$app"
}

main() {
  require_root
  require_git

  local app=""
  if app="$(script_app_root)"; then
    INSTALL_DIR="$app"
    info "Jalankan dari dalam repo MIKFAST: $INSTALL_DIR"
  fi

  INSTALL_DIR="$(mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && pwd)"

  echo ""
  info "MIKFAST Installer"
  info "Target : $INSTALL_DIR"
  info "Repo   : $REPO_URL ($BRANCH)"
  echo ""

  step_msg 1 "Validasi environment (root, git, path target)"

  if [[ "$SKIP_PULL" -eq 0 ]]; then
    step_msg 2 "Clone atau update repository"
    if [[ "$DO_UPDATE" -eq 1 ]] || [[ -d "$INSTALL_DIR/.git" ]]; then
      clone_or_update_repo
    elif [[ ! -f "$INSTALL_DIR/admin.php" ]]; then
      clone_or_update_repo
    else
      warn "Folder sudah berisi app tanpa .git — skip clone (pakai --update atau --skip-pull)"
    fi
  else
    step_msg 2 "Skip clone/pull (--skip-pull)"
    info "Menggunakan instalasi yang sudah ada di $INSTALL_DIR"
  fi

  if [[ ! -f "$INSTALL_DIR/admin.php" ]]; then
    fail "Install gagal — admin.php tidak ditemukan di $INSTALL_DIR"
    exit 1
  fi
  ok "Aplikasi MIKFAST ditemukan di $INSTALL_DIR"

  step_msg 3 "Inisialisasi config.php (tidak menimpa config live)"
  init_live_config "$INSTALL_DIR"

  step_msg 4 "Stop tracking file live di git"
  untrack_live_files "$INSTALL_DIR"

  step_msg 5 "Setup permission (owner, chmod, web user)"
  local perm_script
  if perm_script="$(mikhfast_helper_script setup-permissions.sh)"; then
    info "Menjalankan: $perm_script"
    bash "$perm_script" "$INSTALL_DIR"
    ok "Setup permission selesai"
  else
    fail "Script setup-permissions.sh tidak ditemukan (bundled maupun di $INSTALL_DIR/scripts/)"
    exit 1
  fi

  step_msg 6 "Cek persistence config setelah update"
  local persist_script
  if persist_script="$(mikhfast_helper_script check-persistence.sh)"; then
    info "Menjalankan: $persist_script"
    if bash "$persist_script" "$INSTALL_DIR"; then
      ok "Cek persistence: OK"
    else
      warn "Cek persistence: ada peringatan (lihat log di atas)"
    fi
  else
    warn "Script check-persistence.sh tidak ditemukan — dilewati"
  fi

  print_done "$INSTALL_DIR"
}

main "$@"
