#!/bin/bash

# Set any environment variables or preparation steps

echo "Starting Docker Compose to run LLM and ML applications..."

# Pull the latest images
docker-compose pull

# Build and start the containers
docker-compose up -d --build

echo "Containers are up and running. Access the application at http://localhost:8080"

# Additional commands for logs, stopping containers, etc.
