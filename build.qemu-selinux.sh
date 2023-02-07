#!/bin/bash
# Copyright (c) 2018 Nexell Co., Ltd.
# Author: Junghyun, Kim <jhkim@nexell.co.kr>
#

BASE_DIR=$(realpath $(dirname $(realpath "$BASH_SOURCE"))/../..)
RESULT_TOP=${BASE_DIR}/result

RESULT_DIR=${RESULT_TOP}/qemu
TOOLCHAIN_DIR="${BASE_DIR}/tools/toolchain/gcc-11.0.1_aarch64-linux-gnu/bin/"
TOOLCHAIN_LINUX="${TOOLCHAIN_DIR}aarch64-linux-gnu-"

TOOLS_DIR="${BASE_DIR}/tools"
TOOLS_SCRIPT_DIR="${TOOLS_DIR}/scripts"
TOOLS_SCRIPT_COMMON_DIR="${TOOLS_DIR}/common"

# buildroot configs
BR2_PATH=buildroot
BR2_DIR=${BASE_DIR}/${BR2_PATH}
BR2_DEFCONFIG=qemu_aarch64_selinux_defconfig

KERNEL_DIR="${BASE_DIR}/linux"
# default search path : arch/arm64/configs/
KERNEL_DEFCONFIG="../../../../${BR2_PATH}/board/rohan/configs/linux_selinux_defconfig"
KERNEL_BIN="Image"

QEMU_DIR="${BASE_DIR}/qemu"
QEMU_VERSION=v6.1.0
QEMU_ISNTALL_DIR="${RESULT_TOP}/tools/qemu-${QEMU_VERSION}"
QEMU_CONFIG="--target-list=aarch64-softmmu,aarch64-linux-user --enable-debug"

ROOT_DIR="${RESULT_DIR}/rootfs"
ROOT_INITRD="${RESULT_DIR}/initrd.img"

BSP_TOOL_FILES=(
)

function qemu_configure () {
	cd ${QEMU_DIR}
        bash -c "./configure ${QEMU_CONFIG}"
}

function qemu_build () {
	cd ${QEMU_DIR}
	bash -c "make -C build -j8"
}

function qemu_install () {
	local destdir="${QEMU_ISNTALL_DIR}"

	echo "INSTALL : ${destdir}"
	mkdir -p ${destdir} 
	cd ${QEMU_DIR}
	bash -c "make install DESTDIR=${destdir}"
}

function qemu_clean () {
	cd ${QEMU_DIR}
	bash -c "make distclean"
}

function br2_initrd () {
	echo "Build initrd: $(pwd)"
	${TOOLS_SCRIPT_COMMON_DIR}/mk_ramimg.sh -r ${ROOT_DIR} -o ${ROOT_INITRD}
}

function copy_tools () {
	for file in "${BSP_TOOL_FILES[@]}"; do
		[[ -d $file ]] && continue;
		cp -a $file ${RESULT_DIR}
	done
}

###############################################################################
# Build Image and Targets
###############################################################################
BUILD_IMAGES=(
	"CROSS_TOOL	= ${TOOLCHAIN_LINUX}",
	"RESULT_DIR 	= ${RESULT_DIR}",

	"qemu	=
		BUILD_MANUAL    : true,
		BUILD_PREV      : qemu_configure,
		BUILD_POST      : qemu_build,
		BUILD_COMPLETE  : qemu_install,
		BUILD_CLEAN     : qemu_clean",

	"kernel	=
		MAKE_PATH       : ${KERNEL_DIR},
		MAKE_ARCH       : arm64,
		MAKE_CONFIG     : ${KERNEL_DEFCONFIG},
		MAKE_TARGET     : ${KERNEL_BIN},
		BUILD_OUTPUT    : arch/arm64/boot/${KERNEL_BIN}",

	"br2   	=
		MAKE_PATH       : ${BR2_DIR},
		MAKE_CONFIG     : ${BR2_DEFCONFIG},
		BUILD_OUTPUT    : output/target; output/images/disk.img,
		BUILD_RESULT    : rootfs; disk.img,
		BUILD_COMPLETE  : br2_initrd",
)
