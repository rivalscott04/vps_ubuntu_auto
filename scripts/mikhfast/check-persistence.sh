#!/usr/bin/env bash
#
# Diagnose why MIKFAST data disappears after VPS restart.
# Usage: sudo bash scripts/check-persistence.sh [/var/www/mikhfast]
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
  fail() { echo -e "${RED}[ISSUE]${NC} $*"; }
  info() { echo "$*"; }
fi

APP="${1:-${MIKFAST_APP:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
APP="$(cd "$APP" && pwd)"

TOTAL_CHECKS=6
check_step() {
  local current="$1"
  local label="$2"
  info "[${current}/${TOTAL_CHECKS}] ${label}"
}

info "MIKFAST persistence check"
info "App: $APP"
echo ""

check_step 1 "Cek git tracking config.php"
if [[ -d "$APP/.git" ]]; then
  if git -C "$APP" ls-files --error-unmatch include/config.php &>/dev/null; then
    fail "include/config.php masih di-track git → git pull/reset bisa timpa data router!"
    info "Fix: sudo bash scripts/install-mikhfast.sh --update"
  else
    ok "include/config.php tidak di-track git (aman dari git pull)"
  fi
else
  warn "Bukan git repo — skip cek git tracking"
fi

check_step 2 "Cek filesystem ephemeral (tmpfs)"
if mount | grep -q " on ${APP} .*tmpfs"; then
  fail "App path di tmpfs — data hilang saat reboot!"
elif df -h "$APP" | grep -q tmpfs; then
  fail "Filesystem tmpfs — data tidak persisten!"
else
  ok "App tidak di tmpfs"
fi

check_step 3 "Cek Docker volume bind mount"
if command -v docker &>/dev/null; then
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qE 'nginx|php'; then
    warn "Docker container aktif — pastikan volume bind ke host:"
    info "  docker inspect nginx php_7_4 2>/dev/null | grep -A5 Mounts"
    if docker inspect nginx 2>/dev/null | grep -q "\"Source\": \"${APP}\""; then
      ok "nginx bind mount ke $APP"
    else
      fail "nginx mungkin TIDAK bind mount ke folder host — restart container = data hilang"
    fi
  else
    ok "Tidak ada container nginx/php aktif"
  fi
else
  ok "Docker tidak terinstall — skip cek container"
fi

check_step 4 "Cek state include/config.php"
if [[ ! -f "$APP/include/config.php" ]]; then
  fail "include/config.php tidak ada"
elif [[ ! -s "$APP/include/config.php" ]]; then
  fail "include/config.php kosong"
else
  routers=$(grep -c "\$data\['" "$APP/include/config.php" 2>/dev/null || echo 0)
  ok "include/config.php ada ($routers baris \$data)"
fi

if [[ -f "$APP/include/config.php.bak" ]]; then
  ok "Backup config.php.bak ada (auto backup sebelum write)"
fi

check_step 5 "Cek kelengkapan file inti include/"
missing=0
for f in include/ajax.php include/readcfg.php include/config-write.php; do
  if [[ ! -f "$APP/$f" ]]; then
    fail "Missing: $f"
    missing=1
  fi
done
[[ "$missing" -eq 0 ]] && ok "File inti include/ lengkap"

check_step 6 "Cek auto-deploy saat boot"
for f in /etc/rc.local /etc/cloud/cloud.cfg; do
  if [[ -f "$f" ]] && grep -qiE 'git (pull|reset|checkout)|rsync.*--delete' "$f" 2>/dev/null; then
    warn "Mungkin ada auto-deploy di $f yang reset file saat boot"
  fi
done

if [[ -d /etc/systemd/system ]]; then
  grep -rlE 'git (pull|reset|checkout)|rsync.*--delete' /etc/systemd/system 2>/dev/null | while read -r unit; do
    warn "Systemd unit auto-deploy: $unit"
  done
fi

echo ""
info "=== Kesimpulan ==="
info "- Restart VPS TIDAK seharusnya hapus file di disk normal."
info "- Data hilang biasanya karena: git reset/pull, Docker tanpa volume, tmpfs, atau deploy script saat boot."
info "- Semua data router disimpan di include/config.php — backup file ini secara rutin!"
