#!/bin/sh
set -eu

DEFAULT_VLESS_ID="2d8fa6af-8380-441a-93d3-5282f44b43c3"
DEFAULT_VMESS_ID="2d8fa6af-8380-441a-93d3-5282f44b43c3"
VLESS_ID="${VLESS_ID:-$DEFAULT_VLESS_ID}"
VMESS_ID="${VMESS_ID:-$DEFAULT_VMESS_ID}"

if [ ! -s "${XRAY_CONFIG}" ]; then
  cp /etc/xray/config.example.json "${XRAY_CONFIG}"
  sed -i \
    -e "s/${DEFAULT_VLESS_ID}/${VLESS_ID}/g" \
    -e "s/${DEFAULT_VMESS_ID}/${VMESS_ID}/g" \
    "${XRAY_CONFIG}"
fi

pids=""

start_bg() {
  "$@" &
  pids="$pids $!"
}

cleanup() {
  for pid in $pids; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
}

trap cleanup INT TERM EXIT

start_bg xray run -c "${XRAY_CONFIG}"
start_bg caddy run --config "${CADDY_CONFIG}" --adapter caddyfile

if [ -n "${CLOUDFLARED_TOKEN:-}" ]; then
  start_bg cloudflared tunnel --no-autoupdate --metrics "${CF_METRICS}" run --token "${CLOUDFLARED_TOKEN}"
fi

while true; do
  for pid in $pids; do
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid"
      exit_code=$?
      cleanup
      exit "${exit_code}"
    fi
  done
  sleep 1
done
