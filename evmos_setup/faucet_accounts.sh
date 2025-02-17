#!/bin/bash

TARGET=${TARGET:-"evmos"}
HOMEDIR=${HOMEDIR:-"$HOME/.evmosd"}
CHAINID=${CHAIN_ID:-"${TARGET}_9000-1"}
KEYRING=${KEYRING:-"test"}
DENOM=${DENOM:-"aevmos"}
GAS_PRICE=${GAS_PRICE:-"700000000"}
FAUCET_AMOUNT=${FAUCET_AMOUNT:-"10000000000000"}
HOST_NODE=${HOST_NODE:-"127.0.0.1"}
HOST_RPC_PORT=${HOST_RPC_PORT:-"26657"}

# Commands
evmosd keys list --keyring-backend ${KEYRING} --node http://${HOST_NODE}:${HOST_RPC_PORT}

evmosd tx bank send evmos1j6m2w8sgccexpv0g2whdls0tdynfwl6etlcthv evmos1ckg040r6tnjfzfwm9skj67qhyqwh3qp4cy5qgn ${FAUCET_AMOUNT}${DENOM} --keyring-backend ${KEYRING} --chain-id ${CHAINID} --gas-prices ${GAS_PRICE}${DENOM} --node http://${HOST_NODE}:${HOST_RPC_PORT} -y 
sleep 3
evmosd tx bank send evmos1j6m2w8sgccexpv0g2whdls0tdynfwl6etlcthv evmos1qy47vryjvtu0exwp8q0ufelgper6ag4kxud4h0 ${FAUCET_AMOUNT}${DENOM} --keyring-backend ${KEYRING} --chain-id ${CHAINID} --gas-prices ${GAS_PRICE}${DENOM} --node http://${HOST_NODE}:${HOST_RPC_PORT} -y 
