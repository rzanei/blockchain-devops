#!/bin/bash

set -euo pipefail

# ============================================================
# Generic Cosmos addrbook peer checker
#
# Usage examples:
#   CHAIN_NAME=sentinelhub-2 ./check_peers_from_addrbook.sh
#   ADDRBOOK_URL=https://snapshots.polkachu.com/addrbook/sentinel/addrbook.json ./check_peers_from_addrbook.sh
#
# Env vars:
#   CHAIN_NAME       - chain name used in addrbook URL, e.g. "sentinel" or "kava"
#   ADDRBOOK_URL     - full addrbook URL (overrides CHAIN_NAME)
#   ADDRBOOK_BASE    - base URL, defaults to https://snapshots.polkachu.com/addrbook
#   MAX_PEERS        - max peers from addrbook to test (default: 50)
#   NC_TIMEOUT       - netcat timeout per peer in seconds (default: 2)
#   CHECK_SNAPSHOTS  - "true" to check snapshot endpoint via RPC (default: false)
#   SNAP_RPC_PATTERN - pattern for snapshot RPC URL using IP placeholder "IP"
#                      default: "http://IP:26657/snapshots"
# ============================================================

ADDRBOOK_BASE="${ADDRBOOK_BASE:-https://snapshots.polkachu.com/addrbook}"
CHAIN_NAME="${CHAIN_NAME:-}"
ADDRBOOK_URL="${ADDRBOOK_URL:-}"
MAX_PEERS="${MAX_PEERS:-50}"
NC_TIMEOUT="${NC_TIMEOUT:-2}"
CHECK_SNAPSHOTS="${CHECK_SNAPSHOTS:-false}"
SNAP_RPC_PATTERN="${SNAP_RPC_PATTERN:-http://IP:26657/snapshots}"

if [[ -z "$ADDRBOOK_URL" ]]; then
  if [[ -z "$CHAIN_NAME" ]]; then
    echo "❌ ERROR: Set either CHAIN_NAME or ADDRBOOK_URL" >&2
    echo "Example:" >&2
    echo "  CHAIN_NAME=sentinel ./check_peers_from_addrbook.sh" >&2
    echo "  ADDRBOOK_URL=https://snapshots.polkachu.com/addrbook/sentinel/addrbook.json ./check_peers_from_addrbook.sh" >&2
    exit 1
  fi
  ADDRBOOK_URL="${ADDRBOOK_BASE}/${CHAIN_NAME}/addrbook.json"
fi

echo "🌐 Using addrbook URL: $ADDRBOOK_URL"
echo "🔎 Fetching addrbook..."

TMP_ADDRBOOK="$(mktemp)"
trap 'rm -f "$TMP_ADDRBOOK"' EXIT

if ! curl -fsSL "$ADDRBOOK_URL" -o "$TMP_ADDRBOOK"; then
  echo "❌ Failed to download addrbook from: $ADDRBOOK_URL" >&2
  exit 1
fi

echo "📦 Parsing peers from addrbook..."
mapfile -t ALL_PEERS < <(jq -r '.addrs[].addr | "\(.id)@\(.ip):\(.port)"' "$TMP_ADDRBOOK" 2>/dev/null | head -n "$MAX_PEERS")

if [[ ${#ALL_PEERS[@]} -eq 0 ]]; then
  echo "❌ No peers found in addrbook (or unexpected format)" >&2
  exit 1
fi

echo "Found ${#ALL_PEERS[@]} peers in addrbook (testing up to $MAX_PEERS)..."
echo

WORKING_PEERS=()
SNAPSHOT_PEERS=()

for peer in "${ALL_PEERS[@]}"; do
  node_id="${peer%@*}"
  address="${peer#*@}"
  ip="${address%%:*}"
  port="${address##*:}"

  echo -n "⏱  Testing $peer ... "

  if nc -z -w "$NC_TIMEOUT" "$ip" "$port" &>/dev/null; then
    echo "✅ Reachable"
    WORKING_PEERS+=("$peer")

    if [[ "$CHECK_SNAPSHOTS" == "true" ]]; then
      snap_url="${SNAP_RPC_PATTERN//IP/$ip}"

      # Note: This assumes the node exposes RPC on that IP (and whatever port
      # you set in SNAP_RPC_PATTERN). This may not match the P2P port.
      SNAP_RESPONSE="$(curl -s --max-time 5 "$snap_url" || true)"

      if [[ -n "$SNAP_RESPONSE" ]]; then
        count="$(echo "$SNAP_RESPONSE" | jq '.result.snapshots | length' 2>/dev/null || echo 0)"
        if [[ "$count" -gt 0 ]]; then
          echo "   📦 Provides $count snapshot(s) at $snap_url"
          SNAPSHOT_PEERS+=("$peer")
        else
          echo "   ❌ No snapshots found at $snap_url"
        fi
      else
        echo "   ⚠️ No response from snapshot URL: $snap_url"
      fi
    fi
  else
    echo "❌ Unreachable"
  fi
done

echo
echo "=============================="
echo "✅ Usable (reachable) peers: ${#WORKING_PEERS[@]}"
if [[ ${#WORKING_PEERS[@]} -gt 0 ]]; then
  WORKING_JOINED=$(IFS=, ; echo "${WORKING_PEERS[*]}")
  echo "$WORKING_JOINED"
  echo
  echo "👉 You can use this in your deployment YAML:"
  echo "    - PERSISTENT_PEERS=$WORKING_JOINED"
else
  echo "None"
fi

echo
echo "📦 Snapshot-capable peers (based on RPC pattern): ${#SNAPSHOT_PEERS[@]}"
if [[ ${#SNAPSHOT_PEERS[@]} -gt 0 ]]; then
  SNAPSHOT_JOINED=$(IFS=, ; echo "${SNAPSHOT_PEERS[*]}")
  echo "$SNAPSHOT_JOINED"
else
  echo "None (or CHECK_SNAPSHOTS=false)"
fi
echo "=============================="
