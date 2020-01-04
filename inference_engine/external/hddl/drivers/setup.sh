#! /bin/bash
# Copyright (C) 2019 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0

DRIVER_DIR=`dirname "$(readlink -f "$0")"`
COMPONENTS="
drv_ion
drv_vsc
"
MAKEFLAGS=""

if [ $# -eq 2 ] && [ "$2" = "USE_SYSTEM_CONTIG_HEAP" ]; then
  MAKEFLAGS=$2"=ON"
fi

if [ "$1" = "install" ]; then
  TARGET=$1
elif [ "$1" = "uninstall" ]; then
  TARGET=$1
else
  echo "Unrecognezed argements. Please use"
  echo "    bash setup.sh install|uninstall"
  exit
fi

function install_component {
  local component=$1
  local target=$2
  local makeflags=$3

  echo "Running $target for component $component"
  cd $DRIVER_DIR/$component
  make $target $makeflags
}

for component in $COMPONENTS
do
  install_component $component $TARGET $MAKEFLAGS
done
