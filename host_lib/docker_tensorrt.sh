#!/bin/bash

# tensorrt root setup
# ================================================================================================
tensorrt_root=$1

# common part
# ================================================================================================

if [ ! -d $tensorrt_root ]; then
  echo "not found tensorrt root in $tensorrt_root"
  echo "download tgz tensorrt from nvidia.com and put at $tensorrt_root"
fi

tensorrt_option="-v $tensorrt_root:/opt/tensorrt"