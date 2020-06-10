#!/bin/bash

function main() {

  # check scripts
  # ==================================================================================
  if [ ! -f scripts/custom.sh ]; then
    echo "not found custom.sh in scripts/ will create a default one"
    mkdir -p scripts
    cp docker/default/custom.default scripts/custom.sh
    exit
  fi

  if [ ! -f scripts/env_setup.sh ]; then
    echo "not found env_setup.sh in scripts/ will create a default one"
    mkdir -p scripts
    cp docker/default/env_setup.default scripts/env_setup.sh
    exit
  fi
  source scripts/custom.sh

  if [ $USE_SUPERVISOR -eq 1 ]; then
    if [ ! -f $supervisor_config ]; then
      mkdir -p scripts
      cp docker/default/supervisor.config.default scripts/supervisor.config.default
    fi
  fi
  # install local libs
  # ==================================================================================

  if [ $USE_TENSORRT -eq 1 ]; then
    source docker/local_lib/docker_tensorrt.sh $tensorrt_root
    specify_option="$specify_option $tensorrt_option"
  fi

  if [ $USE_LIBTORCH -eq 1 ]; then
    source docker/local_lib/docker_libtorch.sh $libtorch_root
    specify_option="$specify_option $libtorch_option"
  fi

  # common part
  # ==================================================================================

  docker_lib_path=/usr/lib/x86_64-linux-gnu

  host_lib_path=/usr/lib64
  if [ ! -d $host_lib_path ]; then
     host_lib_path=/usr/lib/x86_64-linux-gnu
  fi
  count=$(ls -1 $host_lib_path/libnvidia* |wc -l)
  if [ $count -eq 0 ]; then
     host_lib_path=/usr/lib/x86_64-linux-gnu
     count=$(ls -1 $host_lib_path/libnvidia* |wc -l)
     if [ $count -eq 0 ]; then
        if [ $USE_CUDA -eq 1 ]; then
          echo "not found nvidia driver!!!"
          exit
        fi
     fi
  fi

  NVIDIA_SO=""
  NVIDIA_BIN=""
  NVIDIA_DEVICES=""
  if [ $USE_CUDA -eq 1 ]; then
      if [ $use_nvidia_docker -eq 1 ]; then
        echo "using cuda, using nvidia-docker, make sure you have installed nvidia-docker"
        NVIDIA_SO="--gpus all"
      else
        echo "using cuda, discover driver by myself, found nvidia driver in $host_lib_path"

        # these variables are the keys
        NVIDIA_SO="$(cd $host_lib_path && ls libcuda* | xargs -I{} echo "-v $host_lib_path/{}:$docker_lib_path/{} ") $(cd $host_lib_path && ls libnvidia* | xargs -I{} echo "-v $host_lib_path/{}:$docker_lib_path/{} ")"
        NVIDIA_BIN="-v /usr/bin/nvidia-smi:/usr/bin/nvidia-smi "
        NVIDIA_DEVICES=$(\ls /dev/nvidia* | xargs -I{} echo '--device {}:{} ')
      fi
  fi

  dir_name="$(pwd | rev | awk -F \/ '{print $1}' | rev)"
  src_conf="-v `pwd`:/$dir_name"

  # using outside cache of pkgs
  if [ $USE_CONDA -eq 1 ]; then
    if [ -d $HOME/miniconda3/pkgs ]; then
      src_conf="$src_conf -v $HOME/miniconda3/pkgs:/opt/pkgs"
    fi
    if [ -d $HOME/.cache/pip ]; then
      src_conf="$src_conf -v $HOME/.cache/pip:/home/$USER/.cache/pip"
    else
      mkdir -p $HOME/.cache/pip
      src_conf="$src_conf -v $HOME/.cache/pip:/home/$USER/.cache/pip"
    fi
  fi
  if [ $# -eq 1 ]; then
    docker_name="$1"
  else
    docker_name="$dir_name"
  fi

  local display=""
  if [[ -z ${DISPLAY} ]];then
      display=":0"
  else
      display="${DISPLAY}"
  fi

  # get user id, will be echo as env variables in docker(docker_adduser.sh)
  USER_ID=$(id -u)
  GRP=$(id -g -n)
  GRP_ID=$(id -g)

  LOCAL_HOST=`hostname`

  docker run $NVIDIA_SO $NVIDIA_BIN $NVIDIA_DEVICES \
     --net=host \
     --name $docker_name \
     $src_conf \
     $data_path \
     $specify_option \
     --privileged \
     -e DISPLAY=$display \
     -e DOCKER_USER=${USER} \
     -e USER=${USER} \
     -e DOCKER_USER_ID=${USER_ID} \
     -e DOCKER_GRP="${GRP}" \
     -e DOCKER_GRP_ID=${GRP_ID} \
     -e LOCAL_HOSTNAME=${LOCAL_HOST} \
     --hostname inside_docker \
     --add-host inside_docker:127.0.0.1 \
     --add-host ${LOCAL_HOST}:127.0.0.1 \
     --shm-size 4G \
     --pid=host \
     -itd \
     -w /$dir_name \
     $docker_base

  # in case of docker exists
  docker start $docker_name

  # common source setup
  docker exec $docker_name bash -c "/bin/sed -i 's/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list"
  docker exec $docker_name bash -c "/bin/sed -i 's/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list"

  if [ $USE_CUDA -eq 1 ]; then
    docker exec $docker_name bash -c "/bin/rm /etc/apt/sources.list.d/cuda.list /etc/apt/sources.list.d/nvidia-ml.list"
  fi
  docker exec $docker_name bash -c "apt-get update && apt-get install sudo -y"

  # set up users
  if [ "${USER}" != "root" ]; then
    docker exec $docker_name bash -c 'bash docker/external/docker_adduser.sh'
  fi

  if [ $USE_CONDA -eq 1 ]; then
    docker exec $docker_name bash -c "/bin/bash docker/external/docker_conda.sh"
  fi
  # deploy using supervisor
  if [ $USE_SUPERVISOR -eq 1 ]; then
    docker exec $docker_name bash -c "/bin/bash docker/external/docker_supervisor.sh $supervisor_config"
  fi
  # custom script run
  docker exec -u ${USER} $docker_name bash -c "/bin/bash scripts/env_setup.sh"

  echo "docker commit $docker_name $docker_name:0.1.0"
  echo "shared data path: "
  echo "$data_path $src_conf"
}

main $*
