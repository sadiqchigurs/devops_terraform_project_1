#!/bin/bash

## Installation Reference: https://docs.docker.com/engine/install/ubuntu/ 

apt-get remove docker docker-engine docker.io containerd runc

apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install docker compose
apt-get install -y docker-compose

# Enable auto start on boot 
systemctl enable docker

# Add current user in the Docker group to avoid sudo
usermod -aG docker $(whoami)