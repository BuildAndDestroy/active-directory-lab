# Sourced by host scripts that touch /var/lib/libvirt/images.
# shellcheck shell=bash

is_root() {
  [[ "$(id -u)" -eq 0 ]]
}

is_system_libvirt_pool() {
  local pool="${1:-}"
  [[ "$pool" == /var/lib/libvirt/images ]] || [[ "$pool" == /var/lib/libvirt/images/* ]]
}

have_sudo() {
  command -v sudo >/dev/null 2>&1 || return 1
  if sudo -n true >/dev/null 2>&1; then
    return 0
  fi
  # Interactive sudo needs a TTY
  [[ -t 0 && -t 2 ]]
}

require_sudo_or_root() {
  local what="${1:-/var/lib/libvirt/images}"
  if is_root; then
    return 0
  fi
  if have_sudo; then
    if sudo -n true >/dev/null 2>&1; then
      return 0
    fi
    echo "sudo required for ${what}. Enter your password if prompted."
    sudo -v
    return 0
  fi
  echo "error: ${what} requires root or sudo. Re-run as root, or in a terminal with sudo." >&2
  exit 1
}

run_priv() {
  if is_root; then
    "$@"
  else
    sudo "$@"
  fi
}

ensure_libvirt_pool() {
  local pool="${1:?pool path required}"

  if ! is_system_libvirt_pool "$pool"; then
    mkdir -p "$pool"
    return 0
  fi

  if [[ -d "$pool" && -w "$pool" ]]; then
    return 0
  fi

  require_sudo_or_root "$pool"

  local owner="${SUDO_USER:-$USER}"
  run_priv mkdir -p "$pool"
  run_priv chown "${owner}:kvm" "$pool"
  run_priv chmod 775 "$pool"

  if [[ ! -w "$pool" ]]; then
    echo "error: ${pool} is still not writable for ${owner}." >&2
    echo "  run_priv: sudo chown ${owner}:kvm ${pool} && sudo chmod 775 ${pool}" >&2
    exit 1
  fi
}
