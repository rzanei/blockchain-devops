#!/bin/bash

set -e

# === BASIC CONFIG ===
TARGET="osmosisd"
CHAIN_ID="osmosis-1"
MONIKER="TheDigitalEmpire"
KEYRING="file"
DENOM="uosmo"
HOMEDIR="$HOME/.${TARGET}"

GENESIS="$HOMEDIR/config/genesis.json"
CONFIG="$HOMEDIR/config/config.toml"
APP="$HOMEDIR/config/app.toml"

RPC1="https://osmosis-rpc.polkachu.com"
RPC2="https://rpc.osmosis.zone"
SNAP_RPC="$RPC1"

PEERS="ade4d8bc8cbe014af6ebdf3cb7b1e9ad36f412c0@seeds.polkachu.com:12556"

# === FIRST-TIME SETUP ===
if [ ! -d "$HOMEDIR/data" ]; then
  echo "🧹 First-time setup: resetting state..."
  rm -rf "$HOMEDIR/data" "$HOMEDIR/config/addrbook.json"
  INIT_NODE=true
else
  echo "✅ Existing data found. Skipping reset."
  INIT_NODE=false
fi

# === INIT NODE ===
if [ "$INIT_NODE" = true ]; then
  echo "🚀 Initializing Osmosis node..."
  $TARGET init "$MONIKER" --chain-id "$CHAIN_ID" --home "$HOMEDIR"
  echo "📚 Downloading fresh addrbook.json..."
  ADDRBOOK_URL="https://snapshots.polkachu.com/addrbook/osmosis/addrbook.json"
  wget -O "$HOMEDIR/config/addrbook.json" "$ADDRBOOK_URL" --inet4-only

  echo "🌐 Downloading genesis.json..."
  curl -s https://snapshots.polkachu.com/genesis/osmosis/genesis.json -o "$GENESIS"

  echo "🔐 Enabling state sync..."
  LATEST_HEIGHT=$(curl -s "$SNAP_RPC/block" | jq -r .result.block.header.height)
  TRUST_HEIGHT=$((LATEST_HEIGHT - 2000))
  TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$TRUST_HEIGHT" | jq -r .result.block_id.hash)

  sed -i "s/^enable *=.*/enable = true/" "$CONFIG"
  sed -i "s|^rpc_servers *=.*|rpc_servers = \"$RPC1,$RPC2\"|" "$CONFIG"
  sed -i "s/^trust_height *=.*/trust_height = $TRUST_HEIGHT/" "$CONFIG"
  sed -i "s/^trust_hash *=.*/trust_hash = \"$TRUST_HASH\"/" "$CONFIG"
  sed -i "s/^trust_period *=.*/trust_period = \"168h0m0s\"/" "$CONFIG"
  sed -i "s/^fast_sync *=.*/fast_sync = true/" "$CONFIG"
fi

# === CONFIGURE NODE ===
echo "⚙️ Updating config and app.toml..."

# API / gRPC / CORS
sed -i '/\[api\]/,/enable = false/s/enable = false/enable = true/' "$APP"
sed -i '/\[api\]/,/enabled-unsafe-cors = false/s/enabled-unsafe-cors = false/enabled-unsafe-cors = true/' "$APP"
sed -i '/\[grpc\]/,/enable = false/s/enable = false/enable = true/' "$APP"
sed -i '/\[grpc-web\]/,/enable = false/s/enable = false/enable = true/' "$APP"
sed -i 's|laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|' "$CONFIG"

# Persistent peers
sed -i "s|^persistent_peers *=.*|persistent_peers = \"$PEERS\"|" "$CONFIG"

# Minimum gas price
sed -i "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0025${DENOM}\"/" "$APP"

# Pruning and snapshots
echo "🧹 Setting pruning and snapshot strategy..."
sed -i 's/^pruning *=.*/pruning = "custom"/' "$APP"
sed -i 's/^pruning-keep-every *=.*/pruning-keep-every = "2000"/' "$APP"
sed -i 's/^pruning-keep-recent *=.*/pruning-keep-recent = "100"/' "$APP"
sed -i 's/^pruning-interval *=.*/pruning-interval = "200"/' "$APP"
sed -i 's/^snapshot-interval *=.*/snapshot-interval = 2000/' "$APP"
sed -i 's/^snapshot-keep-recent *=.*/snapshot-keep-recent = 5/' "$APP"

# === INFO ===
if [ "$INIT_NODE" = true ]; then
  echo "✅ Node initialized. You can now recover your validator key:"
  echo "👉 $TARGET keys add validator --recover --keyring-backend $KEYRING --home $HOMEDIR"
fi

# === START NODE ===
echo "🚀 Starting node..."
exec $TARGET start --home "$HOMEDIR" --log_level info --moniker "$MONIKER"
