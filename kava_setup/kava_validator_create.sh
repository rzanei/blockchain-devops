#!/bin/bash
set -e

TARGET="kavad"
HOMEDIR="$HOME/.${TARGET}"
NODE_RPC="https://kava-rpc.polkachu.com:443"  # Use a valid RPC endpoint
KEY_NAME="thedigitalempire"                  # <-- Replace with your key name
MONIKER="TheDigitalEmpire"                   # <-- Customize as needed
CHAIN_ID="kava_2222-10"                      # <-- Confirm latest chain ID
DELEGATION="10000000ukava"                  # 10 KAVA in microdenom
FEES="6000ukava"
COMMISSION_RATE="0.05"
COMMISSION_MAX_RATE="0.20"
COMMISSION_MAX_CHANGE_RATE="0.10"
MIN_SELF_DELEGATION="1"

echo "🚀 Creating Kava Validator..."

$TARGET tx staking create-validator \
  --amount "$DELEGATION" \
  --pubkey "$($TARGET tendermint show-validator --home "$HOMEDIR")" \
  --moniker "$MONIKER" \
  --chain-id "$CHAIN_ID" \
  --commission-rate "$COMMISSION_RATE" \
  --commission-max-rate "$COMMISSION_MAX_RATE" \
  --commission-max-change-rate "$COMMISSION_MAX_CHANGE_RATE" \
  --min-self-delegation "$MIN_SELF_DELEGATION" \
  --from "$KEY_NAME" \
  --gas auto \
  --gas-adjustment 1.3 \
  --fees "$FEES" \
  --keyring-backend file \
  --home "$HOMEDIR" \
  --node "$NODE_RPC" \
  -y

echo "✅ Validator creation transaction submitted."
