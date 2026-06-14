FROM jenkins/jenkins:lts

USER root

# Install Python3, pip, venv, and Docker CLI
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Match the host docker group GID so socket permissions work at runtime.
# The host docker group is typically GID 999 or 998 — adjust if needed.
RUN groupmod -g 999 docker || groupadd -g 999 docker \
    && usermod -aG docker jenkins

USER jenkins
