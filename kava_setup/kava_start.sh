#!/bin/bash

set -e

# === BASIC CONFIG ===
TARGET="kavad"
HOMEDIR="$HOME/.${TARGET}"
CHAINID="kava_2222-10"
KEYRING="file"
MONIKER="TheDigitalEmpire"
DENOM="ukava"

GENESIS="$HOMEDIR/config/genesis.json"
CONFIG="$HOMEDIR/config/config.toml"
APP="$HOMEDIR/config/app.toml"
SNAP_URL="https://storage1.quicksync.io/kava/mainnet/minimal/latest.tar.zst"
SNAP_FILE="$HOME/snapshot.tar.lz4"
export NO_COLOR=1

# === FIRST-TIME CHECK ===
if [ ! -d "$HOMEDIR/data" ]; then
  echo "🧹 First-time setup..."
  INIT_NODE=true
else
  echo "✅ Blockchain data exists."
  INIT_NODE=false
fi

# === INIT NODE ===
if [ "$INIT_NODE" = true ]; then
  echo "🚀 Initializing Kava validator node..."
  $TARGET init "$MONIKER" --chain-id "$CHAINID" --home "$HOMEDIR"

  echo "🌐 Downloading genesis file..."
  curl -s "https://kava-genesis-files.s3.us-east-1.amazonaws.com/kava_2222-10/genesis.json" -o "$GENESIS"

  echo "📥 Downloading snapshot file..."
  curl -L -o "$SNAP_FILE" "$SNAP_URL"

  echo "⚠ Resetting node state..."
  $TARGET tendermint unsafe-reset-all --home "$HOMEDIR" --keep-addr-book

  echo "📦 Extracting snapshot (with progress)..."
  tar --use-compress-program=unzstd -xvf "$SNAP_FILE" -C "$HOMEDIR"

  echo "🧹 Cleaning up snapshot file..."
  rm -f "$SNAP_FILE"

  echo "🔧 Restore priv_validator_state.json if backup exists..."
  if [ -f "$HOMEDIR/priv_validator_state.json.bak" ]; then
    cp "$HOMEDIR/priv_validator_state.json.bak" "$HOMEDIR/data/priv_validator_state.json"
    rm "$HOMEDIR/priv_validator_state.json.bak"
  fi

  echo "❌ Disabling state sync to avoid conflict..."
  sed -i 's/^enable *=.*/enable = false/' "$CONFIG"
  sed -i 's/^rpc_servers *=.*/rpc_servers = ""/' "$CONFIG"
  sed -i 's/^trust_height *=.*/trust_height = 0/' "$CONFIG"
  sed -i 's/^trust_hash *=.*/trust_hash = ""/' "$CONFIG"
fi

# === CONFIGURE NODE ===
echo "⚙️ Configuring node..."

# echo "🔧 Fix possible missing min_commission_rate"
# jq '.app_state.staking.params.min_commission_rate = "0.000000000000000000"' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"

# echo "🔧 Remove unknown abstain fields (fully walk)"
# jq 'walk(if type == "object" then del(.abstain) else . end)' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"

# Enable API + CORS + gRPC + RPC
sed -i '/\[api\]/,/enable = false/s/enable = false/enable = true/' "$APP"
sed -i '/\[api\]/,/enabled-unsafe-cors = false/s/enabled-unsafe-cors = false/enabled-unsafe-cors = true/' "$APP"
sed -i '/\[grpc\]/,/enable = false/s/enable = false/enable = true/' "$APP"
sed -i '/\[grpc-web\]/,/enable = false/s/enable = false/enable = true/' "$APP"
sed -i 's/^enable *= *true/enable = false/' "$APP"
sed -i 's|laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|' "$CONFIG"

# Performance tuning: iavl-disable-fastnode and discard_abci_responses
sed -i 's|^storage.discard_abci_responses *=.*|storage.discard_abci_responses = true|' "$CONFIG" || echo 'storage.discard_abci_responses = true' >> "$CONFIG"
sed -i 's|^iavl-disable-fastnode *=.*|iavl-disable-fastnode = true|' "$APP" || echo 'iavl-disable-fastnode = true' >> "$APP"

# Configure persistent peers
PEERS="3075a9bc512e2f6882431ba4057d85aeef57cf8a@136.243.147.235:13956,b398be3de934573073f75c4075df9829cf7dacc6@142.132.158.9:13956,4a399804899c2ef764b71db0c21ebd37f3643863@138.201.197.188:4000,10993a6beb3a6ab38f186d2c3b2fe77310e24b7c@82.100.58.117:26656,efc317a83887975aae92a7020c92e75f2a3cee12@138.201.127.169:26656,c925f3d550e57cc43aa747197abecbfe975809c0@173.214.24.178:26656,106fdbaead50477479bd003681d840767169c8a3@23.88.72.46:26666,414cac4d762d80efd5abbc3725f960093b990613@65.109.159.109:13956,87ea634a248b0e744785ca3e9c9a597150a9ea34@141.94.139.219:26956,80c69334a84523836602e2fc0a4eace56cf84dc7@49.12.172.57:26666,3bcc95ea9d7aac1da52b2cff96fbe3439e49eeef@5.10.24.81:26656,6cf922e49395521cbc2682ba650d4fd6fc08bce4@85.237.193.94:26656"
sed -i "s|^persistent_peers *=.*|persistent_peers = \"$PEERS\"|" "$CONFIG"
sed -i 's/^minimum-gas-prices = ""/minimum-gas-prices = "0.001ukava"/' "$APP"

# === CUSTOM PRUNING & SNAPSHOT STRATEGY ===
echo "🧹 Setting custom pruning and snapshot strategy..."
sed -i 's/^pruning *=.*/pruning = "custom"/' "$APP"
sed -i 's/^pruning-keep-recent *=.*/pruning-keep-recent = "100"/' "$APP"
sed -i 's/^pruning-keep-every *=.*/pruning-keep-every = "0"/' "$APP"
sed -i 's/^pruning-interval *=.*/pruning-interval = "10"/' "$APP"
sed -i 's/^snapshot-interval *=.*/snapshot-interval = 0/' "$APP"
sed -i 's/^snapshot-keep-recent *=.*/snapshot-keep-recent = 0/' "$APP"

# === INFO ===
if [ "$INIT_NODE" = true ]; then
  echo "✅ Node initialized. Load your validator key:"
  echo "👉 Run inside container:"
  echo "   $TARGET keys add validator --recover --keyring-backend $KEYRING --home $HOMEDIR"
fi

# === START NODE ===
exec $TARGET start --home "$HOMEDIR" --log_level info --moniker "$MONIKER"
