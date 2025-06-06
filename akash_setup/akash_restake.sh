#!/bin/bash
set -e

# === CONFIGURATION ===
TARGET="akash"
VALIDATOR_ADDRESS="akashvaloper1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  # <-- Replace this
WALLET_ADDRESS="akash1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"         # <-- Replace this
KEY_NAME="validator"                                                   # <-- Key name in keyring
NODE="https://rpc-akash.ecostake.com:443"
CHAIN_ID="akashnet-2"
KEYRING="file"
HOME_DIR="$HOME/.${TARGET}"
FEE="5000uakt"
GAS_ADJUSTMENT="1.3"

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
BAL_RAW=$($TARGET query bank balances "$WALLET_ADDRESS" --node "$NODE" -o json | jq -r '.balances[] | select(.denom == "uakt") | .amount')

if [[ -z "$BAL_RAW" || "$BAL_RAW" -le 1000000 ]]; then
  echo "⚠️ Not enough balance to re-stake. Available: ${BAL_RAW:-0} uakt"
  exit 0
fi

# === 3. Delegate (restake) rewards ===
RESTAKE_AMOUNT=$((BAL_RAW - 1000000))  # Leave 1 AKT buffer for fees

echo "🚀 Restaking $RESTAKE_AMOUNT uakt..."

$TARGET tx staking delegate "$VALIDATOR_ADDRESS" "${RESTAKE_AMOUNT}uakt" \
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
