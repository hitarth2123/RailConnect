#!/bin/bash
# Fix Docker socket permissions on macOS Docker Desktop
if [ -S /var/run/docker.sock ]; then
    chmod 666 /var/run/docker.sock
fi

# Hand off to the official Jenkins entrypoint
exec /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"
