#!/bin/bash

set -e

# === BASIC CONFIG ===
TARGET="akash"
HOMEDIR="$HOME/.${TARGET}"
CHAINID="akashnet-2"
KEYRING="file"
MONIKER="TheDigitalEmpire"
DENOM="uakt"

GENESIS="$HOMEDIR/config/genesis.json"
TMP_GENESIS="$HOMEDIR/config/tmp_genesis.json"
CONFIG="$HOMEDIR/config/config.toml"
APP="$HOMEDIR/config/app.toml"

# === FIRST-TIME CHECK ===
if [ ! -d "$HOMEDIR/data" ]; then
  echo "🧹 First-time setup: resetting blockchain state..."
  rm -rf "$HOMEDIR/data" "$HOMEDIR/config/addrbook.json"
  INIT_NODE=true
else
  echo "✅ Blockchain data exists, skipping reset and state sync."
  INIT_NODE=false
fi

# === INIT NODE ===
if [ "$INIT_NODE" = true ]; then
  echo "🚀 Initializing Akash validator node..."
  $TARGET init "$MONIKER" --chain-id "$CHAINID" --home "$HOMEDIR"

  echo "🌐 Downloading genesis file..."
  curl -s https://raw.githubusercontent.com/ovrclk/net/master/mainnet/genesis.json -o "$GENESIS"

  echo "🔧 Patching genesis.json..."
  jq 'del(.app_state.deployment.params.deployment_min_deposit)' "$GENESIS" > "$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
  jq '.app_state.deployment.params.min_deposits = [{"amount": "500000", "denom": "uakt"}]' "$GENESIS" > "$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

  echo "🛰️ Enabling State Sync..."
  STATESYNC_SERVERS="https://rpc-akash.ecostake.com:443,https://akash-rpc.polkachu.com:443"
  STATESYNC_RPC="https://rpc-akash.ecostake.com:443"

  LATEST_HEIGHT=$(curl -s "$STATESYNC_RPC/block" | jq -r .result.block.header.height)
  TRUST_HEIGHT=$((LATEST_HEIGHT - 2000))
  TRUST_HASH=$(curl -s "$STATESYNC_RPC/block?height=$TRUST_HEIGHT" | jq -r .result.block_id.hash)

  sed -i "s/^enable *=.*/enable = true/" "$CONFIG"
  sed -i "s|^rpc_servers *=.*|rpc_servers = \"$STATESYNC_SERVERS\"|" "$CONFIG"
  sed -i "s/^trust_height *=.*/trust_height = $TRUST_HEIGHT/" "$CONFIG"
  sed -i "s/^trust_hash *=.*/trust_hash = \"$TRUST_HASH\"/" "$CONFIG"
  sed -i "s/^trust_period *=.*/trust_period = \"168h0m0s\"/" "$CONFIG"
  sed -i "s/^fast_sync *=.*/fast_sync = true/" "$CONFIG"
fi

# === CONFIGURE NODE ===
echo "⚙️ Configuring node..."

# Enable API + CORS + gRPC + RPC
sed -i '/\[api\]/,/enable = false/s/enable = false/enable = true/' "$APP"
sed -i '/\[api\]/,/enabled-unsafe-cors = false/s/enabled-unsafe-cors = false/enabled-unsafe-cors = true/' "$APP"
sed -i '/\[grpc\]/,/enable = false/s/enable = false/enable = true/' "$APP"
sed -i '/\[grpc-web\]/,/enable = false/s/enable = false/enable = true/' "$APP"
sed -i 's|laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|' "$CONFIG"

# Configure persistent peers
PEERS="\
c13ccbfcd70626d42e048f2e79c02b775fcd7944@rpc-akash.whispernode.com:26656,\
ef856e1ef57c4efc396a4e064d04d2f8f5b82e58@akash-rpc.polkachu.com:26656,\
f0d3c114e0a388e2f10f0eb3f781705fd2c0db4b@akash-mainnet-seed.autostake.com:26656"

sed -i "s|^persistent_peers *=.*|persistent_peers = \"$PEERS\"|" "$CONFIG"
sed -i 's/^minimum-gas-prices = ""/minimum-gas-prices = "0.025uakt"/' "$APP"

# === CUSTOM PRUNING & SNAPSHOT STRATEGY ===
echo "🧹 Setting custom pruning and snapshot strategy..."
sed -i 's/^pruning *=.*/pruning = "custom"/' "$APP"
sed -i 's/^pruning-keep-every *=.*/pruning-keep-every = "2000"/' "$APP"
sed -i 's/^pruning-keep-recent *=.*/pruning-keep-recent = "0"/' "$APP"
sed -i 's/^pruning-interval *=.*/pruning-interval = "200"/' "$APP"
sed -i 's/^snapshot-interval *=.*/snapshot-interval = 2000/' "$APP"
sed -i 's/^snapshot-keep-recent *=.*/snapshot-keep-recent = 5/' "$APP"

# === INFO ===
if [ "$INIT_NODE" = true ]; then
  echo "✅ Node initialized. Load your validator key:"
  echo "👉 Run inside container:"
  echo "   akash keys add validator --recover --keyring-backend $KEYRING --home $HOMEDIR"
fi

# === START NODE ===
$TARGET start --home "$HOMEDIR" --log_level info --moniker $MONIKER
