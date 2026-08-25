#!/usr/bin/env bash
# Create a libvirt guest. Does not install the OS; attach ISOs and complete setup in the console.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
if [[ -f "${ROOT}/config.env" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT}/config.env"
fi

URI="${LIBVIRT_URI:-qemu:///system}"
DISK_POOL="${DISK_POOL:-/var/lib/libvirt/images/ad-kvm-lab}"
NETWORK="${NETWORK:-ad-lab}"
NETWORK_FOOTHOLD="${NETWORK_FOOTHOLD:-ad-lab-foothold}"
WIN_SERVER_ISO="${WIN_SERVER_ISO:-}"
WIN10_ISO="${WIN10_ISO:-}"
KALI_ISO="${KALI_ISO:-}"
VIRTIO_ISO="${VIRTIO_ISO:-}"

# Fixed MACs so JUMP-CORP Windows scripts can bind the right static IPs.
# First NIC = corp (ad-lab), second = foothold (ad-lab-foothold).
JUMP_MAC_CORP="${JUMP_MAC_CORP:-52:54:00:57:00:60}"
JUMP_MAC_FOOTHOLD="${JUMP_MAC_FOOTHOLD:-52:54:00:58:00:10}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <guest>

Guests: dc-corp dc-corp2 dc-partner srv-corp ca-corp win10-corp jump-corp dc-foothold srv-foothold kali-ad

Requires config.env ISO paths and a disk from create-disks.sh.
jump-corp is dual-homed (ad-lab + ad-lab-foothold). kali-ad is on foothold only.
EOF
  exit 1
}

[[ $# -eq 1 ]] || usage
GUEST="$1"

disk="${DISK_POOL}/${GUEST}.qcow2"
[[ -f "$disk" ]] || { echo "missing disk $disk — run create-disks.sh"; exit 1; }
if is_system_libvirt_pool "$DISK_POOL" && [[ ! -r "$disk" ]]; then
  echo "error: cannot read ${disk}. Check ownership under /var/lib/libvirt/images (root or sudo)." >&2
  exit 1
fi

if virsh -c "$URI" dominfo "$GUEST" >/dev/null 2>&1; then
  echo "domain $GUEST already exists"
  exit 0
fi

HAVE_VIRTIO=0
if [[ -n "$VIRTIO_ISO" && -f "$VIRTIO_ISO" ]]; then
  HAVE_VIRTIO=1
fi

if [[ $HAVE_VIRTIO -eq 1 ]]; then
  nic_model=virtio
  disk_bus=virtio
else
  nic_model=e1000
  disk_bus=sata
  if [[ "$GUEST" != kali-ad ]]; then
    echo "No virtio-win ISO; using SATA disk and e1000 NIC so Windows setup can see the disk."
  fi
fi

# Kali has virtio in-tree
if [[ "$GUEST" == kali-ad ]]; then
  nic_model=virtio
  disk_bus=virtio
fi

common=(
  --connect "$URI"
  --name "$GUEST"
  --cpu host-passthrough
  --vcpus 2
  --graphics spice
  --video qxl
  --channel unix,target_type=virtio,name=org.qemu.guest_agent.0
  --noautoconsole
)

case "$GUEST" in
  dc-corp|dc-corp2|dc-partner|srv-corp)
    [[ -n "$WIN_SERVER_ISO" && -f "$WIN_SERVER_ISO" ]] || { echo "set WIN_SERVER_ISO in config.env"; exit 1; }
    common+=(--network "network=${NETWORK},model=${nic_model}")
    extra=(
      --memory 4096
      --os-variant win2k19
      --disk "path=${disk},format=qcow2,bus=${disk_bus},cache=writeback,discard=unmap,sparse=yes"
      --cdrom "$WIN_SERVER_ISO"
    )
    ;;
  ca-corp)
    [[ -n "$WIN_SERVER_ISO" && -f "$WIN_SERVER_ISO" ]] || { echo "set WIN_SERVER_ISO in config.env"; exit 1; }
    common+=(--network "network=${NETWORK},model=${nic_model}")
    extra=(
      --memory 8192
      --os-variant win2k19
      --disk "path=${disk},format=qcow2,bus=${disk_bus},cache=writeback,discard=unmap,sparse=yes"
      --cdrom "$WIN_SERVER_ISO"
    )
    ;;
  win10-corp)
    [[ -n "$WIN10_ISO" && -f "$WIN10_ISO" ]] || { echo "set WIN10_ISO in config.env"; exit 1; }
    common+=(--network "network=${NETWORK},model=${nic_model}")
    extra=(
      --memory 4096
      --os-variant win10
      --disk "path=${disk},format=qcow2,bus=${disk_bus},cache=writeback,discard=unmap,sparse=yes"
      --cdrom "$WIN10_ISO"
    )
    ;;
  jump-corp)
    [[ -n "$WIN_SERVER_ISO" && -f "$WIN_SERVER_ISO" ]] || { echo "set WIN_SERVER_ISO in config.env"; exit 1; }
    # NIC order: corp first, foothold second (matched by MAC in 00-lab-config.ps1).
    common+=(
      --network "network=${NETWORK},model=${nic_model},mac=${JUMP_MAC_CORP}"
      --network "network=${NETWORK_FOOTHOLD},model=${nic_model},mac=${JUMP_MAC_FOOTHOLD}"
    )
    extra=(
      --memory 4096
      --os-variant win2k19
      --disk "path=${disk},format=qcow2,bus=${disk_bus},cache=writeback,discard=unmap,sparse=yes"
      --cdrom "$WIN_SERVER_ISO"
    )
    ;;
  dc-foothold)
    [[ -n "$WIN_SERVER_ISO" && -f "$WIN_SERVER_ISO" ]] || { echo "set WIN_SERVER_ISO in config.env"; exit 1; }
    common+=(--network "network=${NETWORK_FOOTHOLD},model=${nic_model}")
    extra=(
      --memory 4096
      --os-variant win2k19
      --disk "path=${disk},format=qcow2,bus=${disk_bus},cache=writeback,discard=unmap,sparse=yes"
      --cdrom "$WIN_SERVER_ISO"
    )
    ;;
  srv-foothold)
    [[ -n "$WIN_SERVER_ISO" && -f "$WIN_SERVER_ISO" ]] || { echo "set WIN_SERVER_ISO in config.env"; exit 1; }
    # Foothold only — initial vuln target; joins corp.lab during setup via temporary JUMP routing.
    common+=(--network "network=${NETWORK_FOOTHOLD},model=${nic_model}")
    extra=(
      --memory 4096
      --os-variant win2k19
      --disk "path=${disk},format=qcow2,bus=${disk_bus},cache=writeback,discard=unmap,sparse=yes"
      --cdrom "$WIN_SERVER_ISO"
    )
    ;;
  kali-ad)
    [[ -n "$KALI_ISO" && -f "$KALI_ISO" ]] || { echo "set KALI_ISO in config.env"; exit 1; }
    # Foothold only — no direct path to corp AD without pivoting through JUMP-CORP.
    common+=(--network "network=${NETWORK_FOOTHOLD},model=${nic_model}")
    extra=(
      --memory 4096
      --os-variant debian11
      --disk "path=${disk},format=qcow2,bus=${disk_bus},cache=writeback,discard=unmap,sparse=yes"
      --cdrom "$KALI_ISO"
    )
    ;;
  *)
    usage
    ;;
esac

if [[ "$GUEST" != kali-ad && $HAVE_VIRTIO -eq 1 ]]; then
  extra+=(--disk "device=cdrom,path=${VIRTIO_ISO}")
fi

virt-install "${common[@]}" "${extra[@]}"
echo "Created $GUEST. Open virt-manager and finish OS install (hostname/IP in inventory.yaml)."
