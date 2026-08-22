#!/usr/bin/env bash
# Serve scripts/windows to guests at http://192.168.57.1:8080
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="${ROOT}/scripts/windows"
BIND="${BIND:-192.168.57.1}"
PORT="${PORT:-8080}"

cd "$DIR"
{
  echo "# ad-kvm-lab windows scripts"
  ls -1 *.ps1 *.example 2>/dev/null | grep -v '^00-creds.ps1$' | sort
} > manifest.txt

echo "Serving ${DIR} on http://${BIND}:${PORT}/"
echo "On the Windows VM:"
echo "  Set-ExecutionPolicy Bypass -Scope Process -Force"
echo "  irm http://${BIND}:${PORT}/00-download.ps1 | iex"
echo "Ctrl-C to stop."
exec python3 -m http.server "$PORT" --bind "$BIND"
