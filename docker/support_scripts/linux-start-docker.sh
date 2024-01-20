#!/bin/bash

# Start Docker
sudo systemctl start docker

# Wait for Docker Desktop to start
timeout=30 # 30 seconds timeout
while ! docker system info > /dev/null 2>&1; do
    sleep 1
    timeout=$((timeout-1))
    if [ $timeout -eq 0 ]; then
        echo "[HTML]: <p>Timed out waiting for Docker Desktop to start.</p>"
        exit 1
    fi
done
