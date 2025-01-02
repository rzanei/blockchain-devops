#!/bin/bash

NODE=${1:?Node is required}
VERSION=${2:?Version is required}

DEST_DIR="${HOME}/.blockchain-devops/${NODE}-${VERSION}"

# Check if the directory already exists
if [ ! -d "$DEST_DIR" ]; then
  case ${NODE} in
    evmos) 
      FILE="${NODE}_${VERSION}_Linux_amd64.tar.gz"
      URL="https://github.com/evmos/evmos/releases/download/v${VERSION}/${FILE}"
      wget -c "${URL}" -O "/tmp/${FILE}"

      # Create the destination directory and extract the tarball
      mkdir -p  "${DEST_DIR}"
      tar zxf "/tmp/${FILE}" -C "${DEST_DIR}"
      ;;
    *)
      # Exit with an error message if node is unsupported
      echo "Unsupported node: ${NODE}"
      exit 1
      ;;
  esac
else
  echo "Directory ${DEST_DIR} already exists. Skipping download."
fi
