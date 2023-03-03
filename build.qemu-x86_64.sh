#!/bin/bash
# Copyright (c) 2018 Nexell Co., Ltd.
# Author: Junghyun, Kim <jhkim@nexell.co.kr>
#

BASE_DIR=$(realpath $(dirname $(realpath "$BASH_SOURCE"))/../..)
RESULT_TOP="${BASE_DIR}/result"
OUTPUT_TOP="${BASE_DIR}/output"
TARGET_ARCH="x86_64"
RESULT_DIR="${RESULT_TOP}/${TARGET_ARCH}"
OUTPUT_DIR="${OUTPUT_TOP}/${TARGET_ARCH}"


TOOLS_DIR="${BASE_DIR}/tools"
TOOLS_SCRIPT_DIR="${TOOLS_DIR}/scripts"
TOOLS_SCRIPT_COMMON_DIR="${TOOLS_DIR}/common"

# buildroot configs
BR2_PATH=buildroot
BR2_DIR=${BASE_DIR}/${BR2_PATH}
BR2_OUT=${OUTPUT_DIR}/${BR2_PATH}
BR2_DEFCONFIG="qemu_x86_64_defconfig"

KERNEL_DIR="${BASE_DIR}/linux"
KERNEL_OUT="${OUTPUT_DIR}/linux-x86_64"
KERNEL_DEFCONFIG="x86_64_defconfig"
KERNEL_BIN="bzImage"

QEMU_DIR="${BASE_DIR}/qemu"
QEMU_OUT="${OUTPUT_DIR}/qemu"
QEMU_VERSION=v6.1.0
QEMU_ISNTALL_DIR="${RESULT_TOP}/tools/qemu-${QEMU_VERSION}"
QEMU_CONFIG="--target-list=aarch64-softmmu,aarch64-linux-user --enable-debug"

ROOT_DIR="${RESULT_DIR}/rootfs"
ROOT_INITRD="${RESULT_DIR}/initrd.img"

function qemu_configure () {
	logmsg "QEMU configure"
	mkdir -p ${QEMU_OUT}
	pushd ${QEMU_OUT} 2>/dev/null
        bash -c "${QEMU_DIR}/configure ${QEMU_CONFIG}"
	popd
}

function qemu_build () {
	logmsg "QEMU build"
	pushd ${QEMU_OUT} 2>/dev/null
	bash -c "make -j$(grep -c processor /proc/cpuinfo)"
	popd
}

function qemu_install () {
	local destdir="${QEMU_ISNTALL_DIR}"

	logmsg "QEMU install: ${destdir}"
	mkdir -p ${destdir}

	pushd ${QEMU_OUT} 2>/dev/null
	bash -c "make install DESTDIR=${destdir}"
	popd
}

function qemu_clean () {
	logmsg "QEMU clean: $(pwd)"
	pushd ${QEMU_OUT} 2>/dev/null
	bash -c "make distclean"
	popd
}

function br2_initrd () {
	logmsg "Build initrd: $(pwd)"
	${TOOLS_SCRIPT_COMMON_DIR}/mk_ramimg.sh -r ${ROOT_DIR} -o ${ROOT_INITRD}
}

###############################################################################
# Build Image and Targets
###############################################################################
BUILD_IMAGES=(
	"RESULT_DIR 	= ${RESULT_DIR}",

	"qemu	=
		BUILD_MANUAL   : true,
		MAKE_PATH      : ${QEMU_DIR},
		BUILD_PREP     : qemu_configure,
		BUILD_POST     : qemu_build,
		BUILD_COMPLETE : qemu_install,
		BUILD_CLEAN    : qemu_clean",

	"kernel	=
		MAKE_ARCH      : x86_64,
		MAKE_PATH      : ${KERNEL_DIR},
		MAKE_DEFCONFIG : ${KERNEL_DEFCONFIG},
		MAKE_TARGET    : ${KERNEL_BIN},
		MAKE_OUTDIR    : ${KERNEL_OUT},
		BUILD_OUTPUT   : arch/x86/boot/${KERNEL_BIN}",

	"br2   	=
		MAKE_PATH      : ${BR2_DIR},
		MAKE_DEFCONFIG : ${BR2_DEFCONFIG},
		MAKE_OUTDIR    : ${BR2_OUT},
		BUILD_OUTPUT   : target,
		BUILD_RESULT   : rootfs,
		BUILD_COMPLETE : br2_initrd",
)
