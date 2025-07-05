#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Is user root or not?
if [ "$EUID" -ne 0 ]; then
    SUDO='sudo'
else
    SUDO=''
fi

$SUDO apt-get update

# Install Docker
if ! command -v docker >/dev/null 2>&1; then
    $SUDO apt-get install ca-certificates curl gnupg lsb-release -y
    $SUDO mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null

    $SUDO apt-get update
    $SUDO apt-get install docker-ce docker-ce-cli containerd.io -y --no-install-recommends
else
    echo 'Docker is already installed!'
fi

# Install Docker Compose (v2 as plugin)
if ! docker compose version >/dev/null 2>&1; then
    $SUDO apt-get install docker-buildx-plugin docker-compose-plugin -y --no-install-recommends
else
    echo 'Docker Compose is already installed!'
fi

# Install Python
if ! command -v python3 >/dev/null 2>&1; then
    $SUDO apt-get install python3 -y --no-install-recommends
else
    echo 'Python is already installed!'
fi

# Install pip3
if ! command -v pip3 >/dev/null 2>&1; then
    $SUDO apt-get install python3-pip -y --no-install-recommends
else
    echo 'Python pip is already installed!'
fi

# Create virtual environment
if [ ! -d "venv" ]; then
    $SUDO apt-get install python3-venv -y
    python3 -m venv venv
else
    echo 'Virtual environment already exists.'
fi

# Activate virtual environment
source venv/bin/activate

# Install Django inside venv
if ! pip list | grep Django >/dev/null 2>&1; then
    pip install Django
else
    echo 'Django is already installed in virtual environment.'
fi

echo 'All packages have been installed successfully!'
