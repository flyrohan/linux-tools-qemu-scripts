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
KERNEL_OUT="${OUTPUT_DIR}/linux"
KERNEL_DEFCONFIG="x86_64_defconfig"
KERNEL_BIN="bzImage"

QEMU_DIR="${BASE_DIR}/qemu"
QEMU_OUT="${OUTPUT_DIR}/qemu"
QEMU_CONFIG=(
	"--target-list=x86_64-softmmu,x86_64-linux-user,i386-linux-user,i386-softmmu"
	"--prefix=/usr"
	"--enable-debug"
)

ROOT_DIR="${RESULT_DIR}/rootfs"
ROOT_INITRD="${RESULT_DIR}/initrd.img"

function qemu_prepare () {
	declare -n local var="${1}"
	local path=${var['BUILD_PATH']}
	local name=$(basename ${path})
	local out="${OUTPUT_DIR}/${name}"

	logmsg " - QEMU prepare : ${name}"
	mkdir -p ${out}
	pushd ${out} > /dev/null 2>&1
	bash -c "${path}/configure ${QEMU_CONFIG[*]}"
	popd > /dev/null 2>&1
}

function qemu_build () {
	declare -n local var="${1}"
	local name=$(basename ${var['BUILD_PATH']})
	local out="${OUTPUT_DIR}/${name}"
	local ret

	logmsg " - QEMU build : ${name}"
	pushd ${out} > /dev/null 2>&1
	bash -c "make -j$(grep -c processor /proc/cpuinfo) V=1"
	ret=${?}
	popd > /dev/null 2>&1

	return ${ret}
}

function qemu_install () {
	declare -n local var="${1}"
	local path=${var['BUILD_PATH']}
	local out="${OUTPUT_DIR}/$(basename ${path})"
	local dir="${RESULT_TOP}/tools/qemu-$(cat ${path}/VERSION)"
	local ret

	logmsg " - QEMU install: ${dir}"
	mkdir -p ${dir}

	pushd ${out} > /dev/null 2>&1
	bash -c "make install DESTDIR=${dir}"
	ret=${?}
	popd > /dev/null 2>&1

	return ${ret}
}

function qemu_clean () {
	declare -n local var="${1}"
	local out="${OUTPUT_DIR}/$(basename ${var['BUILD_PATH']})"

	logmsg " QEMU clean : ${out}"
	pushd ${out} > /dev/null 2>&1
	bash -c "make distclean"
	popd > /dev/null 2>&1
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
		BUILD_PATH     : ${QEMU_DIR},
		BUILD_PREP     : qemu_prepare,
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
