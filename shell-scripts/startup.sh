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

# Clone the h2ogpt_rg repository
echo "Cloning the h2ogpt_rg repository..."
git clone https://github.com/Royce-Geospatial-Consultants/h2ogpt_rg.git

# Clone the scaled-llm-deployment repository
echo "Cloning the scaled-llm-deployment repository"
git clone https://github.com/NickThompson42/scaled-llm-deployment.git

# Navigate into the repository directory
cd h2ogpt_rg

## Check if the ~/.bashrc_functions file exists and create it if it doesn't
if [ ! -f "$USER_HOME/.bashrc_functions" ]; then
    echo "Creating $USER_HOME/.bashrc_functions..."
    touch "$USER_HOME/.bashrc_functions"
    chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.bashrc_functions"
fi

# Append the docker_startup function to the ~/.bashrc_functions
echo "Appending docker_startup function to $USER_HOME/.bashrc_functions..."
cat << EOF >> "$USER_HOME/.bashrc_functions"
function docker_startup(){
    # make run_docker_compose executable
    sudo chmod +x $USER_HOME/scaled-llm-deployment/shell-scripts/run_docker_compose.sh
    sudo $USER_HOME/scaled-llm-deployment/shell-scripts/run_docker_compose.sh
}
EOF

# Source the ~/.bashrc_functions in the user's .bashrc if it's not already
if ! grep -q ".bashrc_functions" "$USER_HOME/.bashrc"; then
    echo "Sourcing $USER_HOME/.bashrc_functions in $USER_HOME/.bashrc..."
    echo "source $USER_HOME/.bashrc_functions" >> "$USER_HOME/.bashrc"
    chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.bashrc"
fi

echo -e "Installation complete."
echo -e "After reboot, run 'docker_startup' to initialize the docker container for the LLM."
echo -e "Please log out and log back in to apply the changes."

# Optional: Reboot the system
read -p "Do you want to reboot now? (y/n) " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
   sudo reboot
fi