#!/bin/bash
# Copyright (C) 2019 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0

if [ -z "$HDDL_INSTALL_DIR" ]; then
    echo "Can't get HDDL_INSTALL_DIR env. Please source your_openvino_intall_path/openvino/bin/setupvars.sh before running."
    exit 0
fi

# Make sure script path is work path
script_path="$( cd "$(dirname "$0")" ; pwd -P )"
cd $script_path

# Get current OS type and version
get_linux_arch() {
    if [[ -f /etc/lsb-release ]]; then
        # Ubuntu
        system_ver=`cat /etc/lsb-release | grep -i "DISTRIB_RELEASE" | cut -d "=" -f2`

        if [ $system_ver = "18.04" ]; then
	    #OS = "Ubuntu18.04"
            return 1
        else
            #OS = "Ubuntu16.04"
            return 2
        fi
    else
        #OS = "CentOS"
	return 3
    fi
}

check_apt_install() {
    dpkgs="$1"
    sudo -E apt install -y ${dpkgs}
    dpkg -l ${dpkgs} > /dev/null
    if [ $? -ne 0 ]; then
        echo ""
        echo "Install: ${dpkgs} failed, please check if apt-get is working correctly (you may need to setup proxy for it)."
        exit -22
    fi
}

check_drivers_setup_status() {
    if [ ! -f "./drv_vsc/myd_vsc.ko" ]; then
        echo "sudo ./setup.sh install myd_vsc fail"
        exit -22
    fi
    if [ ! -f "/lib/modules/$(uname -r)/kernel/drivers/myd/myd_vsc.ko" ]; then
        echo "sudo ./setup.sh install myd_vsc fail"
        exit -22
    fi

    if [ ! -f "./drv_ion/myd_ion.ko" ]; then
        echo "sudo ./setup.sh install myd_ion fail"
        exit -22
    fi
    if [ ! -f "/lib/modules/$(uname -r)/kernel/drivers/myd/myd_ion.ko" ]; then
        echo "sudo ./setup.sh install myd_ion fail"
        exit -22
    fi
    
    lsmod | grep "myd_vsc" > /dev/null
    if [ $? -ne 0 ]; then
        echo "Fail: myd_vsc don't been loaded!"
        exit -22
    fi
    lsmod | grep "myd_ion" > /dev/null
    if [ $? -ne 0 ]; then
        echo "Fail: myd_ion don't been loaded!"
        exit -22
    fi
}

install_dependencies_ubuntu18_04() {
    check_apt_install "libusb-1.0-0 libboost-program-options1.65.1 libssl1.0.0 libudev1 libjson-c3 libelf-dev"
    sudo usermod -a -G users "$(whoami)"
    sudo chmod +x ./generate_udev_rules.sh
    sudo ./generate_udev_rules.sh /etc/udev/rules.d/98-hddlbsl.rules
    if [ $? -ne 0 ]; then
        echo "generate_udev_rules.sh fail."
        exit -22
    fi
    sudo sed -i "s/\(.*i2c_i801$\)/#\1/g" /etc/modprobe.d/blacklist.conf
    sudo modprobe i2c_i801 # unblocking will take effect at next reboot. To avoid reboot, this time we still insmod manually
    kill -9 $(pidof hddldaemon autoboot)
    cd ./drivers
    sudo chmod +x ./setup.sh
    sudo ./setup.sh install
    check_drivers_setup_status

    sudo cp -av ${HDDL_INSTALL_DIR}/../97-myriad-usbboot.rules /etc/udev/rules.d/
    sudo cp -av ${HDDL_INSTALL_DIR}/etc /
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    sudo ldconfig
    return 0
}

install_dependencies_ubuntu16_04() {
    check_apt_install "libusb-1.0-0 libboost-program-options1.58.0 libboost-thread1.58.0 libboost-filesystem1.58.0 libssl1.0.0 libudev1 libjson-c2 libelf-dev"
    sudo usermod -a -G users "$(whoami)"
    sudo chmod +x ./generate_udev_rules.sh
    sudo ./generate_udev_rules.sh /etc/udev/rules.d/98-hddlbsl.rules
    if [ $? -ne 0 ]; then
        echo "generate_udev_rules.sh fail."
        exit -22
    fi
    sudo sed -i "s/\(.*i2c_i801$\)/#\1/g" /etc/modprobe.d/blacklist.conf
    sudo modprobe i2c_i801 # unblocking will take effect at next reboot. To avoid reboot, this time we still insmod manually
    kill -9 $(pidof hddldaemon autoboot)
    cd ./drivers
    sudo chmod +x ./setup.sh
    sudo ./setup.sh install
    check_drivers_setup_status

    sudo cp -av ${HDDL_INSTALL_DIR}/../97-myriad-usbboot.rules /etc/udev/rules.d/
    sudo cp -av ${HDDL_INSTALL_DIR}/etc /
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    sudo ldconfig
    return 0
}

check_yum_install() {
    dpkgs="$1"
    sudo -E yum install ${dpkgs} -y 
    rpm -qa ${dpkgs} > /dev/null
    if [ $? -ne 0 ]; then
        echo ""
        echo "Install: ${dpkgs} fail, Please check if yum work corrently(You may need to set proxy for it)."
        exit -22
    fi
}

install_dependencies_centos7_4() {
    # check kernel version
    uname -r | grep "3.10.0-693"
    if [ "$?" != "0" ]; then
        echo "Warning:We only verify this script based on CentOS 7.4(kernel version: 3.10.0-693), other version kernel maybe fail"
    fi

    check_yum_install "libusb"
    check_yum_install "boost-filesystem-1.53.0-27.el7.x86_64 boost-program-options-1.53.0-27.el7.x86_64 boost-thread-1.53.0-27.el7.x86_64 boost-system-1.53.0-27.el7.x86_64 boost-chrono-1.53.0-27.el7.x86_64 boost-date-time-1.53.0-27.el7.x86_64 boost-atomic-1.53.0-27.el7.x86_64"
    check_yum_install "pciutils"
    check_yum_install "redhat-lsb-core-4.1-27.el7.centos.1.x86_64"
    
    # Check folder whether if exits?
    kernel_build_path="/lib/modules/$(uname -r)/build"
    if [ -d "$kernel_build_path" ]; then
        echo "${kernel_build_path} already exists"
    else
        echo "Error: ${kernel_build_path} no exists"
        echo "Please find kernel-devel-$(uname -r).rpm on your installation packages, and then install it, for example:"
        echo "rpm -ivh [your_path]/kernel-devel-$(uname -r).rpm"
        exit 0
    fi

    sudo usermod -a -G users "$(whoami)"
    cd ${HDDL_INSTALL_DIR}
    sudo chmod +x ./generate_udev_rules.sh
    sudo ./generate_udev_rules.sh /etc/udev/rules.d/98-hddlbsl.rules
    if [ $? -ne 0 ]; then
        echo "generate_udev_rules.sh fail."
        exit -22
    fi

    sudo modprobe i2c_dev
    sudo modprobe i2c_i801

    ps -fe|grep autoboot |grep -v grep
    if [ $? -ne 0 ]; then
        kill -9 $(pidof autoboot)
    fi
    ps -fe|grep hddldaemon |grep -v grep
    if [ $? -ne 0 ]; then
        kill -9 $(pidof hddldaemon)
    fi

    cd ${HDDL_INSTALL_DIR}/drivers
    sudo chmod +x ./setup.sh
    sudo ./setup.sh install
    check_drivers_setup_status

    cfg_i2c="/etc/modules-load.d/i2c-i801.conf"
    sudo bash -c "echo -e \"i2c-i801\ni2c-dev\"">$cfg_i2c

    sudo cp -av ${HDDL_INSTALL_DIR}/../97-myriad-usbboot.rules /etc/udev/rules.d/
    sudo cp -av ${HDDL_INSTALL_DIR}/etc /
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    sudo ldconfig
    return 0
}

get_linux_arch
OS=$?
if [ $OS = "1" ]; then
    echo "Ubuntu18.04"
    install_dependencies_ubuntu18_04
elif [ $OS = "2" ]; then
    echo "Ubuntu16.04"
    install_dependencies_ubuntu16_04
elif [ $OS = "3" ]; then
    echo "CentOS"
    install_dependencies_centos7_4
else
    echo "Current OS isn't supported."
fi

SUCESS_OR_NOT=$?
if [ $SUCESS_OR_NOT = "0" ]; then
    echo "======================================="
    echo "Install HDDL dependencies sucessful"
    echo "Please reboot"
fi

