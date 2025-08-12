#!/bin/bash

INFO="\033[1;34m[INFO]\033[0m"
SUCCESS="\033[1;32m[SUCCESS]\033[0m"
ERROR="\033[1;31m[ERROR]\033[0m"

check_command() {
    command -v "$1" &> /dev/null
}

install_solana() {
    echo -e "$INFO Installing Solana CLI... ⏳"
    
    # Run the official Solana install script
    curl --proto '=https' --tlsv1.2 -sSfL https://raw.githubusercontent.com/solana-developers/solana-install/main/install.sh | bash

    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

    if check_command solana; then
        echo -e "$SUCCESS Solana CLI installed successfully! 🚀"
    else
        echo -e "$ERROR Solana installation failed. Please check the logs in ~/.local/share/solana/install. ❌"
        exit 1
    fi
}

install_anchor() {
    echo -e "$INFO Installing Anchor CLI... ⏳"
    
    # Install Anchor CLI using cargo
    cargo install --git https://github.com/coral-xyz/anchor anchor-cli --locked --force

    if check_command anchor; then
        echo -e "$SUCCESS Anchor CLI installed successfully! 🚀"
    else
        echo -e "$ERROR Anchor CLI installation failed. Ensure Rust and Solana CLI are installed correctly. ❌"
        exit 1
    fi
}

if check_command solana; then
    SOLANA_VERSION=$(solana --version)
    echo -e "$SUCCESS Solana CLI is already installed: $SOLANA_VERSION"
else
    install_solana
fi

if check_command anchor; then
    ANCHOR_VERSION=$(anchor --version)
    echo -e "$SUCCESS Anchor CLI is already installed: $ANCHOR_VERSION"
else
    install_anchor
fi

echo -e "\n$INFO Installed Versions:\n"

if check_command rustc; then
    RUST_VERSION=$(rustc --version)
    echo -e "🔹 Rust: $RUST_VERSION"
else
    echo -e "Rust is not installed."
fi

if check_command solana; then
    SOLANA_VERSION=$(solana --version)
    echo -e "🔹 Solana CLI: $SOLANA_VERSION"
else
    echo -e "Solana CLI is not installed."
fi

if check_command anchor; then
    ANCHOR_VERSION=$(anchor --version)
    echo -e "🔹 Anchor CLI: $ANCHOR_VERSION"
else
    echo -e "Anchor CLI is not installed."
fi

if check_command node; then
    NODE_VERSION=$(node -v)
    echo -e "🔹 Node.js: $NODE_VERSION"
else
    echo -e "Node.js is not installed."
fi

if check_command yarn; then
    YARN_VERSION=$(yarn -v)
    echo -e "🔹 Yarn: $YARN_VERSION"
else
    echo -e "Yarn is not installed."
fi

# Copy Solana binaries to $HOME/.blockchain-devops/solana
DEVOPS_DIR="$HOME/.blockchain-devops/solana"
mkdir -p "$DEVOPS_DIR"

if check_command solana-test-validator && check_command solana && check_command solana-keygen; then
    cp "$(command -v solana-test-validator)" "$DEVOPS_DIR" 2>/dev/null
    cp "$(command -v solana)" "$DEVOPS_DIR" 2>/dev/null
    cp "$(command -v solana-keygen)" "$DEVOPS_DIR" 2>/dev/null
    echo -e "$SUCCESS Solana binaries copied to $DEVOPS_DIR ✅"
else
    echo -e "$ERROR Failed to locate some Solana binaries. Ensure they are installed properly. ❌"
fi

echo -e "\n✅ Installation complete. Please add the following to your ~/.bashrc or ~/.zshrc to persist the PATH:"
echo -e "export PATH=\"$HOME/.local/share/solana/install/active_release/bin:\$PATH\""
echo -e "Then, run 'source ~/.bashrc' or 'source ~/.zshrc' to apply changes."