#!/bin/bash
set -e

if [ `hostname` != 'inside_docker' ]; then
  echo "need to be excuted inside docker container"
  exit 2
fi

apt-get install -y supervisor

if [ $# -eq 2 ]; then
  supervisor_config=$2
  cp $supervisor_config /etc/supervisor/conf.d
  supervisord
else
  echo "not found config file, will skip launch supervisor"
fi