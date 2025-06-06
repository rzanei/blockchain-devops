#!/bin/bash
set -e

TARGET="akash"
HOMEDIR="$HOME/.${TARGET}"
NODE_RPC="https://rpc-akash.ecostake.com:443"
KEY_NAME="thedigitalempire"
MONIKER="TheDigitalEmpire"
CHAIN_ID="akashnet-2"
DELEGATION="60000000uakt"
FEES="6000uakt"
COMMISSION_RATE="0.05"
COMMISSION_MAX_RATE="0.20"
COMMISSION_MAX_CHANGE_RATE="0.10"
MIN_SELF_DELEGATION="1"

echo "🚀 Creating Akash Validator..."

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
