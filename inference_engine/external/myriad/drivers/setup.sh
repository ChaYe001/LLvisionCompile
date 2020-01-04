#! /bin/bash
# Copyright (C) 2019 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0

DRIVER_DIR=`dirname "$(readlink -f "$0")"`"/serial/mxlk"

cd $DRIVER_DIR
if [ "$1" = "install" ]; then
  echo "Running PCIe driver installation"
  make clean && make all && make install
elif [ "$1" = "uninstall" ]; then
  echo "Running PCIe driver deinstallation"
  sudo rmmod mxlk.ko
else
  echo "Unrecognezed argements. Please use"
  echo "    bash setup.sh install|uninstall"
  exit
fi
