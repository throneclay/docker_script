#!/bin/bash

function main() {

  # check scripts
  # ==================================================================================
  if [ ! -f scripts/custom.sh ]; then
    echo "not found custom.sh in scripts/ will create a default one"
    mkdir -p scripts
    cp default/custom.default scripts/custom.sh
  fi

  if [ ! -f scripts/env_setup.sh ]; then
    echo "not found env_setup.sh in scripts/ will create a default one"
    mkdir -p scripts
    cp default/env_setup.default scripts/env_setup.sh
  fi
  source scripts/custom.sh

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
        echo "not found nvidia driver!!!"
        exit
     fi
  fi

  echo "found nvidia driver in $host_lib_path"

  # these variables are the keys
  NVIDIA_SO="$(cd $host_lib_path && ls libcuda* | xargs -I{} echo "-v $host_lib_path/{}:$docker_lib_path/{} ") $(cd $host_lib_path && ls libnvidia* | xargs -I{} echo "-v $host_lib_path/{}:$docker_lib_path/{} ")"
  NVIDIA_BIN="-v /usr/bin/nvidia-smi:/usr/bin/nvidia-smi "
  NVIDIA_DEVICES=$(\ls /dev/nvidia* | xargs -I{} echo '--device {}:{} ')
  dir_name="$(pwd | rev | awk -F \/ '{print $1}' | rev)"
  src_conf="-v `pwd`:/$dir_name"

  docker_name="$dir_name"

  local display=""
  if [[ -z ${DISPLAY} ]];then
      display=":0"
  else
      display="${DISPLAY}"
  fi

  docker run $NVIDIA_SO $NVIDIA_BIN $NVIDIA_DEVICES \
     --net=host \
     --name $docker_name \
     $src_conf \
     $data_path \
     $specify_option \
     -e DISPLAY=$display \
     -itd \
     -w /$dir_name \
     $docker_base

  # in case of docker exists
  docker start $docker_name

  # common source setup
  docker exec $docker_name bash -c "/bin/sed -i 's/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list"
  docker exec $docker_name bash -c "/bin/sed -i 's/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list"
  docker exec $docker_name bash -c "/bin/rm /etc/apt/sources.list.d/cuda.list /etc/apt/sources.list.d/nvidia-ml.list"

  if [ $USE_CONDA -eq 1 ]; then
    docker exec $docker_name bash -c "/bin/bash docker/external/docker_conda.sh"
  fi

  # custom script run
  docker exec $docker_name bash -c "/bin/bash scripts/env_setup.sh"
}

main