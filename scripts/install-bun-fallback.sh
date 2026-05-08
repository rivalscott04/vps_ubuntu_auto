#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[bun-fallback] %s\n' "$*" >&2; }
warn() { printf '[bun-fallback][warn] %s\n' "$*" >&2; }

ensure_prereqs() {
  if ! command -v curl >/dev/null 2>&1; then
    log "Installing curl..."
    sudo apt-get update -y
    sudo apt-get install -y curl ca-certificates
  fi
  if ! command -v unzip >/dev/null 2>&1; then
    log "Installing unzip..."
    sudo apt-get update -y
    sudo apt-get install -y unzip
  fi
}

arch_to_asset() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) echo "bun-linux-x64.zip" ;;
    aarch64|arm64) echo "bun-linux-aarch64.zip" ;;
    *)
      warn "Unsupported arch: ${arch}"
      return 1
      ;;
  esac
}

download_with_mirrors() {
  local url_path="$1" out="$2"

  # Try multiple mirrors; some networks block github.com but allow proxies.
  local -a bases=(
    "https://github.com"
    "https://ghproxy.com/https://github.com"
    "https://mirror.ghproxy.com/https://github.com"
    "https://download.fastgit.org"
  )

  local base url
  for base in "${bases[@]}"; do
    # If base already includes https://github.com in it (proxy), don't double it.
    if [[ "$base" == "https://github.com" ]]; then
      url="${base}${url_path}"
    else
      url="${base}${url_path}"
    fi

    log "Downloading: ${url}"
    if curl -fL --retry 5 --retry-delay 1 -o "$out" "$url"; then
      return 0
    fi
  done

  return 1
}

install_latest_release_zip() {
  local asset tmpzip tmpdir bun_install
  asset="$(arch_to_asset)"

  tmpzip="$(mktemp -t bun.zip.XXXXXX)"
  tmpdir="$(mktemp -d -t bun.unzip.XXXXXX)"

  # "latest" redirect path (no API).
  local path="/oven-sh/bun/releases/latest/download/${asset}"

  if ! download_with_mirrors "$path" "$tmpzip"; then
    warn "All mirrors failed for ${asset}"
    return 1
  fi

  unzip -q "$tmpzip" -d "$tmpdir"

  # Zip contains bun binary nested like: bun-linux-x64/bun
  local bun_path
  bun_path="$(find "$tmpdir" -type f -name bun -perm -111 2>/dev/null | head -n 1 || true)"
  if [[ -z "${bun_path}" ]]; then
    warn "Could not find bun binary inside zip"
    return 1
  fi

  bun_install="${HOME}/.bun"
  mkdir -p "${bun_install}/bin"
  install -m 0755 "$bun_path" "${bun_install}/bin/bun"

  rm -f "$tmpzip"
  rm -rf "$tmpdir"

  export BUN_INSTALL="${bun_install}"
  export PATH="${BUN_INSTALL}/bin:${PATH}"

  return 0
}

verify() {
  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"

  if command -v bun >/dev/null 2>&1; then
    log "bun installed. Version:"
    bun --version
    return 0
  fi
  return 1
}

main() {
  ensure_prereqs

  if install_latest_release_zip; then
    if verify; then
      exit 0
    fi
  fi

warn "Fallback install failed."
warn "Coba cek koneksi kamu (DNS/proxy/firewall) atau share error output curl biar aku benerin urutan mirror-nya."
exit 1
}

main "$@"
