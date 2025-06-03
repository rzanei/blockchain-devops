#!/bin/bash

# List of peers to check
PEERS=(
  "c13ccbfcd70626d42e048f2e79c02b775fcd7944@rpc-akash.whispernode.com:26656"
  "ef856e1ef57c4efc396a4e064d04d2f8f5b82e58@akash-rpc.polkachu.com:26656"
  "b3d4c223f832a6582be431060efb2a73903dc85b@85.237.193.106:26656"
  "66b74927d51888a25fe94bff2dfeaae125739f26@79.127.196.36:29656"
  "c58852a0c6ee1d1a68b76e5a54a9dbce895065d9@162.55.245.149:2140"
  "ebeea522e069f9037876e13f73310a601cfcff8a@95.179.212.224:26656"
  "0d8434034e645d305a0cf294e5670ee59e5e55f0@148.251.53.24:12856"
  "ef9221336be2f2cda18f3da3fd3733e2b96d03ee@54.157.107.51:26656"
  "b071f46ff940ea8acf7adbd93a7ea78498431a53@86.32.69.228:26656"
  "4de4f8839c4afdac12aa3c40b80788e720fcd324@164.152.163.191:26656"
  "9744e833f44218fb6f0646e2c37aae1331ce1efc@37.252.186.117:2000"
  "5a7599058e1bb208c6d8fe1e8e514d7bd6559980@146.59.81.92:29656"
  "be0a6315cbac3a368ff394d314514264d8447057@141.94.139.219:26856"
  "893429952c41a3485ea63b5af2886c91f090c065@65.108.76.28:12856"
  "7e1ec5bf83a17fc588c04beb807bba0daa4b54e7@207.180.193.18:26656"
)



echo "🔎 Checking peers..."
for peer in "${PEERS[@]}"; do
  node_id=$(echo "$peer" | cut -d@ -f1)
  address=$(echo "$peer" | cut -d@ -f2)
  ip=$(echo "$address" | cut -d: -f1)
  port=$(echo "$address" | cut -d: -f2)

  # Check if port is open (timeout 2s)
  nc -z -w2 "$ip" "$port" &> /dev/null
  if [ $? -eq 0 ]; then
    echo "$peer ✅"
  else
    echo "$peer ❌" >&2
  fi
done
