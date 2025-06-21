#!/bin/bash

set -euo pipefail

# === BASIC CONFIG ===
TARGET="sentinelhub"
HOMEDIR="$HOME/.${TARGET}"
CHAINID="sentinelhub-2"
KEYRING="file"
MONIKER="TheDigitalEmpire"
DENOM="udvpn"

GENESIS="$HOMEDIR/config/genesis.json"
CONFIG="$HOMEDIR/config/config.toml"
APP="$HOMEDIR/config/app.toml"
SNAP_URL="https://snapshots.polkachu.com/snapshots/sentinel/sentinel_22104343.tar.lz4"
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

if [ "$INIT_NODE" = true ]; then
  echo "🚀 Initializing Sentinel validator node..."
  $TARGET init "$MONIKER" --chain-id "$CHAINID" --home "$HOMEDIR"

  echo "🌐 Downloading genesis file for Sentinel dVPN v0.11.5..."
  curl -fsSL -o genesis.zip "https://github.com/sentinel-official/networks/raw/refs/heads/main/sentinelhub-2/genesis.zip"
  unzip -o genesis.zip -d "$HOMEDIR/config/"
  rm genesis.zip

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

# === PATCH GENESIS: ensure required fields for Sentinel v0.11.5 ===
jq '
  # === REMOVE unsupported fields ===
  del(
    .app_state.vpn.nodes.params.inactive_duration,
    .app_state.vpn.sessions.params.inactive_duration,
    .app_state.vpn.subscriptions.params.inactive_duration
  )

  # === ADD required defaults if missing ===
  | .app_state.vpn.nodes.params.active_duration = (.app_state.vpn.nodes.params.active_duration // "3600s")
  | .app_state.vpn.nodes.params.staking_share = (.app_state.vpn.nodes.params.staking_share // "0.100000000000000000")
  | .app_state.vpn.nodes.params.max_subscription_gigabytes = (.app_state.vpn.nodes.params.max_subscription_gigabytes // "10")
  | .app_state.vpn.nodes.params.max_subscription_hours = (.app_state.vpn.nodes.params.max_subscription_hours // "10")
  | .app_state.vpn.nodes.params.min_subscription_gigabytes = (.app_state.vpn.nodes.params.min_subscription_gigabytes // "1")
  | .app_state.vpn.nodes.params.min_subscription_hours = (.app_state.vpn.nodes.params.min_subscription_hours // "1")

  # === ADD staking_share for providers if missing ===
  | .app_state.vpn.providers.params.staking_share = (.app_state.vpn.providers.params.staking_share // "0.100000000000000000")

  # === ADD status_change_delay for sessions and subscriptions
  | .app_state.vpn.sessions.params.status_change_delay = (.app_state.vpn.sessions.params.status_change_delay // "60s")
  | .app_state.vpn.subscriptions.params.status_change_delay = (.app_state.vpn.subscriptions.params.status_change_delay // "120s")
' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"

# === FIX GOV PROPOSALS FOR Cosmos SDK v0.45 ===
jq '
  .app_state.gov.proposals |= map(
    (
      if has("content") then . + .content | del(.content) else . end
    )
    | with_entries(
        select(
          .key != "@type" and
          .key != "proposal_id" and
          .key != "description" and
          .key != "title" and
          .key != "submit_time" and
          .key != "voting_start_time" and
          .key != "voting_end_time" and
          .key != "deposit_end_time"
        )
      )
    | .final_tally_result |= {
        "yes": (.yes // "0"),
        "abstain": (.abstain // "0"),
        "no": (.no // "0")
      }
    | del(.no_with_veto)
  )
  | .app_state.gov.proposals |= map(select(has("changes") | not))
' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"


# === RESTRUCTURE GOV PARAMS FOR SDK v0.45 ===
jq '
  .app_state.gov.deposit_params = {
    "min_deposit": (.app_state.gov.params.min_deposit // [{"denom": "udvpn", "amount": "10000000"}]),
    "max_deposit_period": (.app_state.gov.params.max_deposit_period // "172800s")
  }
  | .app_state.gov.voting_params = {
    "voting_period": (.app_state.gov.params.voting_period // "172800s")
  }
  | .app_state.gov.tally_params = {
    "quorum": (.app_state.gov.params.quorum // "0.334000000000000000"),
    "threshold": (.app_state.gov.params.threshold // "0.500000000000000000"),
    "veto_threshold": (.app_state.gov.params.veto_threshold // "0.334000000000000000")
  }
  | del(.app_state.gov.params)
' "$GENESIS" > "$GENESIS.tmp" && mv "$GENESIS.tmp" "$GENESIS"

# === CONFIGURE NODE ===
echo "⚙️ Configuring node..."
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
PEERS="22d8779a7fa39c81ca457be8ea8e6d51bd886045@38.102.86.36:21056,65d87ee4d3a29cf7364a7a9889787c65ee70146c@23.227.221.173:26656,7766ec993ae96803834e15ef1e06ffbdf5d8257c@95.211.45.16:21056"
sed -i "s|^persistent_peers *=.*|persistent_peers = \"$PEERS\"|" "$CONFIG"
sed -i 's/^minimum-gas-prices = ""/minimum-gas-prices = "0.1udvpn"/' "$APP"

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
  echo "   $TARGET keys add thedigitalempire --recover --keyring-backend $KEYRING --home $HOMEDIR"
fi

# === START NODE ===
exec "$TARGET" start --home "$HOMEDIR" --log_level info --moniker "$MONIKER"
