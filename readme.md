# Blockchain DevOps

This repository contains scripts and configurations to set up blockchain nodes using Docker and containerization. 
The project currently focuses on automating the setup for:
1) **Evmos**
2) **...**

## Contents

- **Dockerfile.linux-ubuntu-base**: A base Dockerfile for setting up a containerized environment based on Ubuntu.
- **evmos_setup/**: Contains Docker Compose file and startup script to set up an Evmos node.
- **lotus_setup/**: Contains Docker Compose file and startup script to set up a Lotus node.

## Features

- Automated node setup for blockchain environments using Docker.
- Easily scalable and replicable setups to run blockchain nodes.
- Customizable Dockerfile to create custom blockchain setups.

## Prerequisites

Before using this repository, ensure you have the following tools installed:

- [Docker](https://www.docker.com/products/docker-desktop) (including Docker Compose)
- [Git](https://git-scm.com/)

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/blockchain-devops.git
cd blockchain-devops
```
### 2. Navigate the Desidered Setup
- Select the desidered folder and explore the readme.md file and follow the setup instructions.

### Get Binary Examples
```bash
# Get lotus
./get-binary.sh lotus 1.31.0
```
