#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Find the home directory of the user who invoked sudo
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    echo "Could not determine the home directory of the original user." 1>&2
    exit 1
fi

echo "Starting system update and package installation..."

# Update package list and upgrade the system
sudo apt-get update && sudo apt-get upgrade -y

# Clean up unnecessary packages
sudo apt autoremove -y

# Install necessary base packages
sudo apt-get install -y git emacs nano vim curl wget software-properties-common pandoc apt-transport-https ca-certificates

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Ensure the user is in the Docker group
sudo usermod -aG docker $SUDO_USER

# Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install NVIDIA Container Toolkit for Docker to access GPUs
echo "Installing NVIDIA Container Toolkit..."
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

# Install the NVIDIA driver 440 for the server
echo "Installing NVIDIA driver 440..."
sudo apt-get install -y nvidia-driver-440-server

# Install CUDA Toolkit 12.3
echo "Installing CUDA Toolkit 12.3..."
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/12.3.0/local_installers/cuda-repo-ubuntu2004-12-3-local_12.3.0-545.23.06-1_amd64.deb
sudo dpkg -i cuda-repo-ubuntu2004-12-3-local_12.3.0-545.23.06-1_amd64.deb
sudo cp /var/cuda-repo-ubuntu2004-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/
sudo apt-get update
sudo apt-get -y install cuda-toolkit-12-3

# Add necessary environment variables to .bashrc
echo "Configuring environment variables..."
echo "export PATH=/usr/local/cuda-12.3/bin:$PATH" >> "$USER_HOME/.bashrc"
echo "export LD_LIBRARY_PATH=/usr/local/cuda-12.3/lib64:$LD_LIBRARY_PATH" >> "$USER_HOME/.bashrc"

# Source the profile files to reload environment variables
source "$USER_HOME/.bashrc"

# Load NVIDIA kernel modules
# echo "Loading NVIDIA kernel modules..."
# sudo modprobe nvidia
# sudo modprobe nvidia_uvm
# sudo modprobe nvidia_drm
# sudo modprobe nvidia_modeset

# Bypassing checks, going straight for the reboot option
echo "Installation complete and the VM will not reboot."
sleep 5
# read -p "Do you want to reboot now? (y/n) " -n 1 -r
# echo    # (optional) move to a new line
# if [[ $REPLY =~ ^[Yy]$ ]]
# then
sudo reboot # indent if you add the request for reboot back in.
# fi
