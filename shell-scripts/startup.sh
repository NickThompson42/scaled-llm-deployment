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

# Pre-configure selections for openssh-server and other packages
echo "openssh-server openssh-server/sshd_config_keep boolean true" | sudo debconf-set-selections
# Add similar lines for any other packages that require pre-configuration

# Update package list and upgrade the system non-interactively
sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq

# echo "Starting system update and package installation..."

# # Update package list and upgrade the system
# sudo apt-get update && sudo apt-get upgrade -y

# Clean up unnecessary packages
sudo apt autoremove -y

# Install necessary base packages
sudo apt-get install -y git emacs nano vim curl wget software-properties-common pandoc apt-transport-https ca-certificates

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

cat << EOF >> "$USER_HOME/.bashrc"

read -p "Would you like to run 'docker_startup'? [y/n] " answer && [[ "$answer" == [Yy] ]] && docker_startup
EOF

# Ensure the .bashrc sources the functions file
if ! grep -q ".bashrc_functions" "$USER_HOME/.bashrc"; then
    cat << EOF >> "$USER_HOME/.bashrc"
# Custom functions for enhanced bash experience
source \$HOME/.bashrc_functions
EOF
    chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.bashrc"
fi

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

######################################
## DOES NOT WORK BUT GOOD REFERENCE ##
######################################

# # Install NVIDIA Container Toolkit for Docker to access GPUs
# echo "Installing NVIDIA Container Toolkit..."
# distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
# curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
# curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
# sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
# sudo systemctl restart docker

# # Install the NVIDIA driver 440 for the server
# echo "Installing NVIDIA driver 440..."
# sudo apt-get install -y nvidia-driver-440-server

# # Install CUDA Toolkit 12.3
# echo "Installing CUDA Toolkit 12.3..."
# wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
# sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
# wget https://developer.download.nvidia.com/compute/cuda/12.3.0/local_installers/cuda-repo-ubuntu2004-12-3-local_12.3.0-545.23.06-1_amd64.deb
# sudo dpkg -i cuda-repo-ubuntu2004-12-3-local_12.3.0-545.23.06-1_amd64.deb
# sudo cp /var/cuda-repo-ubuntu2004-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/
# sudo apt-get update
# sudo apt-get -y install cuda-toolkit-12-2

# # Install nvtop for monitoring
# sud apt install nvtop -y

# Remove the old NVIDIA driver installation line
# echo "Installing NVIDIA driver 440..."
# sudo apt-get install -y nvidia-driver-440-server

###################################
## END, NEXT SECTION REPLACES IT ##
###################################

######################
## REPLACEMENT CODE ##
######################

# Install NVIDIA Container Toolkit for Docker to access GPUs
echo "Installing NVIDIA Container Toolkit..."
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

# Install CUDA Toolkit 12.3.2 and NVIDIA Drivers
echo "Installing CUDA Toolkit 12.3.2 and NVIDIA Drivers..."
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/12.3.2/local_installers/cuda-repo-ubuntu2004-12-3-local_12.3.2-545.23.08-1_amd64.deb
sudo dpkg -i cuda-repo-ubuntu2004-12-3-local_12.3.2-545.23.08-1_amd64.deb
sudo cp /var/cuda-repo-ubuntu2004-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/
sudo apt-get update

# Pre-configure selections and Install the NVIDIA driver
echo "Pre-configuring and Installing the NVIDIA driver..."
echo "nvidia-driver-450-server nvidia-driver-450-server/license-type select Accept" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-drivers

# Install CUDA Toolkit
echo "Installing CUDA Toolkit..."
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install cuda-toolkit-12-3

# Install nvtop for monitoring
echo "Installing nvtop for monitoring..."
sudo apt install nvtop -y

#########
## END ##
#########

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
echo "Installation complete and the VM will now reboot."
sleep 5
# read -p "Do you want to reboot now? (y/n) " -n 1 -r
# echo    # (optional) move to a new line
# if [[ $REPLY =~ ^[Yy]$ ]]
# then
sudo reboot # indent if you add the request for reboot back in.
# fi
