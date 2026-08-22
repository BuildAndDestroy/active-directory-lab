#!/usr/bin/env bash
# Move lab qcow2 disks from $HOME/libvirt to /var/lib/libvirt/images.
# Shuts down running lab guests, copies disks, retargets libvirt XML, starts dc-corp.
# Does not delete the old files; remove them yourself after you confirm the VM boots.
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

SRC="${SRC:-$HOME/libvirt/ad-kvm-lab}"
DST="${DST:-/var/lib/libvirt/images/ad-kvm-lab}"
URI="${LIBVIRT_URI:-qemu:///system}"
OLD_PREFIX='/home/codonnell/libvirt/ad-kvm-lab'
NEW_PREFIX='/var/lib/libvirt/images/ad-kvm-lab'

[[ -d "$SRC" ]] || { echo "missing $SRC"; exit 1; }

require_sudo_or_root "$DST"
ensure_libvirt_pool "$DST"

lab_guests=(dc-corp dc-corp2 dc-partner srv-corp ca-corp win10-corp kali-ad)
for g in "${lab_guests[@]}"; do
  if virsh -c "$URI" dominfo "$g" >/dev/null 2>&1; then
    state="$(virsh -c "$URI" domstate "$g")"
    if [[ "$state" != "shut off" ]]; then
      echo "Shutting down $g"
      virsh -c "$URI" shutdown "$g" || true
    fi
  fi
done

echo "Waiting for lab guests to stop..."
for _ in $(seq 1 60); do
  busy=0
  for g in "${lab_guests[@]}"; do
    if virsh -c "$URI" dominfo "$g" >/dev/null 2>&1; then
      state="$(virsh -c "$URI" domstate "$g")"
      if [[ "$state" != "shut off" ]]; then
        busy=1
      fi
    fi
  done
  [[ $busy -eq 0 ]] && break
  sleep 2
done

for g in "${lab_guests[@]}"; do
  if virsh -c "$URI" dominfo "$g" >/dev/null 2>&1; then
    state="$(virsh -c "$URI" domstate "$g")"
    if [[ "$state" != "shut off" ]]; then
      echo "Forcing off $g"
      virsh -c "$URI" destroy "$g"
    fi
  fi
done

echo "Converting disks to thin qcow2 (preallocation=off). Empty images take seconds; dc-corp copies used clusters only."
shopt -s nullglob
for img in "$SRC"/*.qcow2; do
  base="$(basename "$img")"
  dest="${DST}/${base}"
  echo "  $base ($(qemu-img info --output=json "$img" | python3 -c 'import json,sys; i=json.load(sys.stdin); print("%s virtual, %s on disk" % (i.get("virtual-size",0), i.get("actual-size",0)))' 2>/dev/null || echo 'qcow2'))"
  run_priv qemu-img convert -p -O qcow2 -o preallocation=off "$img" "$dest"
done
run_priv chown -R "${USER}:kvm" "$DST"
if [[ -f "$DST/dc-corp.qcow2" ]]; then
  run_priv chown libvirt-qemu:kvm "$DST/dc-corp.qcow2"
fi

tmpdir="$(mktemp -d)"
for g in "${lab_guests[@]}"; do
  if virsh -c "$URI" dominfo "$g" >/dev/null 2>&1; then
    virsh -c "$URI" dumpxml "$g" > "${tmpdir}/${g}.xml"
    if grep -q "$OLD_PREFIX" "${tmpdir}/${g}.xml"; then
      sed -i "s|${OLD_PREFIX}|${NEW_PREFIX}|g" "${tmpdir}/${g}.xml"
      virsh -c "$URI" define "${tmpdir}/${g}.xml"
      echo "Updated disk path for $g"
    fi
  fi
done
rm -rf "$tmpdir"

if virsh -c "$URI" dominfo dc-corp >/dev/null 2>&1; then
  virsh -c "$URI" start dc-corp
  echo "Started dc-corp from $DST/dc-corp.qcow2"
fi

echo
echo "Verify the VM, then delete the old copies:"
echo "  rm -rf $SRC"
echo "Do not delete $SRC until dc-corp boots from $DST."
