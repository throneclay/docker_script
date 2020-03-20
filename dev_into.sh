#!/bin/bash

dir_name="$(pwd | rev | awk -F \/ '{print $1}' | rev)"

docker exec -it $dir_name /bin/bash