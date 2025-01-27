#!/bin/bash
ACCOUNTS=${1:-5}
AMOUNT=${2:-100}
KEYPAIR_DIR="$HOME/.solana-keypair/"
GENESIS_ACCOUNT_PATH="$KEYPAIR_DIR""account0"
echo "Funding generated accounts with SOL from the source wallet..."
for ((i=1; i<=ACCOUNTS; i++)); do
    PUBLIC_KEY=$(cat "$KEYPAIR_DIR""account$i/public_key.json")
    echo "Funding account $i with public key: $PUBLIC_KEY"
    solana transfer "$PUBLIC_KEY" $AMOUNT --keypair "$GENESIS_ACCOUNT_PATH/keypair" --allow-unfunded-recipient 
done