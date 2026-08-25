#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
URI="${LIBVIRT_URI:-qemu:///system}"

define_net() {
  local name="$1" xml="$2" desc="$3"
  if virsh -c "$URI" net-info "$name" >/dev/null 2>&1; then
    echo "libvirt network $name already exists"
    virsh -c "$URI" net-info "$name"
    return 0
  fi
  virsh -c "$URI" net-define "$xml"
  virsh -c "$URI" net-autostart "$name"
  virsh -c "$URI" net-start "$name"
  virsh -c "$URI" net-info "$name"
  echo "Defined $desc"
}

define_net ad-lab "${ROOT}/network/ad-lab.xml" \
  "NAT network ad-lab (192.168.57.0/24)"
define_net ad-lab-foothold "${ROOT}/network/ad-lab-foothold.xml" \
  "isolated network ad-lab-foothold (192.168.58.0/24, no NAT)"
