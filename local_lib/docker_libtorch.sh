#!/bin/bash

libtorch_root=$1
# common part
# ================================================================================================

if [ ! -d $libtorch_root ]; then
  echo "not found libtorch in $libtorch_root, will download automatically"
  cd /opt
  sudo wget https://download.pytorch.org/libtorch/cu101/libtorch-cxx11-abi-shared-with-deps-1.3.1.zip
  sudo unzip /opt/libtorch-cxx11-abi-shared-with-deps-1.3.1.zip
fi

libtorch_option="-v $libtorch_root:/opt/libtorch"