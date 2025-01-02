
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



