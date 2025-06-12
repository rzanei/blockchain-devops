#!/bin/bash

# -------------------------------------------
# Multi-Chain Binary Downloader Script
# Supports: akash, osmosis, evmos, kava
# Usage: ./get-node.sh <node> <version>
# Example: ./get-node.sh osmosis 29.0.1
# -------------------------------------------

NODE=${1:?❌ Node is required (e.g., osmosis, akash, evmos, kava)}
VERSION=${2:?❌ Version is required (e.g., 29.0.1)}

DEST_DIR="${HOME}/.blockchain-devops/${NODE}-${VERSION}"

# Check if the directory already exists
if [ ! -d "$DEST_DIR" ]; then
  case ${NODE} in
    akash)
      echo "📦 Downloading Akash version ${VERSION}..."
      FILE="${NODE}_${VERSION}_linux_amd64.zip"
      URL="https://github.com/akash-network/node/releases/download/v${VERSION}/${FILE}"
      wget -c "${URL}" -O "/tmp/${FILE}"
      mkdir -p "${DEST_DIR}"
      unzip -o "/tmp/${FILE}" -d "${DEST_DIR}"
      ;;

    osmosis)
      echo "📦 Downloading Osmosis version ${VERSION}..."
      FILE="osmosisd-${VERSION}-linux-amd64.tar.gz"
      URL="https://github.com/osmosis-labs/osmosis/releases/download/v${VERSION}/${FILE}"
      wget -c "${URL}" -O "/tmp/${FILE}"
      mkdir -p "${DEST_DIR}"
      tar -xzf "/tmp/${FILE}" -C "${DEST_DIR}"
      ;;

    evmos)
      echo "📦 Downloading Evmos version ${VERSION}..."
      FILE="${NODE}_${VERSION}_Linux_amd64.tar.gz"
      URL="https://github.com/evmos/evmos/releases/download/v${VERSION}/${FILE}"
      wget -c "${URL}" -O "/tmp/${FILE}"
      mkdir -p "${DEST_DIR}"
      tar -xzf "/tmp/${FILE}" -C "${DEST_DIR}"
      ;;

    kava)
      echo "📦 Downloading Kava version ${VERSION}..."
      FILE="kava-v${VERSION}-linux-amd64"
      URL="https://github.com/Kava-Labs/kava/releases/download/v${VERSION}/${FILE}"
      wget -c "${URL}" -O "/tmp/kava"
      mkdir -p "${DEST_DIR}"
      mv /tmp/kava "${DEST_DIR}/kavad"
      chmod +x "${DEST_DIR}/kavad"
      ;;

    *)
      echo "❌ Unsupported node: ${NODE}"
      echo "👉 Supported nodes: akash, osmosis, evmos, kava"
      exit 1
      ;;
  esac

  echo "✅ Binaries extracted to: ${DEST_DIR}"
else
  echo "✅ Directory ${DEST_DIR} already exists. Skipping download."
fi
