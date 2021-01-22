#!/bin/bash

dir_name="$(pwd | rev | awk -F \/ '{print $1}' | rev)"

if [ $# -eq 1 ]; then
  docker_name="$1"
else
  docker_name="$dir_name_${USER}"
fi

docker exec -u ${USER} -it $docker_name /bin/bash
