#!/bin/bash
#

BASE_DIR=$(realpath $(dirname $(realpath "$BASH_SOURCE"))/../..)
RESULT_TOP=${BASE_DIR}/result
RESULT_DIR=${RESULT_TOP}/qemu

QEMU_INSTALL=${RESULT_TOP}/tools/qemu-v6.1.0
LK_PROJECT=qemu-virt-arm64-test

QENU_SYSTEM=${QEMU_INSTALL}/usr/local/bin/qemu-system-aarch64
QEMU_CPU=cortex-a53
QEMU_MACHINE=virt,gic-version=2
QEMU_SMP=1
QEMU_TARGET=${RESULT_DIR}/lk.elf

${QENU_SYSTEM} -cpu ${QEMU_CPU} \
	-m 512 \
	-smp ${QEMU_SMP} \
	-machine ${QEMU_MACHINE} \
	-kernel ${QEMU_TARGET} \
	-net none \
	-nographic
