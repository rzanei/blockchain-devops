#!/bin/bash
set -e

# === CONFIGURATION ===
TARGET="sentinelhub"
VALIDATOR_ADDRESS="sentvaloper1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  # <-- Replace this
WALLET_ADDRESS="sent1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"         # <-- Replace this
KEY_NAME="thedigitalempire"
NODE="https://sentinel-rpc.polkachu.com:443"
CHAIN_ID="sentinelhub-2"
KEYRING="file"
HOME_DIR="$HOME/.${TARGET}"
FEE="5000udvpn"
GAS_ADJUSTMENT="1.3"
DENOM="udvpn"
BUFFER_AMOUNT=1000000

echo "🔁 Starting restake process for $TARGET..."

# === 1. Withdraw rewards ===
echo "💰 Withdrawing rewards..."
$TARGET tx distribution withdraw-rewards "$VALIDATOR_ADDRESS" \
  --commission \
  --from "$KEY_NAME" \
  --chain-id "$CHAIN_ID" \
  --node "$NODE" \
  --keyring-backend "$KEYRING" \
  --home "$HOME_DIR" \
  --gas auto \
  --gas-adjustment "$GAS_ADJUSTMENT" \
  --fees "$FEE" \
  -y

sleep 10  # Wait for rewards to be processed

# === 2. Check wallet balance ===
echo "🔍 Fetching wallet balance..."
BAL_RAW=$($TARGET query bank balances "$WALLET_ADDRESS" --node "$NODE" -o json | jq -r ".balances[] | select(.denom == \"$DENOM\") | .amount")

if [[ -z "$BAL_RAW" || "$BAL_RAW" -le $BUFFER_AMOUNT ]]; then
  echo "⚠️ Not enough balance to re-stake. Available: ${BAL_RAW:-0} $DENOM"
  exit 0
fi

# === 3. Delegate (restake) rewards ===
RESTAKE_AMOUNT=$((BAL_RAW - BUFFER_AMOUNT))

echo "🚀 Restaking $RESTAKE_AMOUNT $DENOM..."

$TARGET tx staking delegate "$VALIDATOR_ADDRESS" "${RESTAKE_AMOUNT}${DENOM}" \
  --from "$KEY_NAME" \
  --chain-id "$CHAIN_ID" \
  --node "$NODE" \
  --keyring-backend "$KEYRING" \
  --home "$HOME_DIR" \
  --gas auto \
  --gas-adjustment "$GAS_ADJUSTMENT" \
  --fees "$FEE" \
  -y

echo "✅ Restake completed."
