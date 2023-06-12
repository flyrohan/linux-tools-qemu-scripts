#!/bin/bash
#
# Require packages
# $ sudo apt-get install qemu-kvm
#

ROOT_DIR=$(realpath $(dirname $(realpath "$BASH_SOURCE"))/../../)
IMAGE_DIR="${ROOT_DIR}/result/x86_64"
QEMU_BIN_DIR="${ROOT_DIR}/result/tools/qemu-6.1.1/usr/bin" # ${ROOT_DIR}/result/tools/qemu-8.0.50/usr/bin
QEMU_SYSTEM_EXE="${QEMU_BIN_DIR}/qemu-system-x86_64"

QEMU_IMAGE_KERNEL="${IMAGE_DIR}/bzImage"
QEMU_IMAGE_ROOTFS="${IMAGE_DIR}/rootfs.cpio"

#QEMU_BOOT_ARGUMENTS="root=/dev/ram rw console=ttyS0 oops=panic panic=1 quiet nokaslr"
QEMU_BOOT_ARGUMENTS="root=/dev/ram rdinit=/init rw console=ttyS0 oops=panic panic=1 nokaslr"

# PCIe
PCIE_DEVICE_VENDOR="Synopsys"
PCIE_DEVICE_ID="$(lspci | grep ${PCIE_DEVICE_VENDOR} | cut -d' ' -f 1)"
QEMU_DEVICE_PCIE="-device vfio-pci,host=${PCIE_DEVICE_ID}"

# Network
QEMU_NET_NAT="-netdev user,id=t0 -device e1000,netdev=t0,id=nic0"
# "qemu-ifup" is copied from ubuntu host pc (installed by $ sudo apt-get install -y qemu-system-x86-64)
#QEMU_NET_BRIDGE="-net nic -net tap,ifname=tap0,script=no"
QEMU_NET_BRIDGE="-net nic -net tap,script=${ROOT_DIR}/tools/scripts/qemu-ifup"
QEMU_DEVICE_NET=${QEMU_NET_BRIDGE}

# Graphic
QEMU_DEVICE_GRAPHIC="-nographic"

QEMU_OPTIONS=(
	# for Network
	${QEMU_DEVICE_NET}
	# for PCIe
	# https://www.kernel.org/doc/Documentation/vfio.txt
	${QEMU_DEVICE_PCIE}
)

QEMU_RUN_COMMAND=(
	"${QEMU_SYSTEM_EXE}"
	"-enable-kvm"
#	"-cpu qemu64,smep,smap"
	"-cpu host"
	"-m 512M"
	"-kernel ${QEMU_IMAGE_KERNEL}"
	"-initrd ${QEMU_IMAGE_ROOTFS}"
	"-append '${QEMU_BOOT_ARGUMENTS}'"
	"${QEMU_DEVICE_GRAPHIC}"
	"${QEMU_OPTIONS[*]}"
	"-s"
	"-pidfile vm.pid"
)

function logmsg () { echo -e "\033[0;33m$*\033[0m"; }

function run_qemu() {
	local cmd=${1}

	cmd="$(echo "${cmd}" | tr '\n' ' ')"
	cmd="$(echo "${cmd}" | sed 's/^[ \t]*//;s/[ \t]*$//')"

	logmsg ${cmd}
	bash -c "${cmd}"
}

run_qemu "${QEMU_RUN_COMMAND[*]}"
