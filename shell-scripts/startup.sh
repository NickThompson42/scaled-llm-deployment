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

# Remove duplicate entries for Docker repository
sudo sed -i '/download.docker.com\/linux\/ubuntu/d' /etc/apt/sources.list
sudo apt-get update

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
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
  && curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add - \
  && curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

# At the end of your NVIDIA driver and CUDA Toolkit installation sections
echo "Attempting to refresh the environment and load NVIDIA kernel modules..."

# Source the profile files to reload environment variables
source ~/.bashrc

# Try to load the NVIDIA kernel modules manually (common module names included, but yours might differ)
sudo modprobe nvidia
sudo modprobe nvidia_uvm
sudo modprobe nvidia_drm
sudo modprobe nvidia_modeset

# Check if NVIDIA drivers are now recognized
if nvidia-smi; then
    echo "NVIDIA drivers are active."
else
    echo "NVIDIA drivers are not responding. A reboot is recommended to ensure all changes take effect."
fi

# Detect GPU and install appropriate drivers and CUDA Toolkit
GPU_TYPE=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader)

if [[ "$GPU_TYPE" == *"Tesla T4"* ]]; then
    echo "Detected Tesla T4. Installing drivers and CUDA for Tesla T4..."
    # Install drivers for Tesla T4
    sudo apt -y install nvidia-utils-440-server
    # Replace with installation commands for Tesla T4 CUDA Toolkit
elif [[ "$GPU_TYPE" == *"A100"* ]]; then
    echo "Detected A100 GPU. Installing drivers and CUDA for A100..."
    # Install drivers for A100
    sudo apt-get -y install nvidia-headless-535-server nvidia-fabricmanager-535 nvidia-utils-535-server
    # Commands from developer recommendation for A100 CUDA installation
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
    sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
    wget https://developer.download.nvidia.com/compute/cuda/12.1.0/local_installers/cuda-repo-ubuntu2004-12-1-local_12.1.0-530.30.02-1_amd64.deb
    sudo dpkg -i cuda-repo-ubuntu2004-12-1-local_12.1.0-530.30.02-1_amd64.deb
    sudo cp /var/cuda-repo-ubuntu2004-12-1-local/cuda-*-keyring.gpg /usr/share/keyrings/
    sudo apt-get update
    sudo apt-get -y install cuda
    # Set up environment variables
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/local/cuda/lib64/" >> ~/.bashrc
    echo "export CUDA_HOME=/usr/local/cuda" >> ~/.bashrc
    echo "export PATH=\$PATH:/usr/local/cuda/bin/" >> ~/.bashrc
    source ~/.bashrc
else
    echo "Unsupported GPU type: $GPU_TYPE"
    exit 1
fi

# Clone the necessary repositories
echo "Cloning the repositories..."
git clone https://github.com/Royce-Geospatial-Consultants/h2ogpt_rg.git $USER_HOME/h2ogpt_rg
git clone https://github.com/NickThompson42/scaled-llm-deployment.git $USER_HOME/scaled-llm-deployment

# Set up bash functions for the user
echo "Setting up bash functions for user..."

# Create the ~/.bashrc_functions file if it doesn't exist
if [ ! -f "$USER_HOME/.bashrc_functions" ]; then
    touch "$USER_HOME/.bashrc_functions"
    chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.bashrc_functions"
fi

# Append the docker_startup function to the ~/.bashrc_functions
cat << EOF >> "$USER_HOME/.bashrc_functions"
function docker_startup(){
    # make run_docker_compose executable and run it
    sudo chmod +x $USER_HOME/scaled-llm-deployment/shell-scripts/run_docker_compose.sh
    sudo $USER_HOME/scaled-llm-deployment/shell-scripts/run_docker_compose.sh
}

function baseline(){
   # source the needed functions
   source $USER_HOME/.bashrc_functions
   # change dir to h2ogpt_rg
   cd $USER_HOME/h2ogpt_rg
   ls
   echo "Verify the files exist in h2ogpt_rg"
   sleep 10
   echo "Immediately after this message, use the 'docker_startup' command."
}
EOF

# Ensure the .bashrc sources the functions file
if ! grep -q ".bashrc_functions" "$USER_HOME/.bashrc"; then
    cat << EOF >> "$USER_HOME/.bashrc"
# Custom functions for enhanced bash experience
source \$HOME/.bashrc_functions
EOF
    chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.bashrc"
fi

echo -e " "
echo -e ">> Installation complete."
echo -e " "
echo -e ">>> After reboot, use command 'baseline'."
echo -e " "
echo -e ">>>> After reboot, run 'docker_startup' to initialize the docker container for the LLM."
echo -e " "
echo -e ">>>>> Please log out and log back in to apply the changes."

# Offer to reboot the system
read -p "Do you want to reboot now? (y/n) " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
   sudo reboot
fi
