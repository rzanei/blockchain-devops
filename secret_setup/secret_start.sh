#!/bin/bash

set -e

# === CONFIGURATION ===
TARGET="secretd"
HOMEDIR="$HOME/.${TARGET}"
CHAINID="secret-4"
KEYRING="file"
MONIKER="TheDigitalEmpire"
DENOM="uscrt"

GENESIS="$HOMEDIR/config/genesis.json"
CONFIG="$HOMEDIR/config/config.toml"
APP="$HOMEDIR/config/app.toml"

SGX_SECRETS="/opt/secret/.sgx_secrets"
KEY_ALIAS="validator"

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
  echo "🚀 Initializing Secret validator node..."
  $TARGET init "$MONIKER" --chain-id "$CHAINID" --home "$HOMEDIR"

  echo "🌐 Downloading genesis file..."
  wget -O $GENESIS "https://github.com/scrtlabs/SecretNetwork/releases/download/v1.2.0/genesis.json"
  echo "759e1b6761c14fb448bf4b515ca297ab382855b20bae2af88a7bdd82eb1f44b9 $GENESIS" | sha256sum --check

  echo "🔐 Setting up SGX secrets..."
  mkdir -p "$SGX_SECRETS"
  $TARGET init-enclave

  echo "📜 Registering enclave on-chain..."
  $TARGET tx register auth "$SGX_SECRETS/attestation_combined.bin" -y --gas 700000 --from "$KEY_ALIAS" --keyring-backend "$KEYRING"

  echo "🔍 Dumping public key and retrieving encrypted seed..."
  PUBLIC_KEY=$($TARGET dump "$SGX_SECRETS/pubkey.bin")
  SEED=$($TARGET query register seed "$PUBLIC_KEY" | cut -c 3-)

  echo "🧬 Configuring node with encrypted seed..."
  mkdir -p "$HOMEDIR/.node"
  $TARGET query register secret-network-params > node-master-key.txt
  $TARGET configure-secret node-master-key.txt "$SEED"

  echo "📛 Add your validator key now if needed:"
  echo "👉 Run: $TARGET keys add $KEY_ALIAS --recover --keyring-backend $KEYRING --home $HOMEDIR"
fi

# === NODE CONFIG ===
echo "⚙️ Configuring node..."
sed -i '/\[api\]/,/enable = false/s/enable = false/enable = true/' "$APP"
sed -i '/\[api\]/,/enabled-unsafe-cors = false/s/enabled-unsafe-cors = false/enabled-unsafe-cors = true/' "$APP"
sed -i '/\[grpc\]/,/enable = false/s/enable = false/enable = true/' "$APP"
sed -i '/\[grpc-web\]/,/enable = false/s/enable = false/enable = true/' "$APP"
sed -i 's/^enable *= *true/enable = false/' "$APP"
sed -i 's|laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|' "$CONFIG"

# Set peers
PEERS="46f5d112960b0a9dd9d1d130fe2e2e7b51e84c63@rpc1.secretnodes.com:26656"
sed -i "s|^persistent_peers *=.*|persistent_peers = \"$PEERS\"|" "$CONFIG"

# Gas price
sed -i 's/^minimum-gas-prices = ""/minimum-gas-prices = "0.25uscrt"/' "$APP"

# Pruning and snapshot
echo "🧹 Setting pruning and snapshot strategy..."
sed -i 's/^pruning *=.*/pruning = "custom"/' "$APP"
sed -i 's/^pruning-keep-recent *=.*/pruning-keep-recent = "100"/' "$APP"
sed -i 's/^pruning-keep-every *=.*/pruning-keep-every = "0"/' "$APP"
sed -i 's/^pruning-interval *=.*/pruning-interval = "10"/' "$APP"
sed -i 's/^snapshot-interval *=.*/snapshot-interval = 2000/' "$APP"
sed -i 's/^snapshot-keep-recent *=.*/snapshot-keep-recent = 5/' "$APP"

# Enclave optimization
echo "🚀 Tuning enclave cache..."
sed -i.bak -e "s/^contract-memory-enclave-cache-size *=.*/contract-memory-enclave-cache-size = \"15\"/" "$APP"

# === LAUNCH NODE ===
echo "🚀 Launching Secret node..."
exec $TARGET start --home "$HOMEDIR" --log_level info --moniker "$MONIKER"
