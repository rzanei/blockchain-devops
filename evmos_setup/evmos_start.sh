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

# ${TARGET}d config chain-id $CHAINID --home "$HOMEDIR"
# ${TARGET}d config keyring-backend $KEYRING --home "$HOMEDIR"
${TARGET}d init $MONIKER --chain-id $CHAINID --home "$HOMEDIR"

# Created account "genesis" 
echo "track ocean bridge rain officer snake active pizza narrow elbow umbrella stable moon travel knee fresh order yellow bridge" | ${TARGET}d keys add genesis --recover --keyring-backend $KEYRING --home "$HOMEDIR"
# Created account "alice" 
echo "piano horse wagon scent tiny rough angle drum oven summer cable traffic urban loud fresh camp" | ${TARGET}d keys add alice --recover --keyring-backend $KEYRING --home "$HOMEDIR"
# Created account "bob" 
echo "math orange bold table sketch winner fashion storm road pin eagle cake quiet star glove mirror" | ${TARGET}d keys add bob --recover --keyring-backend $KEYRING --home "$HOMEDIR"


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
sed -i '/\[rpc\]/,/laddr = "tcp:\/\/127.0.0.1:26657"/s/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' $CONFIG

sed -i '/\[api\]/,/enable = false/s/enable = false/enable = true/' $APP
sed -i '/\[json-rpc\]/,/enable = false/s/enable = false/enable = true/' $APP
sed -i 's/address = "127.0.0.1:8545"/address = "0.0.0.0:8545"/g' $APP
sed -i '/\[json-rpc\]/,/api = "eth,net,web3"/s/api = "eth,net,web3"/api = "eth,txpool,personal,net,debug,web3"/' $APP
sed -i '/\[grpc-web\]/,/enable = false/s/enable = false/enable = true/' $APP
sed -i '/\[grpc\]/,/enable = false/s/enable = false/enable = true/' $APP
sed -i '/\[api\]/,/enabled-unsafe-cors = false/s/enabled-unsafe-cors = false/enabled-unsafe-cors = true/' $APP
sed -i '/cors_allowed_origins = \[\]/s/cors_allowed_origins = \[\]/cors_allowed_origins = ["*"]/' $CONFIG

${TARGET}d add-genesis-account "genesis" "300000000000000000000000000$DENOM" --keyring-backend test --home "$HOMEDIR"

amount_to_claim=0
total_supply=$(echo "300000000000000000000000000 + $amount_to_claim" | bc)
jq -r --arg total_supply "$total_supply" '.app_state["bank"]["supply"][0]["amount"]=$total_supply' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
jq -r --arg DENOM "$DENOM" '.app_state["bank"]["supply"][0]["denom"]=$DENOM' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

${TARGET}d gentx "genesis" 1000000000000000000000$DENOM --keyring-backend $KEYRING --chain-id $CHAINID --home "$HOMEDIR"
${TARGET}d collect-gentxs --home "$HOMEDIR"
${TARGET}d validate-genesis --home "$HOMEDIR"

${TARGET}d start \
  --chain-id $CHAINID \
  --api.enable \
  --rpc.pprof_laddr "127.0.0.1:6060" \
  --grpc.address "0.0.0.0:9090" \
  --json-rpc.ws-address "0.0.0.0:8546" \
  --fees 7aevmos \
  --home "$HOMEDIR"