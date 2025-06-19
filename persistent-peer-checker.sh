#!/bin/bash

# List of peers to check (format: NODE_ID@IP:PORT)
PEERS=("ade4d8bc8cbe014af6ebdf3cb7b1e9ad36f412c0@seeds.polkachu.com:13956"
"ebc272824924ea1a27ea3183dd0b9ba713494f83@kava-mainnet-seed.autostake.com:26656"
"7ab4b78fbe5ee9e3777b21464a3162bd4cc17f57@seed-kava-01.stakeflow.io:1206"
"8542cd7e6bf9d260fef543bc49e59be5a3fa9074@seed.publicnode.com:26656"
"10ed1e176d874c8bb3c7c065685d2da6a4b86475@seed-kava.ibs.team:16677")

WORKING_PEERS=()
SNAPSHOT_PEERS=()
echo "🔎 Checking peers..."

for peer in "${PEERS[@]}"; do
  node_id=$(echo "$peer" | cut -d@ -f1)
  address=$(echo "$peer" | cut -d@ -f2)
  ip=$(echo "$address" | cut -d: -f1)
  port=$(echo "$address" | cut -d: -f2)

  # Check if peer is reachable
  nc -z -w2 "$ip" "$port" &>/dev/null
  if [ $? -eq 0 ]; then
    echo "$peer ✅ Reachable"

    WORKING_PEERS+=("$peer")

    # Check if snapshot endpoint returns anything
    SNAPSHOT_URL="http://$ip:$port/snapshots"
    SNAP_RESPONSE=$(curl -s --max-time 5 "$SNAPSHOT_URL")
    COUNT=$(echo "$SNAP_RESPONSE" | jq '.result.snapshots | length' 2>/dev/null || echo 0)

    if [[ "$COUNT" -gt 0 ]]; then
      echo "   📦 Provides $COUNT snapshot(s)"
      SNAPSHOT_PEERS+=("$peer")
    else
      echo "   ❌ No snapshots found"
    fi
  else
    echo "$peer ❌ Unreachable"
  fi
done

# Format outputs
WORKING_JOINED=$(IFS=, ; echo "${WORKING_PEERS[*]}")
SNAPSHOT_JOINED=$(IFS=, ; echo "${SNAPSHOT_PEERS[*]}")

echo
echo "=============================="
echo "✅ Usable Peers: ${#WORKING_PEERS[@]}"
echo "$WORKING_JOINED"

echo
echo "📦 Snapshot-Capable Peers: ${#SNAPSHOT_PEERS[@]}"
echo "$SNAPSHOT_JOINED"
echo "=============================="
