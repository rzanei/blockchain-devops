#!/bin/bash

set -e

TARGET="evmos"
HOMEDIR="$HOME/.evmosd"
CHAINID=${CHAIN_ID:-${TARGET}_9000-1}
DENOM="aevmos"

LOGLEVEL="info"
MONIKER=${CHAINID}
GENESIS=$HOMEDIR/config/genesis.json
TMP_GENESIS=$HOMEDIR/config/tmp_genesis.json
CONFIG=$HOMEDIR/config/config.toml
APP=$HOMEDIR/config/app.toml
KEYRING=test


rm -rf $HOMEDIR/

${TARGET}d config chain-id $CHAINID --home "$HOMEDIR"
${TARGET}d config keyring-backend $KEYRING --home "$HOMEDIR"
${TARGET}d init $MONIKER --chain-id $CHAINID --home "$HOMEDIR"

# Created account "genesis" 
echo "acid orphan sting arm attract shallow tiny begin never patient ethics elbow stove middle lady honey undo news observe problem number frozen gasp leg" | ${TARGET}d keys add genesis --recover --keyring-backend $KEYRING --home "$HOMEDIR"
# Created account "alice" 
echo "caution also galaxy match upset cheap slow aisle alley credit place share run shoe oxygen pole arrow sauce clip plunge defy absorb car concert" | ${TARGET}d keys add alice --recover --keyring-backend $KEYRING --home "$HOMEDIR"
# Created account "bob" 
echo "endless suspect clump job wagon control wonder project leave dream vendor inform cry tobacco lab youth prison cereal absurd bulb toy student tissue cabbage" | ${TARGET}d keys add bob --recover --keyring-backend $KEYRING --home "$HOMEDIR"


jq -r --arg DENOM "$DENOM" '.app_state["staking"]["params"]["bond_denom"]=$DENOM' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
jq -r --arg DENOM "$DENOM" '.app_state["crisis"]["constant_fee"]["denom"]=$DENOM' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
jq -r --arg DENOM "$DENOM" '.app_state["gov"]["deposit_params"]["min_deposit"][0]["denom"]=$DENOM' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
jq -r --arg DENOM "$DENOM" '.app_state["inflation"]["params"]["mint_denom"]=$DENOM' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
jq -r --arg DENOM "$DENOM" '.app_state["mint"]["params"]["mint_denom"]=$DENOM' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
jq -r --arg DENOM "$DENOM" '.app_state["claims"]["params"]["claims_denom"]=$DENOM' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

# Set gas limit in genesis
jq '.consensus_params["block"]["max_gas"]="10000000"' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

sed -i 's/create_empty_blocks = true/create_empty_blocks = false/g' $CONFIG
sed -i 's/seeds = ".*"/seeds = ""/g' $CONFIG
sed -i 's/size = 5000/size = 10000/g' $CONFIG
sed -i '/\[api\]/,/enable = false/s/enable = false/enable = true/' $APP

${TARGET}d add-genesis-account "genesis" "300000000000000000000000000$DENOM" --keyring-backend test --home "$HOMEDIR"

amount_to_claim=0
total_supply=$(echo "300000000000000000000000000 + $amount_to_claim" | bc)
jq -r --arg total_supply "$total_supply" '.app_state["bank"]["supply"][0]["amount"]=$total_supply' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
jq -r --arg DENOM "$DENOM" '.app_state["bank"]["supply"][0]["denom"]=$DENOM' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

${TARGET}d gentx "genesis" 1000000000000000000000$DENOM --keyring-backend $KEYRING --chain-id $CHAINID --home "$HOMEDIR"
${TARGET}d collect-gentxs --home "$HOMEDIR"
${TARGET}d validate-genesis --home "$HOMEDIR"

${TARGET}d start \
  --chain-id $CHAINID 
  --api.enable --json-rpc.api eth,txpool,personal,net,debug,web3 --json-rpc.enable true --grpc-web.enable true --grpc.enable true \
  --rpc.laddr "tcp://0.0.0.0:26657" \
  --rpc.pprof_laddr "127.0.0.1:6060" \
  --p2p.laddr "0.0.0.0:26656" \
  --grpc.address "0.0.0.0:9090" \
  --json-rpc.address "0.0.0.0:8545" \
  --json-rpc.ws-address "0.0.0.0:8546" \
  --fees 7aevmos \
  --home "$HOMEDIR"