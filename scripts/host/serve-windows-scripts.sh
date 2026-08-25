#!/usr/bin/env bash
# Serve scripts/windows to guests on both lab bridges (corp + foothold).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="${ROOT}/scripts/windows"
# 0.0.0.0 so both 192.168.57.1 and 192.168.58.1 work as the download URL.
BIND="${BIND:-0.0.0.0}"
PORT="${PORT:-8080}"

cd "$DIR"
{
  echo "# ad-kvm-lab windows scripts"
  ls -1 *.ps1 *.example 2>/dev/null | grep -v '^00-creds.ps1$' | sort
} > manifest.txt

echo "Serving ${DIR} on http://${BIND}:${PORT}/"
echo "On corp (.57) Windows VMs:"
echo "  irm http://192.168.57.1:${PORT}/00-download.ps1 | iex"
echo "On JUMP-CORP / foothold (.58) guests:"
echo "  irm http://192.168.58.1:${PORT}/00-download.ps1 | iex"
echo "Ctrl-C to stop."
exec python3 -m http.server "$PORT" --bind "$BIND"
