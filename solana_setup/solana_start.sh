#!/bin/bash

# Configuration
TARGET="solana"
KEYPAIR_DIR="$HOME/.solana-keypair"
ACCOUNTS=${1:-5}  # Default to 5 accounts if ACCOUNTS is not set
GENESIS_ACCOUNT_PATH="$KEYPAIR_DIR/account0"
HOST="localhost"
RPC_PORT=8899
WS_PORT=8900
FAUCET_PORT=9900

# Check if solana-keygen and solana-test-validator are installed
if ! command -v solana-keygen &> /dev/null; then
    echo "❌ solana-keygen not found. Please install the Solana CLI."
    echo "Run: sh -c \"\$(curl -sSfL https://release.solana.com/stable/install)\""
    exit 1
fi
if ! command -v solana-test-validator &> /dev/null; then
    echo "❌ solana-test-validator not found. Please install the Solana CLI."
    echo "Run: sh -c \"\$(curl -sSfL https://release.solana.com/stable/install)\""
    exit 1
fi

# Check write permissions for KEYPAIR_DIR
if [ -d "$KEYPAIR_DIR" ] && [ ! -w "$KEYPAIR_DIR" ]; then
    echo "❌ No write permission for $KEYPAIR_DIR. Attempting to fix..."
    sudo chown -R "$(whoami)":"$(whoami)" "$KEYPAIR_DIR"
    chmod -R u+rw "$KEYPAIR_DIR"
    if [ ! -w "$KEYPAIR_DIR" ]; then
        echo "❌ Failed to fix permissions for $KEYPAIR_DIR. Please run as the correct user or fix manually."
        exit 1
    fi
fi

# Ensure keypair directory exists and is populated
if [ -d "$KEYPAIR_DIR" ]; then
    echo "🔐 Keypair directory already exists, checking for valid keypairs..."
    for ((i=0; i<=ACCOUNTS; i++)); do
        ACCOUNT_DIR="$KEYPAIR_DIR/account$i"
        if [ ! -f "$ACCOUNT_DIR/keypair" ] || [ ! -f "$ACCOUNT_DIR/public_key.json" ]; then
            echo "🔧 Generating account $i..."
            if ! mkdir -p "$ACCOUNT_DIR" 2>/dev/null; then
                echo "❌ Failed to create directory $ACCOUNT_DIR: Permission denied"
                exit 1
            fi
            if ! SOLANA_KEYGEN_OUTPUT=$(solana-keygen new -o "$ACCOUNT_DIR/keypair" --no-passphrase 2>&1); then
                echo "❌ Failed to generate keypair for account $i: $SOLANA_KEYGEN_OUTPUT"
                exit 1
            fi
            MNEMONIC=$(echo "$SOLANA_KEYGEN_OUTPUT" | grep -A 1 "Save this seed phrase" | tail -n 1)
            if [ -z "$MNEMONIC" ]; then
                echo "❌ Failed to extract mnemonic for account $i"
                exit 1
            fi
            echo "$MNEMONIC" > "$ACCOUNT_DIR/mnemonic.json"
            if ! solana-keygen pubkey "$ACCOUNT_DIR/keypair" > "$ACCOUNT_DIR/public_key.json" 2>/dev/null; then
                echo "❌ Failed to generate public key for account $i"
                exit 1
            fi
            echo "🗝️ Account $i saved to $ACCOUNT_DIR"
        fi
    done
else
    echo "🚀 Generating new keypairs..."
    if ! mkdir -p "$KEYPAIR_DIR" 2>/dev/null; then
        echo "❌ Failed to create keypair directory: $KEYPAIR_DIR"
        exit 1
    fi
    for ((i=0; i<=ACCOUNTS; i++)); do
        echo "🔧 Generating account $i..."
        ACCOUNT_DIR="$KEYPAIR_DIR/account$i"
        if ! mkdir -p "$ACCOUNT_DIR" 2>/dev/null; then
            echo "❌ Failed to create directory $ACCOUNT_DIR: Permission denied"
            exit 1
        fi
        if ! SOLANA_KEYGEN_OUTPUT=$(solana-keygen new -o "$ACCOUNT_DIR/keypair" --no-passphrase 2>&1); then
            echo "❌ Failed to generate keypair for account $i: $SOLANA_KEYGEN_OUTPUT"
            exit 1
        fi
        MNEMONIC=$(echo "$SOLANA_KEYGEN_OUTPUT" | grep -A 1 "Save this seed phrase" | tail -n 1)
        if [ -z "$MNEMONIC" ]; then
            echo "❌ Failed to extract mnemonic for account $i"
            exit 1
        fi
        echo "$MNEMONIC" > "$ACCOUNT_DIR/mnemonic.json"
        if ! solana-keygen pubkey "$ACCOUNT_DIR/keypair" > "$ACCOUNT_DIR/public_key.json" 2>/dev/null; then
            echo "❌ Failed to generate public key for account $i"
            exit 1
        fi
        echo "🗝️ Account $i saved to $ACCOUNT_DIR"
    done
fi

echo "🎉 Existing Accounts:"
for ((i=0; i<=ACCOUNTS; i++)); do
    PUBLIC_KEY=$(cat "$KEYPAIR_DIR/account$i/public_key.json" 2>/dev/null || echo "Not found")
    if [ "$PUBLIC_KEY" == "Not found" ]; then
        echo "❌ Public key for account $i not found"
    else
        echo "🗝️ Account $i Public Key: $PUBLIC_KEY"
    fi
done

# Clean up test-ledger
echo "🧹 Cleaning up test-ledger..."
if ! rm -rf test-ledger 2>/dev/null; then
    echo "❌ Failed to clean test-ledger directory. Attempting to fix permissions..."
    sudo chown -R "$(whoami)":"$(whoami)" test-ledger
    chmod -R u+rw test-ledger
    rm -rf test-ledger
    if [ -d test-ledger ]; then
        echo "❌ Failed to remove test-ledger directory. Please remove it manually."
        exit 1
    fi
fi

# Check for port conflicts
for PORT in $RPC_PORT $WS_PORT $FAUCET_PORT; do
    if lsof -i :$PORT >/dev/null; then
        echo "❌ Port $PORT is already in use. Please free it or choose another port."
        lsof -i :$PORT
        exit 1
    fi
done

# Set Solana configuration
if ! solana config set --keypair "$GENESIS_ACCOUNT_PATH/keypair" --url "http://$HOST:$RPC_PORT" 2>/dev/null; then
    echo "❌ Failed to set Solana configuration"
    exit 1
fi

# Start the test validator and show logs in real-time
echo "🚀 Starting Solana test validator..."
solana-test-validator --rpc-port $RPC_PORT --faucet-port $FAUCET_PORT --reset
