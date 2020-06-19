#!/bin/bash
set -e

if [ `hostname` != 'inside_docker' ]; then
  echo "need to be excuted inside docker container"
  exit 2
fi

addgroup --gid "$DOCKER_GRP_ID" "$DOCKER_GRP"
adduser --disabled-password --force-badname --gecos '' "$DOCKER_USER" \
    --uid "$DOCKER_USER_ID" --gid "$DOCKER_GRP_ID" 2>/dev/null
usermod -aG sudo "$DOCKER_USER"
echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
echo "alias ls=\"ls --color=auto\"" >> /etc/bash.bashrc
chown $DOCKER_USER: /home/$DOCKER_USER