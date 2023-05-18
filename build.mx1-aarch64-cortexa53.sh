#!/bin/bash
# Copyright (c) 2018 Nexell Co., Ltd.
# Author: Junghyun, Kim <jhkim@nexell.co.kr>
#

BASE_DIR=$(realpath $(dirname $(realpath "$BASH_SOURCE"))/../..)

TARGET_ARCH="aarch64"
RESULT_DIR="${BASE_DIR}/result/${TARGET_ARCH}"
OUTPUT_DIR="${BASE_DIR}/output/${TARGET_ARCH}"

CROSS_COMPILE_DIR="${BASE_DIR}/tools/toolchain/gcc-11.0.1_aarch64-linux-gnu/bin"
CROSS_COMPILE_PREFIX=aarch64-linux-gnu-
CROSS_COMPILE="${CROSS_COMPILE_DIR}/${CROSS_COMPILE_PREFIX}"

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
#ATF_PLATFORM="mx1"
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
ATF_BL2_OPTIONS="BL2_AT_EL3=0"

# littlekernel
LK_DIR="${BASE_DIR}/lk"
LK_BUILDROOT="${OUTPUT_DIR}/lk"
LK_PROJECT="mx1-evb"
LK_DEBUG="DEBUG=2"
LK_TARGET_OPTION_SRAM=(
	"TARGET_MEMBASE_RAM=0"
	"KERNEL_RUN_EL1_SECURE=0"
	"WITH_SMP=1"
)

LK_TARGET_OPTION_DDR=(
	"TARGET_MEMBASE_RAM=1"
	"TARGET_RAM_SIZE=0x10000000"
	"KERNEL_RUN_EL1_SECURE=0"
	"WITH_SMP=1"
)
LK_TARGET_OPTION="${LK_TARGET_OPTION_DDR[*]}"
#LK_TARGET_OPTION="${LK_TARGET_OPTION_SRAM[*]}"

LK_OPTIONS=(
	"BUILDROOT=${LK_BUILDROOT}"
	"ARCH_arm64_TOOLCHAIN_PREFIX=${CROSS_COMPILE_PREFIX}"
	"ARCH_arm64_COMPILEFLAGS='-mno-outline-atomics -fno-stack-protector'"
	"NOECHO="
	"ARCH_OPTFLAGS=-Os"
	"${LK_TARGET_OPTION}"
	"${LK_DEBUG}"
)

# u-boot
UBOOT_DIR="${BASE_DIR}/u-boot"
UBOOT_OUT="${OUTPUT_DIR}/u-boot"
UBOOT_DEFCONFIG="mx1_defconfig"
#UBOOT_DEFCONFIG="qemu_arm64_defconfig"
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
	local dir="${RESULT_DIR}/qemu-$(cat ${path}/VERSION)"
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

function atf_copy_binary () {
	declare -n local var="${1}"
	local target=${var['MAKE_TARGET']}
	local out="${ATF_OUTPUT}"

	# copy to home
	[[ ${target} == bl1 ]] &&
		cp ${ATF_OUTPUT}/bl1.bin /data/jhk/deepx/m1/devel/rt_fw.git/firmware/build_fpga/dxfw_fpga.bin;

	if [[ ${target} == bl2 ]]; then
		opt=( ${var['MAKE_OPTION']} )
		for i in ${opt[*]}; do
			if echo "${i}" | grep -qw "BL2_AT_EL3"; then
				el3="$(echo ${i} | cut -d"=" -f 2)"
			fi
		done
		if [[ ${el3} == '1' ]]; then
			cp ${ATF_OUTPUT}/bl2.bin /data/jhk/deepx/m1/devel/rt_fw.git/firmware/build_fpga/dxfw_fpga.bin;
		else			
			cp ${ATF_OUTPUT}/bl2.bin /data/jhk/deepx/m1/devel/rt_fw/firmware/test_vector/npu0_vector.bin;
		fi
	fi

	if [[ ${target} == bl31 ]]; then
		cp ${ATF_OUTPUT}/bl31.bin /data/jhk/deepx/m1/devel/rt_fw/firmware/test_vector/dxfw_cm7_fpga.bin;
	fi

	return 0
}

function atf_complete () {
	declare -n local bsp="${1}"
	local target=${bsp['MAKE_TARGET']}
	local out="${ATF_OUTPUT}"

	logmsg " ${target} complete: $(pwd)"
	pushd ${out} > /dev/null 2>&1

	${CROSS_COMPILE}size -G -t --common $(find ./ -name "*.o") > "${out}/${target}.obj.size"
	${CROSS_COMPILE}size -G -t --common "${target}/${target}.elf" > "${out}/${target}.bin.size"

	popd > /dev/null 2>&1

	atf_copy_binary bsp
}

function atf_qemu_complete () {
	logmsg " ATF Complete: $(pwd)"
	pushd ${RESULT_DIR} > /dev/null 2>&1
	bash -c "rm bl33.bin"
	bash -c "ln -s ${BASE_DIR}/firmware/bios/QEMU_EFI_edk2.fd bl33.bin"
	popd > /dev/null 2>&1
}

function lk_copy_binary () {
	logmsg " LK Complete: $(pwd)"
#	cp ${RESULT_DIR}/lk.bin /home/jhk/deepx/m1/devel/rt_fw/firmware/build_asic/dxfw_asic.bin
#	cp ${RESULT_DIR}/lk.bin /data/jhk/deepx/m1/devel/rt_fw/firmware/test_vector/dxfw_cm7_fpga2.bin
#	cp ${RESULT_DIR}/lk.bin /data/jhk/deepx/m1/devel/rt_fw.git/firmware/build_fpga/dxfw_fpga.bin
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
	"CROSS_TOOL	= ${CROSS_COMPILE}",
	"RESULT_DIR = ${RESULT_DIR}",

	"qemu	=
		BUILD_MANUAL   : true,
		BUILD_PATH     : ${QEMU_DIR},
		BUILD_PREP     : qemu_prepare,
		BUILD_POST     : qemu_build,
		BUILD_COMPLETE : qemu_install,
		BUILD_CLEAN    : qemu_clean",

	"bl1 =
		MAKE_PATH      : ${ATF_DIR},
		MAKE_TARGET    : bl1,
		MAKE_OPTION    : ${ATF_OPTIONS[*]},
		BUILD_OUTPUT   : ${ATF_OUTPUT}/bl1.bin,
		BUILD_COMPLETE : atf_complete",

	"bl2 =
		MAKE_PATH      : ${ATF_DIR},
		MAKE_TARGET    : bl2,
		MAKE_OPTION    : ${ATF_OPTIONS[*]} ${ATF_BL2_OPTIONS},
		BUILD_OUTPUT   : ${ATF_OUTPUT}/bl2.bin,
		BUILD_COMPLETE : atf_complete",

	"bl31 =
		MAKE_PATH      : ${ATF_DIR},
		MAKE_TARGET    : bl31,
		MAKE_OPTION    : ${ATF_OPTIONS[*]},
		BUILD_OUTPUT   : ${ATF_OUTPUT}/bl31.bin,
		BUILD_COMPLETE : atf_complete",

	"lk =
		BUILD_MANUAL   : true,
		MAKE_PATH      : ${LK_DIR},
		MAKE_TARGET    : ${LK_PROJECT},
		MAKE_OPTION    : ${LK_OPTIONS[*]},
		MAKE_CLEANOPT  : ${LK_PROJECT},
		BUILD_OUTPUT   : ${LK_BUILDROOT}/build-${LK_PROJECT}/lk.bin; ${LK_BUILDROOT}/build-${LK_PROJECT}/lk.elf,
		BUILD_COMPLETE : lk_copy_binary",

	"uboot	=
		MAKE_PATH      : ${UBOOT_DIR},
		MAKE_DEFCONFIG : ${UBOOT_DEFCONFIG},
		MAKE_TARGET    : ${UBOOT_BIN},
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
		BUILD_RESULT   : ${ROOT_OUT}; disk.img",
)
