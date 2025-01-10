
## Evmos Node Setup

**evmos_setup** : This directory contains a Docker Compose file and a startup script to quickly launch an Evmos node in a containerized environment.


#### Setup the Desidered node:

0) Make sure you have the docker base image buit correctly.
if is the first time running the setup, use this command from the root folder top build the base image:
```bash
docker build -f Dockerfile.linux-ubuntu-base -t linux-ubuntu-base:0.0.1 .
```

1) Use the get-binary.sh script to get the specific node:
```bash
# Example
./get-binary.sh "evmos" "20.0.0"
```

2) Setup env
- In each setup folder there is a .env file containing the environment variables, make sure is the same version you dowloaded
```bash
# Example
NODE_VERSION=20.0.0
```

3) Setup & Deploy
- Browse the desidered folder and deploy the infrastructure
```bash
# Example
cd evmos_setup
docker compose up -d
```

4) Check Pod Logs
```bash
# Example of Output 
5:45PM INF executed block app_hash=694E1298928654FF593CD722286F51FC372561FC48B97F81D3FDCB410F07A0BC height=4 module=state server=node
5:45PM INF committed state block_app_hash=761A5A70A8938FC5BEF99A5BB406FD32281EF4B2FDFED7CB9CB08562D0607829 height=4 module=state server=node
5:45PM INF indexed block events height=4 module=txindex server=node 
```

# Useful Evmos Commands

List keys (address, name and relative data)
```bash
 evmosd keys list --home $HOME/.evmosd/ --keyring-backend test

# Example of Output
- address: evmos1ckg040r6tnjfzfwm9skj67qhyqwh3qp4cy5qgn
  name: alice
  pubkey: '{"@type":"/ethermint.crypto.v1.ethsecp256k1.PubKey","key":"A+H/2of63e1x/VYQYac+SfCOTNjTjBTOHXsasGBFE2bY"}'
  type: local
- address: evmos1qy47vryjvtu0exwp8q0ufelgper6ag4kxud4h0
  name: bob
  pubkey: '{"@type":"/ethermint.crypto.v1.ethsecp256k1.PubKey","key":"AogLOh9fg8vq6TDvJtVJs0inTyLGm7I6kHyHwsLiT8Hn"}'
  type: local
- address: evmos1j6m2w8sgccexpv0g2whdls0tdynfwl6etlcthv
  name: genesis
  pubkey: '{"@type":"/ethermint.crypto.v1.ethsecp256k1.PubKey","key":"AlT+mvXrSgcOsDRNy236zcaA/K4BD3T1RyKdKrT+zjPv"}'
  type: local
```

List debug addr (Address hex, Address bytes)
```bash
 evmosd debug addr evmos1ckg040r6tnjfzfwm9skj67qhyqwh3qp4cy5qgn

# Example of Output
Address bytes: [197 144 250 188 122 92 228 145 37 219 44 45 45 120 23 32 29 120 128 53]
Address hex: 0xc590FAbc7a5CE49125DB2c2d2D7817201D788035
```

Fund address from genesis: (TODO: script automation to autofund)
```bash
 evmosd tx bank send evmos1j6m2w8sgccexpv0g2whdls0tdynfwl6etlcthv evmos1ckg040r6tnjfzfwm9skj67qhyqwh3qp4cy5qgn 10000000000000aevmos --keyring-backend test --chain-id evmos_9000-1 --gas-prices 700000000aevmos -y 

# Example of Output
code: 0
codespace: ""
data: ""
events: []
gas_used: "0"
gas_wanted: "0"
height: "0"
info: ""
logs: []
raw_log: ""
timestamp: ""
tx: null
txhash: 3B2EFFC5D9DA13063A4A70529CD7DDC4B974C296E5FCB22AD134DD522C539167
```