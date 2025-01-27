#!/bin/bash

# Configuration
TARGET="solana"
KEYPAIR_DIR="$HOME/.solana-keypair/"
ACCOUNTS=${1:-5}  # Default to 3 accounts if ACCOUNTS is not set
GENESIS_ACCOUNT_PATH="$KEYPAIR_DIR""account0"

if [ -d "$KEYPAIR_DIR" ]; then
    echo "Keypair directory already exists..."
else
    echo "Generating new keypairs..."
    rm -rf "$KEYPAIR_DIR"
    mkdir -p "$KEYPAIR_DIR"

    for ((i=0; i<=ACCOUNTS; i++)); do
        echo "Generating account $i..."
        ACCOUNT_DIR="$KEYPAIR_DIR""account$i"
        mkdir -p "$ACCOUNT_DIR"   

        SOLANA_KEYGEN_OUTPUT=$(solana-keygen new -o "$ACCOUNT_DIR/keypair" --no-passphrase)
        MNEMONIC=$(echo "$SOLANA_KEYGEN_OUTPUT" | sed -n '/Save this seed phrase to recover your new keypair:/,+1p' | tail -n 1)
        echo "$MNEMONIC" > "$ACCOUNT_DIR/mnemonic.json"
        solana-keygen pubkey "$ACCOUNT_DIR/keypair" > "$ACCOUNT_DIR/public_key.json"
        echo "Account $i saved to $ACCOUNT_DIR"
    done
fi

echo "Existing Accounts:"
for ((i=0; i<=ACCOUNTS; i++)); do
    PUBLIC_KEY=$(cat "$KEYPAIR_DIR""account$i/public_key.json")
    echo "Account $i Public Key: $PUBLIC_KEY"
done


rm -rf test-ledger

solana config set --keypair "$GENESIS_ACCOUNT_PATH/keypair"

solana-test-validator