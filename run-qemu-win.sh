#!/bin/bash

BASE_DIR=$(realpath $(dirname $(realpath "$BASH_SOURCE"))/../../)
QEMU_IMAGE_DIR="${BASE_DIR}/images/"

QEMU_ISO_IMAGE="${QEMU_IMAGE_DIR}Win10_2004_Korean_x64.iso"
#QEMU_ISO_IMAGE="${QEMU_IMAGE_DIR}Win11_Korean_x64v1.iso"
QEMU_WIN_IMAGE="${QEMU_IMAGE_DIR}windows.raw"
QEMU_IMAGE_SIZE=20G

#QEMU_INSTALL_PATH="/home/rohan/devel/work/rohan/github.rohan/qemu/install/x86_64/usr/local/bin/"
QEMU_SYSTEM="${QEMU_INSTALL_PATH}qemu-system-x86_64"

QEMU_OPTION_VNC="-vnc 127.0.0.1:1"
#QEMU_OPTION_NET="-net nic"
#QEMU_OPTION_NET+="-net tap,id=foo"
#QEMU_OPTION="${QEMU_OPTION_VNC} ${QEMU_OPTION_NET}"

function msg () { echo -e "\033[0;33m$*\033[0m"; }
function err () { echo -e "\033[0;31m$*\033[0m"; }

function qemu_create_image () {
        if [[ ! -f ${QEMU_ISO_IMAGE} ]]; then
                err "Not found win ISO image : ${QEMU_ISO_IMAGE} !!!"
                exit 1;
        fi

        qemu-img create ${QEMU_WIN_IMAGE} ${QEMU_IMAGE_SIZE}
        wait;
        sudo ${QEMU_SYSTEM} -m 4G -cpu host ${QEMU_OPTION} -smp sockets=1,cores=2,threads=2 -cdrom ${QEMU_ISO_IMAGE} -drive file=${QEMU_WIN_IMAGE},format=raw -enable-kvm
}

function qemu_run () {
        sudo ${QEMU_SYSTEM} -m 4G -cpu host -smp sockets=1,cores=2,threads=2 -drive file=${QEMU_WIN_IMAGE},format=raw -soundhw all -enable-kvm
}

function qemu_stop () {
	pid=$(pidof ${QEMU_SYSTEM})

	if [[ ${pid} ]]; then
		user=$(ps -o user= -p ${pid})
		echo "Kill ${QEMU_SYSTEM} pid [${user}:${pid}]"
		[[ ${user} == root ]] && _sudo_=sudo
		bash -c "${_sudo_} kill ${pid}"
	else
		echo "No such process ${QEMU_SYSTEM}"
	fi
}

case $1 in
	image )
                qemu_create_image 
		;;
	delete )
		rm -rf ${QEMU_WIN_IMAGE}
		;;
	run )
	        qemu_run	
		;;
        stop )
                qemu_stop
                ;;
	* )
		echo "$0 [image|delete|run|stop]"
esac
