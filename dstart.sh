#!/bin/bash

# check scripts, create the default script if not found
# ==================================================================================
if [ ! -f scripts/custom.sh ]; then
  echo "not found custom.sh in scripts/ will create a default one, run me again to continue"
  mkdir -p scripts
  cp docker/default/custom.default scripts/custom.sh
  exit
fi

if [ ! -f scripts/env_setup.sh ]; then
  echo "not found env_setup.sh in scripts/ will create a default one, run me again to continue"
  mkdir -p scripts
  cp docker/default/env_setup.default scripts/env_setup.sh
  exit
fi

# source all the options
source scripts/custom.sh

function run_docker_container() {
  # check args
  # ==================================================================================
  if [ $# -lt 1 ]; then
    echo "param is not right, please checkout usage"
    exit
  fi
  # check supervisor script
  if [ $USE_SUPERVISOR -eq 1 ]; then
    if [ ! -f $supervisor_config ]; then
      mkdir -p scripts
      cp docker/default/supervisor.config.default scripts/supervisor.config.default
      exit
    fi
  fi
  # install local libs
  # ==================================================================================

  if [ $USE_TENSORRT -eq 1 ]; then
    source docker/host_lib/docker_tensorrt.sh $tensorrt_root
    specify_option="$specify_option $tensorrt_option"
  fi

  if [ $USE_LIBTORCH -eq 1 ]; then
    source docker/host_lib/docker_libtorch.sh $libtorch_root
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

  # the nvidia docker can be simulated these way
  # if your host cannot install nvidia-docker, you can use these sharing options
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

  #set options based on the args

  # if not base, then the entry of this function is exec, changing docker base
  if [ $1 != "base" ]; then
    docker_base=$1
    echo "exec docker image using $1"
  fi

  # if docker name is passed
  if [ $# -eq 2 ]; then
    docker_name="$2"
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

  # network setup
  network_config="--net=host"
  # TODO macinto cannot support network sharing, this might not working
  if [ "$(uname)" == "Darwin" ]; then
    network_config="-P"
  fi

  docker run $NVIDIA_SO $NVIDIA_BIN $NVIDIA_DEVICES \
     $network_config \
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
}

function create_docker_with_post_install() {
  # first of all, i need to create docker env

  # if you have better idea, let me know XD
  run_docker_container base $@

  if [ $? -ne 0 ]; then
    echo "docker exists, will skip env setup, and start docker directly"
    # in case of docker exists
    docker start $docker_name
    exit 0
  fi

  # common source setup
  docker exec $docker_name bash -c "/bin/sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list"
  docker exec $docker_name bash -c "/bin/sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list"

  if [ $USE_CUDA -eq 1 ]; then
    docker exec $docker_name bash -c "/bin/rm /etc/apt/sources.list.d/cuda.list /etc/apt/sources.list.d/nvidia-ml.list"
  fi
  docker exec $docker_name bash -c "apt-get update && apt-get install sudo -y"

  # set up users
  if [ "${USER}" != "root" ]; then
    docker exec $docker_name bash -c 'bash docker/in_docker_lib/docker_adduser.sh'
  fi

  if [ $USE_CONDA -eq 1 ]; then
    docker exec $docker_name bash -c "/bin/bash docker/in_docker_lib/docker_conda.sh"
  fi

  if [ $USE_DOCKER_SSH -eq 1 ]; then
    docker exec $docker_name bash -c "/bin/bash docker/in_docker_lib/docker_parepare_ssh.sh $DOCKER_SSH_PORT"
  fi

  # deploy using supervisor
  if [ $USE_SUPERVISOR -eq 1 ]; then
    docker exec $docker_name bash -c "/bin/bash docker/in_docker_lib/docker_supervisor.sh $supervisor_config"
  fi
  # custom script run
  docker exec -u ${USER} $docker_name bash -c "/bin/bash scripts/env_setup.sh"
  echo ""
  echo "docker prepare finished, next you can run bash docker/dinto.sh to get inside docker, or you can commit your own image by using:"
  echo "bash docker/dstart.sh commit $docker_name $docker_name:0.1.0"
  echo "the shared data path is : "
  echo "$data_path $src_conf"
}

function commit_docker_image() {
  typeset -l docker_target_name
  # commit helper function
  if [ $# -eq 1 ]; then
    docker_target_name=$1
  else
    docker_target_name=$2
  fi
  echo "i will commit $1 to $docker_target_name"
  docker commit $1 $docker_target_name
}

function print_usage() {
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NONE='\033[0m'

  echo -e "\n${RED}Usage${NONE}:
  ${BOLD}bash docker/dstart.sh${NONE} Command [Options]"

  echo -e "\n${RED}Command${NONE}:
  ${BLUE}create${NONE}: create docker from scratch based on custom.sh and start it. option: [container_name]
  ${BLUE}run${NONE}: run docker from image I commited, using custom.sh sharing path, option: target_image_name [container_name]
  ${BLUE}commit${NONE}: commit the container I created. option: container_name [target_image_name]
  ${BLUE}usage${NONE}: display this message
  "
}

# main entry
function main() {
  local cmd=$1
  case $cmd in
    create)
      # calling docker create, with post install
      # pass args from the second to the end
      create_docker_with_post_install ${@:2}
      ;;
    run)
      # just run with custom sharing setup
      # pass args from the second to the end
      run_docker_container ${@:2}
      ;;
    commit)
      # commit helper
      # pass args from the second to the end
      commit_docker_image ${@:2}
      ;;
    usage)
      print_usage
      ;;
    *)
      print_usage
      ;;
  esac
}

main $@

echo "enjoy :)"