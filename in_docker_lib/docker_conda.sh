#!/bin/bash
set -e

if [ `hostname` != 'inside_docker' ]; then
  echo "need to be excuted inside docker container"
  exit 2
fi

# common part
# ================================================================================================

if [ ! -f ./Miniconda3-latest-Linux-x86_64.sh ]; then
  sudo apt-get install wget -y
  wget https://mirrors.bfsu.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh
fi
chmod a+x Miniconda3-latest-Linux-x86_64.sh
sudo ./Miniconda3-latest-Linux-x86_64.sh -p /opt/miniconda3 -b
if [ -d /opt/pkgs ]; then
  sudo rm -r /opt/miniconda3/pkgs
  sudo ln -s /opt/pkgs/ /opt/miniconda3/pkgs
fi

# change owner, because i install using sudo
sudo chown $DOCKER_USER: -R /opt/miniconda3/
sudo chown $DOCKER_USER: -R /home/$DOCKER_USER/.conda

echo '
__conda_setup="$('/opt/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
' >> /home/$DOCKER_USER/.bashrc

#chown $DOCKER_USER: /home/$DOCKER_USER/.bashrc

__conda_setup="$('/opt/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup

conda config --add channels https://mirrors.bfsu.edu.cn/anaconda/pkgs/free/
conda config --add channels https://mirrors.bfsu.edu.cn/anaconda/pkgs/main/
conda config --set show_channel_urls yes
conda config --add channels https://mirrors.bfsu.edu.cn/anaconda/cloud/conda-forge/
conda config --add channels https://mirrors.bfsu.edu.cn/anaconda/cloud/pytorch/

echo "minconda setup success!!"

mkdir -p /home/$DOCKER_USER/.config/pip/
echo '
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/

[install]
trusted-host=mirrors.aliyun.com
' > /home/$DOCKER_USER/.config/pip/pip.conf
sudo chown $DOCKER_USER: -R /home/$DOCKER_USER/.config
sudo chown $DOCKER_USER: -R /home/$DOCKER_USER/.cache
echo "setup pip source success!!"
