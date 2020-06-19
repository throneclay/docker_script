#!/bin/bash
set -e
set -x

if [ `hostname` != 'inside_docker' ]; then
  echo "need to be excuted inside docker container"
  exit 2
fi

if [ $# -ne 1 ]; then
  echo "need to pass the port of docker ssh"
  exit 111
fi

sudo apt-get install openssh-server -y

sudo /bin/sed -i "s/#Port 22/Port $1/g" /etc/ssh/sshd_config
sudo service ssh start

# not good
echo $DOCKER_USER:abc |sudo chpasswd