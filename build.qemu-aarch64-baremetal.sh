#!/bin/bash
# Copyright (c) 2018 Nexell Co., Ltd.
# Author: Junghyun, Kim <jhkim@nexell.co.kr>
#

BASE_DIR=$(realpath $(dirname $(realpath "$BASH_SOURCE"))/../..)
RESULT_TOP="${BASE_DIR}/result"
OUTPUT_TOP="${BASE_DIR}/output"
TARGET_ARCH="aarch64"
RESULT_DIR="${RESULT_TOP}/${TARGET_ARCH}"
OUTPUT_DIR="${OUTPUT_TOP}/${TARGET_ARCH}"

TOOLCHAIN_DIR="${BASE_DIR}/tools/toolchain/gcc-11.0.1_aarch64-linux-gnu/bin"
TOOLCHAIN_PREFIX=aarch64-linux-gnu-
TOOLCHAIN_LINUX="${TOOLCHAIN_DIR}/${TOOLCHAIN_PREFIX}"

TOOLS_DIR="${BASE_DIR}/tools"
TOOLS_SCRIPT_DIR="${TOOLS_DIR}/scripts"
TOOLS_SCRIPT_COMMON_DIR="${TOOLS_DIR}/common"

# qemu
QEMU_DIR="${BASE_DIR}/qemu"
QEMU_OUT="${OUTPUT_DIR}/qemu"
QEMU_CONFIG=(
	"--target-list=aarch64-softmmu,aarch64-linux-user"
	"--prefix=/usr"
	"--enable-debug --enable-debug-info"
	"--enable-gprof --enable-profiler"
)

# arm-trust-firmware
ATF_DIR="${BASE_DIR}/atf"
ATF_OUT="${OUTPUT_DIR}/atf"
ATF_PLATFORM="qemu"
ATF_DEBUG="DEBUG=1"
ATF_OUTPUT="${ATF_OUT}/${ATF_PLATFORM}/release"
if [[ -n ${ATF_DEBUG} ]]; then
	mode=$(echo ${ATF_DEBUG} | grep -w "DEBUG")
	[[ -n ${mode} ]] && mode=$(echo ${mode} | cut -d"=" -f 2);
	[[ $((mode)) -gt '0' ]] && ATF_OUTPUT="${ATF_OUT}/${ATF_PLATFORM}/debug";
fi	
ATF_OPTIONS=(
	"PLAT=${ATF_PLATFORM} BUILD_BASE=${ATF_OUT}"
	"${ATF_DEBUG}"
)

# littlekernel
LK_DIR="${BASE_DIR}/lk"
LK_BUILDROOT="${OUTPUT_DIR}/lk"
LK_PROJECT="qemu-virt-arm64-test"
LK_DEBUG="DEBUG=2"
LK_OPTIONS=(
	"BUILDROOT=${LK_BUILDROOT}"
	"ARCH_arm64_TOOLCHAIN_PREFIX=${TOOLCHAIN_PREFIX}"
	"ARCH_arm64_COMPILEFLAGS='-mno-outline-atomics -fno-stack-protector'"
	"LK_HEAP_IMPLEMENTATION=miniheap"
	"NOECHO="
	"ARCH_OPTFLAGS=-Os"
	"${LK_DEBUG}"
)

# u-boot
UBOOT_DIR="${BASE_DIR}/u-boot"
UBOOT_OUT="${OUTPUT_DIR}/u-boot"
UBOOT_DEFCONFIG="qemu_arm64_defconfig"
UBOOT_BIN="u-boot.bin"

# buildroot configs
BR2_PATH=buildroot
BR2_DIR="${BASE_DIR}/${BR2_PATH}"
BR2_OUT="${OUTPUT_DIR}/${BR2_PATH}"
BR2_DEFCONFIG="qemu_aarch64_tiny_defconfig"
BR2_SDK="sdk-buildroot-${TARGET_ARCH}"

# linux kernel
KERNEL_DIR="${BASE_DIR}/linux"
KERNEL_OUT="${OUTPUT_DIR}/linux"
# default search from <linux>/arch/arm64/configs/
KERNEL_DEFCONFIG="../../../../${BR2_PATH}/board/rohan/configs/linux_selinux_defconfig"
KERNEL_BIN="Image"

# root image
ROOT_OUT="root"
ROOT_OUTPUT="${RESULT_DIR}/${ROOT_OUT}"
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

function atf_complete () {
	logmsg " ATF Complete: $(pwd)"
	pushd ${RESULT_DIR} > /dev/null 2>&1
	bash -c "rm bl33.bin"
	bash -c "ln -s ${BASE_DIR}/firmware/bios/QEMU_EFI_edk2.fd bl33.bin"
	popd > /dev/null 2>&1
}

function br2_initrd () {
	logmsg " Build initrd: $(pwd)"
	${TOOLS_SCRIPT_COMMON_DIR}/mk_ramimg.sh -r ${ROOT_OUTPUT} -o ${ROOT_INITRD}
}

function lk_clean () {
	declare -n local var="${1}"
	local project=${var['MAKE_TARGET']}

	logmsg " LK Clean: ${project} "
	eval "make -C ${LK_DIR} BUILDROOT=${LK_BUILDROOT} ${project} clean"
}

function uboot_complete () {
	logmsg " U-BOOT Complete: $(pwd)"
	pushd ${RESULT_DIR} > /dev/null 2>&1
	bash -c "rm bl33.bin"
	bash -c "ln -s ${UBOOT_BIN} bl33.bin"
	popd > /dev/null 2>&1
}
###############################################################################
# Build Image and Targets
###############################################################################
BUILD_IMAGES=(
	"CROSS_TOOL	= ${TOOLCHAIN_LINUX}",
	"RESULT_DIR = ${RESULT_DIR}",

	"qemu	=
		BUILD_MANUAL   : true,
		BUILD_PATH     : ${QEMU_DIR},
		BUILD_PREP     : qemu_prepare,
		BUILD_POST     : qemu_build,
		BUILD_COMPLETE : qemu_install,
		BUILD_CLEAN    : qemu_clean",

	"atf =
		MAKE_PATH      : ${ATF_DIR},
		MAKE_OPTION    : ${ATF_OPTIONS[*]},
		BUILD_OUTPUT   : ${ATF_OUTPUT}/bl1.bin; ${ATF_OUTPUT}/bl2.bin; ${ATF_OUTPUT}/bl31.bin,
		BUILD_COMPLETE : atf_complete",

	"lk =
		MAKE_PATH      : ${LK_DIR},
		MAKE_TARGET    : ${LK_PROJECT},
		MAKE_OPTION    : ${LK_OPTIONS[*]},
		MAKE_CLEANOPT  : ${LK_PROJECT},
		BUILD_OUTPUT   : ${LK_BUILDROOT}/build-${LK_PROJECT}/lk.bin; ${LK_BUILDROOT}/build-${LK_PROJECT}/lk.elf",

	"uboot	=
		MAKE_PATH      : ${UBOOT_DIR},
		MAKE_DEFCONFIG : ${UBOOT_DEFCONFIG},
		MAKE_TARGET    : ${UBOOT_BIN},
		MAKE_OUTDIR    : ${UBOOT_OUT},
		BUILD_OUTPUT   : ${UBOOT_BIN},
		BUILD_COMPLETE : uboot_complete",

	"kernel	=
		MAKE_ARCH      : arm64,
		MAKE_PATH      : ${KERNEL_DIR},
		MAKE_DEFCONFIG : ${KERNEL_DEFCONFIG},
		MAKE_TARGET    : ${KERNEL_BIN},
		MAKE_OUTDIR    : ${KERNEL_OUT},
		BUILD_OUTPUT   : arch/arm64/boot/${KERNEL_BIN}",

	"br2   	=
		MAKE_PATH      : ${BR2_DIR},
		MAKE_DEFCONFIG : ${BR2_DEFCONFIG},
		MAKE_OUTDIR    : ${BR2_OUT},
		BUILD_OUTPUT   : target; images/disk.img,
		BUILD_RESULT   : ${ROOT_OUT}; disk.img,
		BUILD_COMPLETE : br2_initrd",

	"sdk =
		BUILD_MANUAL   : true,
		BUILD_DEPEND   : br2,
        MAKE_NOCLEAN   : true,
		MAKE_PATH      : ${BR2_DIR},
		MAKE_TARGET    : sdk,
		MAKE_OPTION    : BR2_SDK_PREFIX=${BR2_SDK},
		MAKE_OUTDIR    : ${BR2_OUT},
		BUILD_OUTPUT   : images/${BR2_SDK}.tar.gz",
)
