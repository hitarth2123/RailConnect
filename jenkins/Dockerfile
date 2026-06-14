FROM jenkins/jenkins:lts

USER root

# Install Python3, pip, venv, and Docker CLI
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Allow jenkins user to run docker
RUN usermod -aG docker jenkins

# Entrypoint fixes socket permissions at container start (needed for macOS Docker Desktop)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
