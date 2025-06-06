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
  echo "🧹 First-time setup..."
  INIT_NODE=true
else
  echo "✅ Blockchain data exists."
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
sed -i 's/^enable *= *true/enable = false/' "$APP"
sed -i 's|laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|' "$CONFIG"

# Configure persistent peers
PEERS="b3d4c223f832a6582be431060efb2a73903dc85b@85.237.193.106:26656,66b74927d51888a25fe94bff2dfeaae125739f26@79.127.196.36:29656,c58852a0c6ee1d1a68b76e5a54a9dbce895065d9@162.55.245.149:2140,ebeea522e069f9037876e13f73310a601cfcff8a@95.179.212.224:26656,0d8434034e645d305a0cf294e5670ee59e5e55f0@148.251.53.24:12856,4de4f8839c4afdac12aa3c40b80788e720fcd324@164.152.163.191:26656,9744e833f44218fb6f0646e2c37aae1331ce1efc@37.252.186.117:2000,5a7599058e1bb208c6d8fe1e8e514d7bd6559980@146.59.81.92:29656,be0a6315cbac3a368ff394d314514264d8447057@141.94.139.219:26856,893429952c41a3485ea63b5af2886c91f090c065@65.108.76.28:12856,d1e47b071859497089c944dc082e920403484c1a@65.108.128.201:12856,1fb2f4a044c08c96f9b527b8c35b7db4425c75e0@141.94.195.151:12856,dda1f59957f767e20b0fc64b1c915b4799fc0cc5@159.223.201.93:26656,a89ded27c2323388fc0f12e7a08f17424b2b7a45@135.181.142.60:15607,79685f65de2bfc391ecbb1d16a275f10bad1c038@65.109.37.251:26656,9aa4c9097c818871e45aaca4118a9fe5e86c60e2@135.181.113.227:1506,03493c979e821f9d047715b1aaec0ee969392c76@95.214.53.119:26656,82c0ece4f15b830a1982fef0fa103d31ecd563b9@148.251.176.12:2000,9b0d47d9872814d7d66ea15e7a5775d9a3bb4da4@5.9.77.116:14756,f9215993d48d8e0abc31cea931d573a45d201ac8@65.108.232.104:12856,6adc00bef235246c90757547d5f0703d6a548460@178.128.82.28:26656,2719d5a0f2ea29bc3d5d48f8487ac07ca94749f7@49.13.153.159:26667,bc9c4ccacb089ebbaa3fb91bc9aa6348027a2d12@144.76.115.182:12856,02b5a74f0cc909045efe170da3cc5706de2c0be5@88.208.243.62:26656,86f866a645bcc25d3d26fe8dffbd603ebfc0d6ee@142.132.158.93:12856"

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
