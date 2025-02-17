# Blockchain DevOps

This repository contains scripts and configurations to automate the setup of blockchain nodes using Docker and containerization. The focus is on providing streamlined setups for the following blockchains:

1. **Solana**
2. **Evmos**

## Contents

- **Dockerfile.linux-ubuntu-base**: A base Dockerfile for creating a containerized environment based on Ubuntu.
- **evmos_setup/**: Contains the Docker Compose file and startup script for setting up an Evmos node.
- **solana_setup/**: Contains the Docker Compose file and startup script for setting up a Solana node.

## Features

- **Automated Node Setup**: Easily deploy blockchain nodes with Docker for both Solana and Evmos.
- **Scalable and Replicable**: Set up nodes that can be easily scaled or replicated across environments.
- **Customizable Dockerfile**: Build customized blockchain setups tailored to specific needs.

## Prerequisites

Before you get started, make sure the following tools are installed on your machine:

- [Docker](https://www.docker.com/products/docker-desktop) (including Docker Compose)
- [Git](https://git-scm.com/)

## Getting Started

### 1. Clone the Repository

Start by cloning the repository:

```bash
git clone https://github.com/rzanei/blockchain-devops.git
cd blockchain-devops
