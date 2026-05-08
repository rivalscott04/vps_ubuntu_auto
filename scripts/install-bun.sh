#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[bun-install] %s\n' "$*" >&2; }
warn() { printf '[bun-install][warn] %s\n' "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    warn "Missing command: $1"
    return 1
  }
}

ensure_prereqs() {
  if ! require_cmd curl; then
    log "Installing curl..."
    sudo apt-get update -y
    sudo apt-get install -y curl ca-certificates
  fi
  if ! command -v unzip >/dev/null 2>&1; then
    log "Installing unzip (needed for fallback zip installs)..."
    sudo apt-get update -y
    sudo apt-get install -y unzip
  fi
}

FIREWALL_WAS_ACTIVE=""
FIREWALL_KIND=""

firewall_pause_if_needed() {
  # Some VPS images have strict egress filtering via firewall tooling.
  # Temporarily disable if active; we will restore it in the EXIT trap.

  if command -v ufw >/dev/null 2>&1; then
    if sudo ufw status 2>/dev/null | grep -qi "Status: active"; then
      FIREWALL_WAS_ACTIVE="1"
      FIREWALL_KIND="ufw"
      warn "UFW aktif. Disable sementara untuk install bun..."
      sudo ufw disable >/dev/null 2>&1 || true
      return 0
    fi
  fi

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet firewalld 2>/dev/null; then
      FIREWALL_WAS_ACTIVE="1"
      FIREWALL_KIND="firewalld"
      warn "firewalld aktif. Stop sementara untuk install bun..."
      sudo systemctl stop firewalld >/dev/null 2>&1 || true
      return 0
    fi
  fi
}

firewall_resume_if_needed() {
  if [[ "${FIREWALL_WAS_ACTIVE}" != "1" ]]; then
    return 0
  fi

  case "${FIREWALL_KIND}" in
    ufw)
      warn "Mengaktifkan kembali UFW..."
      sudo ufw --force enable >/dev/null 2>&1 || true
      ;;
    firewalld)
      warn "Menjalankan kembali firewalld..."
      sudo systemctl start firewalld >/dev/null 2>&1 || true
      ;;
  esac
}

add_bun_to_path_hint() {
  # Bun installer puts bun in ~/.bun/bin/bun
  local bun_bin="${HOME}/.bun/bin"
  if [[ ":${PATH}:" != *":${bun_bin}:"* ]]; then
    warn "PATH belum include ${bun_bin}"
    warn "Biar permanen, tambahin ke shell profile kamu, contoh (bash):"
    warn "  echo 'export BUN_INSTALL=\"$HOME/.bun\"' >> ~/.bashrc"
    warn "  echo 'export PATH=\"$BUN_INSTALL/bin:$PATH\"' >> ~/.bashrc"
    warn "Terus reload: source ~/.bashrc (atau ~/.zshrc)"
  fi
}

install_via_bun_com() {
  log "Trying official installer (bun.com)..."

  # Prefer strict TLS and retries. If IPv6 broken, fallback to IPv4 variant below.
  if curl --connect-timeout 10 --max-time 300 --retry 5 --retry-delay 1 -fsSL https://bun.com/install | bash; then
    return 0
  fi

  warn "bun.com installer failed, retrying with IPv4 forced..."
  curl -4 --connect-timeout 10 --max-time 300 --retry 5 --retry-delay 1 -fsSL https://bun.com/install | bash
}

verify() {
  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"

  if command -v bun >/dev/null 2>&1; then
    log "bun installed. Version:"
    bun --version
    return 0
  fi

  add_bun_to_path_hint
  return 1
}

main() {
  ensure_prereqs
  trap firewall_resume_if_needed EXIT
  firewall_pause_if_needed

  if install_via_bun_com; then
    if verify; then
      exit 0
    fi
  fi

warn "Primary install failed. Running fallback installer..."
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  bash "${SCRIPT_DIR}/install-bun-fallback.sh"
}

main "$@"
