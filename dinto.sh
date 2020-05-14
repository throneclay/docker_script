#!/bin/bash

dir_name="$(pwd | rev | awk -F \/ '{print $1}' | rev)"

docker exec -u ${USER} -it $dir_name /bin/bash