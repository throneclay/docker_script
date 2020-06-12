#!/bin/bash

# common part
# ================================================================================================

if [ ! -f ./Miniconda3-latest-Linux-x86_64.sh ]; then
  apt-get install wget -y
  wget https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh
fi
chmod a+x Miniconda3-latest-Linux-x86_64.sh
./Miniconda3-latest-Linux-x86_64.sh -p /opt/miniconda3 -b
rm -r /opt/miniconda3/pkgs
ln -s /opt/pkgs/ /opt/miniconda3/pkgs

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

chown $DOCKER_USER: /home/$DOCKER_USER/.bashrc
chown $DOCKER_USER: -R /opt/miniconda3/

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

#conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/
#conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/
#conda config --set show_channel_urls yes
#conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge/
#conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/pytorch/

chown $DOCKER_USER: -R /home/$DOCKER_USER/.conda /home/$DOCKER_USER/.condarc

echo "minconda setup success!!"

mkdir -p /home/$DOCKER_USER/.config/pip/
#echo '
#[global]
#index-url = https://pypi.tuna.tsinghua.edu.cn/simple
#' > /home/$DOCKER_USER/.config/pip/pip.conf
chown $DOCKER_USER: -R /home/$DOCKER_USER/.config
chown $DOCKER_USER: -R /home/$DOCKER_USER/.cache
echo "setup pip source success!!"
