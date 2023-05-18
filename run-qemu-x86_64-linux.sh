#!/bin/bash
#
# Require packages
# $ sudo apt-get install qemu-kvm
#

ROOT_DIR=$(realpath $(dirname $(realpath "$BASH_SOURCE"))/../../)
QEMU_BIN_DIR="${ROOT_DIR}/result/tools/qemu-6.1.1/usr/bin"

QEMU_IMAGE_DIR="${ROOT_DIR}/result/x86_64"

QEMU_KERNE_IMAGE="${QEMU_IMAGE_DIR}/bzImage"
QEMU_ROOT_IMAGE="${QEMU_IMAGE_DIR}/initrd.img"
#QEMU_BOOT_ARGUMENTS="root=/dev/ram rw console=ttyS0 oops=panic panic=1 quiet nokaslr"
QEMU_BOOT_ARGUMENTS="root=/dev/ram rdinit=/linuxrc rw console=ttyS0 oops=panic panic=1 nokaslr"

QEMU_HOST_DEV_PCIE=$(lspci | grep  Xil | cut -d' ' -f 1)
QEMU_DEVICES=(
	"-device e1000,netdev=t0,id=nic0"
	# for PCIe
	# https://www.kernel.org/doc/Documentation/vfio.txt
	#"-device vfio-pci,host=${QEMU_HOST_DEV_PCIE}"
)

QEMU_RUN_COMMAND="${QEMU_BIN_DIR}/qemu-system-x86_64 \
    -m 512M \
    -kernel ${QEMU_KERNE_IMAGE} \
    -initrd ${QEMU_ROOT_IMAGE} \
    -append '${QEMU_BOOT_ARGUMENTS}' \
    -netdev user,id=t0 \
    -nographic  \
    -cpu qemu64,smep,smap \
	${QEMU_DEVICES[@]} \
    -s \
    -pidfile vm.pid"

function logmsg () { echo -e "\033[0;33m$*\033[0m"; }

function do_run() {
	local command=${1}

	command="$(echo "${command}" | tr '\n' ' ')"
	command="$(echo "${command}" | sed 's/^[ \t]*//;s/[ \t]*$//')"
	logmsg ${command}
	bash -c "${command}"
}

do_run "${QEMU_RUN_COMMAND}"
