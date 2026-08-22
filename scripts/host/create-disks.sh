#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
if [[ -f "${ROOT}/config.env" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT}/config.env"
fi

DISK_POOL="${DISK_POOL:-/var/lib/libvirt/images/ad-kvm-lab}"
ensure_libvirt_pool "$DISK_POOL"

create() {
  local name="$1" size="$2"
  local path="${DISK_POOL}/${name}.qcow2"
  if [[ -e "$path" ]]; then
    echo "exists: $path"
    return
  fi
  if [[ -w "$DISK_POOL" ]]; then
    qemu-img create -f qcow2 -o preallocation=off "$path" "$size"
  else
    require_sudo_or_root "$DISK_POOL"
    run_priv qemu-img create -f qcow2 -o preallocation=off "$path" "$size"
    run_priv chown "${USER}:kvm" "$path"
  fi
  echo "created: $path"
}

create dc-corp 60G
create dc-corp2 60G
create dc-partner 60G
create srv-corp 60G
create ca-corp 60G
create win10-corp 60G
create kali-ad 40G
