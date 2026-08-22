#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
XML="${ROOT}/network/ad-lab.xml"
URI="${LIBVIRT_URI:-qemu:///system}"

if virsh -c "$URI" net-info ad-lab >/dev/null 2>&1; then
  echo "libvirt network ad-lab already exists"
  virsh -c "$URI" net-info ad-lab
  exit 0
fi

virsh -c "$URI" net-define "$XML"
virsh -c "$URI" net-autostart ad-lab
virsh -c "$URI" net-start ad-lab
virsh -c "$URI" net-info ad-lab
echo "Defined NAT network ad-lab (192.168.57.0/24, no DHCP)"
