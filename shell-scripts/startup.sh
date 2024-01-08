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

# Function to compare versions, returns 1 if first argument is greater
version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

echo "Starting system update and package installation..."

# Pre-configure selections for openssh-server and other packages
echo "openssh-server openssh-server/sshd_config_keep boolean true" | sudo debconf-set-selections
# Add similar lines for any other packages that require pre-configuration

# Update package list and upgrade the system non-interactively
sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq

# echo "Starting system update and package installation..."

# Clean up unnecessary packages
sudo apt autoremove -y

# Define required packages
REQUIRED_PKGS="git emacs nano vim curl wget software-properties-common pandoc apt-transport-https ca-certificates"

# Install only the missing packages
for pkg in $REQUIRED_PKGS; do
    if ! dpkg -l | grep -qw $pkg; then
        sudo apt-get install -y $pkg
    else
        echo "$pkg is already installed."
    fi
done

####################################
#### LAST WORKING FRESH INSTALL ###
####################################

# # Clone the necessary repositories
# echo "Cloning the repositories..."
# git clone https://github.com/Royce-Geospatial-Consultants/h2ogpt_rg.git $USER_HOME/h2ogpt_rg
# git clone https://github.com/NickThompson42/scaled-llm-deployment.git $USER_HOME/scaled-llm-deployment

############
### END ####
############

############
### NEW ####
############

# Check if repositories already cloned
if [ ! -d "$USER_HOME/h2ogpt_rg" ]; then
    git clone https://github.com/Royce-Geospatial-Consultants/h2ogpt_rg.git $USER_HOME/h2ogpt_rg
else
    echo "h2ogpt_rg already cloned."
fi

if [ ! -d "$USER_HOME/scaled-llm-deployment" ]; then
    git clone https://github.com/NickThompson42/scaled-llm-deployment.git $USER_HOME/scaled-llm-deployment
else
    echo "scaled-llm-deployment already cloned."
fi

############
### END ####
############


# Set up bash functions for the user
echo "Setting up bash functions for user..."

# Create the ~/.bashrc_functions file if it doesn't exist
if [ ! -f "$USER_HOME/.bashrc_functions" ]; then
    touch "$USER_HOME/.bashrc_functions"
    chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.bashrc_functions"
fi

####################################
#### LAST WORKING FRESH INSTALL ###
####################################

# # Append the docker_startup function to the ~/.bashrc_functions
# cat << EOF >> "$USER_HOME/.bashrc_functions"
# function docker_startup(){
#     # make run_docker_compose executable and run it
#     sudo chmod +x $USER_HOME/scaled-llm-deployment/shell-scripts/run_docker_compose.sh
#     sudo $USER_HOME/scaled-llm-deployment/shell-scripts/run_docker_compose.sh
# }

# function baseline(){
#    # source the needed functions
#    source $USER_HOME/.bashrc_functions
#    # change dir to h2ogpt_rg
#    cd $USER_HOME/h2ogpt_rg
#    ls
#    echo "Verify the files exist in h2ogpt_rg"
#    sleep 10
#    echo "Immediately after this message, use the 'docker_startup' command."
# }
# EOF

############
### END ####
############

##########################
#### NEW BASH STARTUP ####
##########################

# Change in .bashrc to prevent docker_startup from running on every shell start
cat << EOF >> "$USER_HOME/.bashrc"
# Custom command to start docker containers if not already running
function ensure_docker_containers_running(){
    CONTAINER_COUNT=\$(docker ps | wc -l)
    # If no containers are running, then start them
    if [ "\$CONTAINER_COUNT" -eq 1 ]; then
        docker_startup
    else
        echo "Docker containers already running."
    fi
}

# Change directory and conditionally run docker_startup at the start of every session
cd $USER_HOME/h2ogpt_rg && docker pull gcr.io/vorvan/h2oai/h2ogpt-runtime:0.1.0 && ensure_docker_containers_running
EOF

#############
#### END ####
#############

# Ensure the .bashrc sources the functions file
if ! grep -q ".bashrc_functions" "$USER_HOME/.bashrc"; then
    cat << EOF >> "$USER_HOME/.bashrc"
# Custom functions for enhanced bash experience
source \$HOME/.bashrc_functions
EOF
    chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.bashrc"
fi

cat << EOF >> "$USER_HOME/.bashrc"
# Change directory and run docker_startup at the start of every session
cd $USER_HOME/h2ogpt_rg && docker pull gcr.io/vorvan/h2oai/h2ogpt-runtime:0.1.0
 && docker_startup
EOF

################
#### DOCKER ####
################

# <<<<< OLD DOCKER >>>>>
# # Install Docker
# echo "Installing Docker..."
# curl -fsSL https://get.docker.com -o get-docker.sh
# sudo sh get-docker.sh

# # Ensure the user is in the Docker group
# sudo usermod -aG docker $SUDO_USER

# # Install Docker Compose
# echo "Installing Docker Compose..."
# sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# sudo chmod +x /usr/local/bin/docker-compose
# <<<<< END OLD DOCKER >>>>>

# >>>>> NEW DOCKER <<<<<

# Check for Docker and install if not found
if ! type "docker" > /dev/null; then
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  sudo usermod -aG docker $SUDO_USER
else
  echo "Docker is already installed."
fi

# Check for Docker Compose and install if not found
if ! type "docker-compose" > /dev/null; then
  sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
else
  echo "Docker Compose is already installed."
fi

# >>>>> END NEW DOCKER <<<<<

#############
#### END ####
#############

#########################
#### NVIDIA AND CUDA ####
#########################

# <<<<< OLD NVIDIA AND CUDA >>>>>

# # Install NVIDIA Container Toolkit for Docker to access GPUs
# echo "Installing NVIDIA Container Toolkit..."
# distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
# curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
# curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
# sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-container-toolkit
# sudo systemctl restart docker

# # Install CUDA Toolkit 12.3.2 and NVIDIA Drivers
# echo "Installing CUDA Toolkit 12.3.2 and NVIDIA Drivers..."
# wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
# sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
# wget https://developer.download.nvidia.com/compute/cuda/12.3.2/local_installers/cuda-repo-ubuntu2004-12-3-local_12.3.2-545.23.08-1_amd64.deb
# sudo dpkg -i cuda-repo-ubuntu2004-12-3-local_12.3.2-545.23.08-1_amd64.deb
# sudo cp /var/cuda-repo-ubuntu2004-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/
# sudo apt-get update

# # Pre-configure selections and Install the NVIDIA driver
# echo "Pre-configuring and Installing the NVIDIA driver..."
# echo "nvidia-driver-450-server nvidia-driver-450-server/license-type select Accept" | sudo debconf-set-selections
# sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-drivers

# # Install CUDA Toolkit
# echo "Installing CUDA Toolkit..."
# sudo DEBIAN_FRONTEND=noninteractive apt-get -y install cuda-toolkit-12-3

# <<<<< END OLD NVIDIA AND CUDA >>>>>

# >>>>> NEW NVIDIA AND CUDA <<<<<

# Check for NVIDIA Container Toolkit and install if not found
if ! type "nvidia-container-toolkit" > /dev/null; then
    echo "NVIDIA Container Toolkit not found. Installing..."
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
    sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-container-toolkit
    sudo systemctl restart docker
else
    echo "NVIDIA Container Toolkit is already installed."
fi

# Check NVIDIA driver version and install if not matching
NVIDIA_VERSION_INSTALLED=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)
NVIDIA_VERSION_REQUIRED="450"
if version_gt $NVIDIA_VERSION_REQUIRED $NVIDIA_VERSION_INSTALLED; then
    echo "Installing required NVIDIA driver and CUDA Toolkit..."

    # Pre-configure selections for the NVIDIA driver
    echo "nvidia-driver-450-server nvidia-driver-450-server/license-type select Accept" | sudo debconf-set-selections

    # Add the CUDA repository and key
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
    sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
    wget https://developer.download.nvidia.com/compute/cuda/12.3.2/local_installers/cuda-repo-ubuntu2004-12-3-local_12.3.2-545.23.08-1_amd64.deb
    sudo dpkg -i cuda-repo-ubuntu2004-12-3-local_12.3.2-545.23.08-1_amd64.deb
    sudo cp /var/cuda-repo-ubuntu2004-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/
    sudo apt-get update

    # Install the NVIDIA driver and CUDA Toolkit
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-drivers
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y install cuda-toolkit-12-3
else
    echo "Required NVIDIA driver is already installed."
fi

# Define the required CUDA version
REQUIRED_CUDA_VERSION="12.3.2"

# Function to extract the version of installed CUDA
get_installed_cuda_version() {
    if type "nvcc" > /dev/null; then
        nvcc --version | grep "release" | awk '{print $6}' | cut -c2-
    else
        echo "none"
    fi
}

# Get the installed CUDA version
INSTALLED_CUDA_VERSION=$(get_installed_cuda_version)

# Compare the installed CUDA version with the required version
if version_gt $REQUIRED_CUDA_VERSION $INSTALLED_CUDA_VERSION; then
    echo "Installing CUDA Toolkit $REQUIRED_CUDA_VERSION..."

    # Add the repository and install the CUDA Toolkit
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
    sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
    wget https://developer.download.nvidia.com/compute/cuda/$REQUIRED_CUDA_VERSION/local_installers/cuda-repo-ubuntu2004-$REQUIRED_CUDA_VERSION-local_$REQUIRED_CUDA_VERSION-545.23.08-1_amd64.deb
    sudo dpkg -i cuda-repo-ubuntu2004-$REQUIRED_CUDA_VERSION-local_$REQUIRED_CUDA_VERSION-545.23.08-1_amd64.deb
    sudo cp /var/cuda-repo-ubuntu2004-$REQUIRED_CUDA_VERSION-local/cuda-*-keyring.gpg /usr/share/keyrings/
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y install cuda-toolkit-12-3
else
    echo "Required CUDA Toolkit $REQUIRED_CUDA_VERSION is already installed."
fi

# >>>>> END NEW NVIDIA AND CUDA <<<<<

# Install nvtop for monitoring
echo "Installing nvtop for monitoring..."
sudo apt install nvtop -y

#############
#### END ####
#############

####################################
#### CONFIGURATINO AND EVN VARS ####
####################################

# <<<<< OLD CONFIG AND ENV VARS >>>>>
# Add necessary environment variables to .bashrc
# echo "Configuring environment variables..."
# echo "export PATH=/usr/local/cuda-12.3/bin:$PATH" >> "$USER_HOME/.bashrc"
# echo "export LD_LIBRARY_PATH=/usr/local/cuda-12.3/lib64:$LD_LIBRARY_PATH" >> "$USER_HOME/.bashrc"

# <<<<< END OLD CONFIG AND ENV VARS >>>>>

# >>>>> NEW CONFIG AND ENV VARS <<<<<

# Get the installed CUDA version
INSTALLED_CUDA_VERSION=$(get_installed_cuda_version)

# Check and append only if the entry is not already in .bashrc
if [ "$INSTALLED_CUDA_VERSION" != "none" ]; then
    # Set CUDA-related environment variables
    CUDA_PATH_LINE="export PATH=/usr/local/cuda-$INSTALLED_CUDA_VERSION/bin:\$PATH"
    CUDA_LD_LIBRARY_LINE="export LD_LIBRARY_PATH=/usr/local/cuda-$INSTALLED_CUDA_VERSION/lib64:\$LD_LIBRARY_PATH"

    if ! grep -q "$CUDA_PATH_LINE" "$USER_HOME/.bashrc"; then
        echo "$CUDA_PATH_LINE" >> "$USER_HOME/.bashrc"
    fi

    if ! grep -q "$CUDA_LD_LIBRARY_LINE" "$USER_HOME/.bashrc"; then
        echo "$CUDA_LD_LIBRARY_LINE" >> "$USER_HOME/.bashrc"
    fi
else
    echo "CUDA is not installed. Skipping setting PATH and LD_LIBRARY_PATH."
fi

# >>>>> END NEW CONFIG AND ENV VARS <<<<<

# Source the profile files to reload environment variables
source "$USER_HOME/.bashrc"


#############
#### END ####
#############

# Bypassing checks, going straight for the reboot option
echo "Installation complete and the VM will now reboot."
sleep 5
# read -p "Do you want to reboot now? (y/n) " -n 1 -r
# echo    # (optional) move to a new line
# if [[ $REPLY =~ ^[Yy]$ ]]
# then
sudo reboot # indent if you add the request for reboot back in.
# fi
