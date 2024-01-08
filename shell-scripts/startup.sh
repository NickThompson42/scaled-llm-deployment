#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Find the home directory of the user who invoked sudo
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6) || {
    echo "Could not determine the home directory of the original user." 1>&2
    exit 1
}

# Function to compare versions, returns 1 if first argument is greater
version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

echo "Starting system update and package installation..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq

REQUIRED_PKGS="git emacs nano vim curl wget software-properties-common pandoc apt-transport-https ca-certificates"
for pkg in $REQUIRED_PKGS; do
    if ! dpkg -l | grep -qw $pkg; then
        sudo apt-get install -y $pkg || { echo "Failed to install $pkg"; exit 1; }
    fi
done

# Clone repositories if not already cloned
[ ! -d "$USER_HOME/h2ogpt_rg" ] && git clone https://github.com/Royce-Geospatial-Consultants/h2ogpt_rg.git "$USER_HOME/h2ogpt_rg"
[ ! -d "$USER_HOME/scaled-llm-deployment" ] && git clone https://github.com/NickThompson42/scaled-llm-deployment.git "$USER_HOME/scaled-llm-deployment"

# Setup bash functions
if [ ! -f "$USER_HOME/.bashrc_functions" ]; then
    touch "$USER_HOME/.bashrc_functions" && chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.bashrc_functions"
fi

# Append docker_startup to .bashrc_functions if not present
if ! grep -q "docker_startup" "$USER_HOME/.bashrc_functions"; then
    cat << EOF >> "$USER_HOME/.bashrc_functions"
function docker_startup(){
    sudo chmod +x $USER_HOME/scaled-llm-deployment/shell-scripts/run_docker_compose.sh
    sudo $USER_HOME/scaled-llm-deployment/shell-scripts/run_docker_compose.sh
}
EOF
fi

# Append baseline to .bashrc_functions
cat << EOF >> "$USER_HOME/.bashrc_functions"
function baseline(){
    source $USER_HOME/.bashrc_functions
    cd $USER_HOME/h2ogpt_rg
    ls
    echo "Verify the files exist in h2ogpt_rg"
    sleep 10
    echo "Immediately after this message, use the 'docker_startup' command."
}
EOF

# Update .bashrc to source .bashrc_functions and set docker_startup
if ! grep -q ".bashrc_functions" "$USER_HOME/.bashrc"; then
    cat << EOF >> "$USER_HOME/.bashrc"
source \$HOME/.bashrc_functions
function ensure_docker_containers_running(){
    CONTAINER_COUNT=\$(docker ps | wc -l)
    [ "\$CONTAINER_COUNT" -eq 1 ] && docker_startup || echo "Docker containers already running."
}
cd $USER_HOME/h2ogpt_rg && docker pull gcr.io/vorvan/h2oai/h2ogpt-runtime:0.1.0 && ensure_docker_containers_running
EOF
fi

# Docker installation
if ! type "docker" > /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh && sudo usermod -aG docker "$SUDO_USER"
fi

# Docker Compose installation
if ! type "docker-compose" > /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# NVIDIA and CUDA installation
if ! type "nvidia-container-toolkit" > /dev/null; then
    distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
    sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-container-toolkit
    sudo systemctl restart docker
fi

NVIDIA_VERSION_INSTALLED=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)
NVIDIA_VERSION_REQUIRED="450"
if version_gt $NVIDIA_VERSION_REQUIRED $NVIDIA_VERSION_INSTALLED; then
    # Install NVIDIA driver and CUDA Toolkit
    echo "nvidia-driver-450-server nvidia-driver-450-server/license-type select Accept" | sudo debconf-set-selections
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-drivers
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y install cuda-toolkit-12-3
fi

# Setting environment variables for CUDA
get_installed_cuda_version() {
    type "nvcc" > /dev/null && nvcc --version | grep "release" | awk '{print $6}' | cut -c2- || echo "none"
}

# Define the required CUDA version
REQUIRED_CUDA_VERSION="12.3.2"

INSTALLED_CUDA_VERSION=$(get_installed_cuda_version)
if [ "$INSTALLED_CUDA_VERSION" != "none" ]; then
    CUDA_PATH_LINE="export PATH=/usr/local/cuda-$INSTALLED_CUDA_VERSION/bin:\$PATH"
    CUDA_LD_LIBRARY_LINE="export LD_LIBRARY_PATH=/usr/local/cuda-$INSTALLED_CUDA_VERSION/lib64:\$LD_LIBRARY_PATH"
    if ! grep -q "$CUDA_PATH_LINE" "$USER_HOME/.bashrc"; then
    echo "$CUDA_PATH_LINE" >> "$USER_HOME/.bashrc"
    fi
    if ! grep -q "$CUDA_LD_LIBRARY_LINE" "$USER_HOME/.bashrc"; then
        echo "$CUDA_LD_LIBRARY_LINE" >> "$USER_HOME/.bashrc"
    fi
    # [ ! grep -q "$CUDA_PATH_LINE" "$USER_HOME/.bashrc" ] && echo "$CUDA_PATH_LINE" >> "$USER_HOME/.bashrc"
    # [ ! grep -q "$CUDA_LD_LIBRARY_LINE" "$USER_HOME/.bashrc" ] && echo "$CUDA_LD_LIBRARY_LINE" >> "$USER_HOME/.bashrc"
fi

# Check if installed CUDA version is less than the required version
if [ "$INSTALLED_CUDA_VERSION" = "none" ] || version_gt $REQUIRED_CUDA_VERSION $INSTALLED_CUDA_VERSION; then
    echo "Required CUDA version is not installed. Installing CUDA Toolkit $REQUIRED_CUDA_VERSION..."
    # Add here the commands to install the required CUDA version
    # (e.g., adding repositories, setting up keys, apt-get install commands)
else
    echo "CUDA Toolkit $REQUIRED_CUDA_VERSION is already installed."
fi

# Finalizing
echo "Installation complete. The VM will now reboot."
sleep 5
sudo reboot
