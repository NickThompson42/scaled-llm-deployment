#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Update package list and upgrade the system
echo "Updating and upgrading the system..."
sudo apt-get update && sudo apt-get upgrade -y

# Install necessary base packages
echo "Installing base packages..."
sudo apt-get install -y git emacs nano vim curl wget software-properties-common pandoc apt-transport-https ca-certificates

# Add Docker’s official GPG key
echo "Adding Docker's official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add the Docker repository
echo "Adding the Docker repository..."
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Update package database with Docker packages from the newly added repo
echo "Updating package database..."
sudo apt-get update

# Install Docker
echo "Installing Docker..."
sudo apt-get install -y docker-ce

# Check if the docker group exists, create if it doesn't, and add the current user to it
echo "Adding current user to the docker group..."
sudo getent group docker || sudo groupadd docker
sudo usermod -aG docker ${USER}

# Enable and start Docker
echo "Enabling and starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

# Install NVIDIA Container Toolkit for Docker to access GPUs
echo "Installing NVIDIA Container Toolkit..."
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
  && curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add - \
  && curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

echo "Installation complete. Please log out and log back in to apply the changes."
