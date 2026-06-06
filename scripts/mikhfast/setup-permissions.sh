#!/usr/bin/env bash
#
# MIKFAST — setup file & folder permissions on the server.
# Usage:
#   sudo bash scripts/setup-permissions.sh
#   sudo MIKFAST_WEB_USER=www-data bash scripts/setup-permissions.sh /var/www/mikhfast
#
set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_VPS_UTILS="${_SCRIPT_DIR}/../../utils.sh"
if [[ -f "$_VPS_UTILS" ]]; then
  # shellcheck source=../../utils.sh
  source "$_VPS_UTILS"
  ok()   { log_info "$*"; }
  warn() { log_warning "$*"; }
  fail() { log_error "$*"; }
  info() { log_info "$*"; }
else
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  NC='\033[0m'
  ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
  warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
  fail() { echo -e "${RED}[GAGAL]${NC} $*"; }
  info() { echo "$*"; }
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="${1:-${MIKFAST_APP:-$(dirname "$SCRIPT_DIR")}}"
WEB_USER="${MIKFAST_WEB_USER:-}"

detect_web_user() {
  if [[ -n "$WEB_USER" ]]; then
    echo "$WEB_USER"
    return
  fi
  if id www-data &>/dev/null; then
    echo www-data
    return
  fi
  if id nginx &>/dev/null; then
    echo nginx
    return
  fi
  if id apache &>/dev/null; then
    echo apache
    return
  fi
  local fpm_user
  fpm_user="$(ps aux 2>/dev/null | grep 'php-fpm: pool' | grep -v grep | awk '{print $1}' | head -1 || true)"
  if [[ -n "$fpm_user" && "$fpm_user" != root ]]; then
    echo "$fpm_user"
    return
  fi
  echo www-data
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    fail "Jalankan sebagai root: sudo $0 [path-app]"
    exit 1
  fi
}

ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    ok "Folder dibuat: $dir"
  fi
}

ensure_config_php() {
  local cfg="$APP/include/config.php"
  local example="$APP/include/config.php.example"
  if [[ ! -f "$cfg" ]] || [[ ! -s "$cfg" ]]; then
    if [[ -f "$example" ]]; then
      cp "$example" "$cfg"
    else
      cat > "$cfg" <<'EOF'
<?php 
if(substr($_SERVER["REQUEST_URI"], -10) == "config.php"){header("Location:./");}; 
$data['mikhmon'] = array ('1'=>'mikhmon<|<mikhmon','mikhmon>|>aWNlbA==','qrbt<|<disable');
EOF
    fi
    warn "include/config.php dibuat ulang (default). Tambah router lewat Admin Settings."
  fi
}

ensure_file() {
  local file="$1"
  local content="${2:-}"
  if [[ ! -f "$file" ]]; then
    if [[ -n "$content" ]]; then
      printf '%s\n' "$content" > "$file"
    else
      : > "$file"
    fi
    ok "File dibuat: $file"
  fi
}

check_deploy_files() {
  local missing=0
  local f

  for f in admin.php index.php include/ajax.php include/readcfg.php img/mikfast.svg; do
    if [[ ! -f "$APP/$f" ]]; then
      fail "Tidak ada: $f — git pull / upload repo dulu!"
      missing=1
    fi
  done

  if [[ ! -f "$APP/img/favicon.png" ]]; then
    warn "img/favicon.png tidak ada (favicon browser bisa broken)"
  fi

  return "$missing"
}

apply_permissions() {
  local web="$1"

  chown -R "$web:$web" "$APP/include" "$APP/img" "$APP/voucher"

  chmod 755 "$APP/include"
  chmod 775 "$APP/img" "$APP/voucher"

  chmod 664 "$APP/include/config.php"
  chmod 664 "$APP/include/lang.php" 2>/dev/null || true
  chmod 664 "$APP/include/theme.php" 2>/dev/null || true
  chmod 664 "$APP/include/quickbt.php"

  while IFS= read -r -d '' php; do
    base="$(basename "$php")"
    case "$base" in
      config.php|quickbt.php|lang.php|theme.php) ;;
      *) chmod 644 "$php" ;;
    esac
  done < <(find "$APP/include" -maxdepth 1 -name '*.php' -print0)

  chmod 664 "$APP/voucher/temp.php"
  while IFS= read -r -d '' tpl; do
    chmod 664 "$tpl"
  done < <(find "$APP/voucher" -maxdepth 1 -name 'template*.php' -print0 2>/dev/null)

  chmod 644 "$APP/img/mikfast.svg" 2>/dev/null || true
  chmod 644 "$APP/img/favicon.png" 2>/dev/null || true
  while IFS= read -r -d '' logo; do
    chmod 664 "$logo"
  done < <(find "$APP/img" -maxdepth 1 -name 'logo-*.png' -print0 2>/dev/null)

  ok "Permission diterapkan (owner: $web)"
}

verify_as_web_user() {
  local web="$1"
  local pass=0
  local fail_count=0

  info "=== Verifikasi (sebagai $web) ==="

  run_check() {
    local label="$1"
    shift
    if sudo -u "$web" "$@" 2>/dev/null; then
      ok "$label"
      pass=$((pass + 1))
    else
      fail "$label"
      fail_count=$((fail_count + 1))
    fi
  }

  run_check "include/config.php readable"  test -r "$APP/include/config.php"
  run_check "include/config.php writable"  test -w "$APP/include/config.php"
  run_check "include/quickbt.php writable" test -w "$APP/include/quickbt.php"
  run_check "voucher/temp.php writable"    test -w "$APP/voucher/temp.php"
  run_check "img/ writable"                test -w "$APP/img"
  run_check "img/mikfast.svg readable"     test -r "$APP/img/mikfast.svg"

  info "Hasil verifikasi: $pass OK, $fail_count GAGAL"
  [[ "$fail_count" -eq 0 ]]
}

main() {
  require_root

  APP="$(cd "$APP" && pwd)"
  WEB_USER="$(detect_web_user)"

  info "MIKFAST setup-permissions"
  info "App path : $APP"
  info "Web user : $WEB_USER"
  echo ""

  info "[1/4] Siapkan folder dan file inti"
  ensure_dir "$APP/include"
  ensure_dir "$APP/img"
  ensure_dir "$APP/voucher"

  ensure_config_php
  ensure_file "$APP/include/quickbt.php" '<?php $qrbt="disable";?>'
  ensure_file "$APP/voucher/temp.php" '<?php // generated by MIKFAST ?>'

  if ! check_deploy_files; then
    warn "Deploy belum lengkap. Permission tetap diterapkan untuk file yang ada."
  fi

  info "[2/4] Terapkan owner dan chmod"
  apply_permissions "$WEB_USER"

  info "[3/4] Verifikasi akses sebagai web user"
  if verify_as_web_user "$WEB_USER"; then
    info "[4/4] Finalisasi"
    ok "Selesai. Buka admin.php?id=login lalu Add Router jika config masih default."
    exit 0
  fi

  info "[4/4] Finalisasi"
  fail "Ada cek yang gagal. Periksa owner/chmod atau lengkapi file dari repo."
  exit 1
}

main "$@"
