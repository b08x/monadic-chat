#!/bin/bash

export SELENIUM_IMAGE="selenium/standalone-chrome:latest"

# Define the path to the root directory
ROOT_DIR=$(dirname "$0")

# Define the path to the home directory
HOME_DIR=$(eval echo ~${SUDO_USER})

# Define the full path to docker-compose
if [[ "$(uname -s)" == "Darwin"* ]]; then
  DOCKER=/usr/local/bin/docker
  if [[ $(uname -m) == "arm64" ]]; then
    export SELENIUM_IMAGE="seleniarm/standalone-chromium:latest"
  fi
else
  DOCKER=docker
fi

# Define the paths to the support scripts
MAC_SCRIPT="${ROOT_DIR}/services/support_scripts/mac-start-docker.sh"
WSL2_SCRIPT="${ROOT_DIR}/services/support_scripts/wsl2-start-docker.sh"
LINUX_SCRIPT="${ROOT_DIR}/services/support_scripts/linux-start-docker.sh"

# in case this script is run inside a docker container
if [ -f "/.dockerenv" ]; then
  if [ ! -f "/monadic/data/.env" ]; then
    mkdir -p "/monadic/data"
    touch "/monadic/data/.env"
  fi
# in case this script is run outside a docker container
else
  if [ ! -f "$HOME_DIR/monadic/data/.env" ]; then
    mkdir -p "$HOME_DIR/monadic/data"
    touch "$HOME_DIR/monadic/data/.env"
  fi
fi

function start_docker {
  # Determine the operating system
  case "$(uname -s)" in
    Darwin)
      # macOS
      sh "$MAC_SCRIPT"
      ;;
    Linux)
      # Linux
      if grep -q microsoft /proc/version; then
        # WSL2
        sh "$WSL2_SCRIPT"
      else
        # Native Linux
        sh "$LINUX_SCRIPT"
      fi
      ;;
    *)
      echo "Unsupported operating system: $(uname -s)"
      exit 1
      ;;
  esac
}

function build_docker_compose {
  start_docker
  $DOCKER compose -f "$ROOT_DIR/services/docker-compose.yml" build --no-cache
}

function start_docker_compose {
  start_docker

  # Check if the Docker image and container exist
  if $DOCKER images | grep -q "monadic-chat"; then
    if $DOCKER container ls --all | grep -q "monadic-chat"; then
      echo "[HTML]: <p>Monadic Chat image and container found.</p>"
      sleep 1
      echo "[HTML]: <p>Starting Monadic Chat container . . .</p>"
      $DOCKER container start monadic-chat-pgvector-container >/dev/null
      $DOCKER container start monadic-chat-selenium-container >/dev/null
      $DOCKER container start monadic-chat-python-container >/dev/null
      $DOCKER container start monadic-chat-ruby-container >/dev/null
    else
      echo "[HTML]: <p>Monadic Chat Docker image exists. Building Monadic Chat container. Please wait . . .</p>"
      $DOCKER compose -f "$ROOT_DIR/services/docker-compose.yml" -p "monadic-chat-container" up -d
    fi
  else
    echo "[IMAGE NOT FOUND]"
    sleep 1
    echo "[HTML]: <p>Building Monadic Chat Docker image. This may take a while . . .</p>"
    build_docker_compose
    echo "[HTML]: <p>Starting Monadic Chat Docker image . . .</p>"
    $DOCKER compose -f "$ROOT_DIR/services/docker-compose.yml" -p "monadic-chat-container" up -d

    # periodically check if the image is ready
    while true; do
      if $DOCKER images | grep -q "monadic-chat"; then
        break
      fi
      sleep 1
    done
  fi
}

function down_docker_compose {
  $DOCKER compose -f "$ROOT_DIR/services/docker-compose.yml" down
  # remove unused docker volumes created by docker-compose
  $DOCKER volume prune -f
}

# Define a function to stop Docker Compose
function stop_docker_compose {
  $DOCKER container stop monadic-chat-ruby-container >/dev/null
  $DOCKER container stop monadic-chat-pgvector-container >/dev/null
  $DOCKER container stop monadic-chat-python-container >/dev/null
  $DOCKER container stop monadic-chat-selenium-container >/dev/null
}

# Define a function to import the database contents from an external file
function import_database {
  sh "${ROOT_DIR}/services/support_scripts/import_vector_db.sh"
}

# Define a function to export the database contents to an external file
function export_database {
  sh "${ROOT_DIR}/services/support_scripts/export_vector_db.sh"
}

# Download the latest version of Monadic Chat and rebuild the Docker image
function update_monadic {
  # Stop the Docker Compose services
  $DOCKER compose -f "$ROOT_DIR/services/docker-compose.yml" down

  # Move to `ROOT_DIR` and download the latest version of Monadic Chat 
  cd "$ROOT_DIR" && git pull origin main

  # Build and start the Docker Compose services
  $DOCKER compose -f "$ROOT_DIR/services/docker-compose.yml" build --no-cache
}

# Remove the Docker image and container
function remove_containers {
  # Stop the Docker Compose services
  $DOCKER compose -f "$ROOT_DIR/services/docker-compose.yml" down

  if $DOCKER images | grep -q "yohasebe/monadic-chat"; then
    $DOCKER rmi -f yohasebe/monadic-chat >/dev/null
  fi

  if $DOCKER images | grep -q "yohasebe/python"; then
    $DOCKER rmi -f yohasebe/python >/dev/null
  fi

  if $DOCKER images | grep -q "yohasebe/pgvector"; then
    $DOCKER rmi -f yohasebe/pgvector >/dev/null
  fi

  if $DOCKER images | grep -q "yohasebe/selenium"; then
    $DOCKER rmi -f yohasebe/selenium >/dev/null
  fi

  if $DOCKER container ls --all | grep -q "monadic-chat"; then
    $DOCKER container rm -f monadic-chat-ruby-container >/dev/null
    $DOCKER container rm -f monadic-chat-pgvector-container >/dev/null
    $DOCKER container rm -f monadic-chat-python-container >/dev/null
    $DOCKER container rm -f monadic-chat-selenium-container >/dev/null
  fi

  if $DOCKER volume ls | grep -q "monadic-chat-pgvector-data"; then
    $DOCKER volume rm monadic-chat-pgvector-data >/dev/null
  fi
}

# Parse the user command
case "$1" in
  build)
    start_docker
    remove_containers
    build_docker_compose
    # check if the above command succeeds
    if $DOCKER images | grep -q "monadic-chat"; then
      echo "[HTML]: <p>Monadic Chat has been built successfully! Press <b>Start</b> button to initialize the server.</p>"
    else
      echo "[HTML]: <p>Monadic Chat has failed to build.</p>"
    fi
    ;;
  start)
    start_docker_compose
    echo "[SERVER STARTED]"
    ;;
  stop)
    stop_docker_compose
    echo "[HTML]: <p>Monadic Chat has been stopped.</p>"
    ;;
  restart)
    stop_docker_compose
    start_docker_compose
    sleep 1
    echo "[SERVER STARTED]"
    ;;
  import)
    start_docker
    stop_docker_compose
    import_database
    ;;
  export)
    start_docker
    stop_docker_compose
    export_database
    ;;
  update)
    start_docker
    update_monadic
    echo "[HTML]: <p>Monadic Chat has been updated successfully!</p>"
    ;;
  down)
    start_docker
    down_docker_compose
    echo "[HTML]: <p>Monadic Chat has been stopped and containers have been removed</p>"
    ;;
  remove)
    start_docker
    remove_containers
    echo "[HTML]: <p>Containers and images have been removed successfully.</p><p>Now you can quit Monadic Chat and unstall the app safely.</p>"
    ;;
  *)
    echo "Usage: $0 {build|start|stop|restart|update|remove}}"
    exit 1
    ;;
esac

exit 0