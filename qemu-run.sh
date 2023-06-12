#!/bin/bash
#

ROOT_DIR=$(realpath $(dirname $(realpath "$BASH_SOURCE"))/../../)
IMAGE_DIR="${ROOT_DIR}/down"

#BIN_DIR="${ROOT_DIR}/result/tools/qemu-6.1.1/usr/bin"
BIN_DIR="${ROOT_DIR}/result/tools/qemu-8.0.2/usr/bin"
QEMU_SYSTEM_EXE="${BIN_DIR}/qemu-system-x86_64"
#QEMU_SYSTEM_EXE="qemu-system-x86_64"
#QEMU_SYSTEM_EXE="kvm"

###############################################################################
# QEMU options
################################################################################
#
# log
#
QEMU_LOG_DUMP_FILE="qemu-guest.log"
QEMU_LOG_DUMP=(
	"-chardev stdio,mux=on,logfile=${QEMU_LOG_DUMP_FILE},id=char0"
	"-mon chardev=char0,mode=readline"
	"-serial chardev:char0"
)

#
# Network (NAT or Bridge)
#
QEMU_NET_NAT="-netdev tap,id=nd0,ifname=tap0,script=no,downscript=no -device e1000,netdev=nd0"
QEMU_NET_BRIDGE="-net nic -net tap,script=${ROOT_DIR}/tools/scripts/qemu-ifup"
QEMU_DEVICE_NET=( ${QEMU_NET_NAT} )

# Graphic
#
# https://discourse.ubuntu.com/t/virtualisation-with-qemu/11523
QEMU_DEVICE_DISPLAY=(
	"-vga virtio"			# Graphis - frontend
	"-display gtk,gl=on"	# Graphis - backend (gtk or vnc)
)

#
# PCIe - PassThrough withvfio-pci
#
PCIE_DEVICE_VENDOR="Synopsys"
PCIE_DEVICE_ID="$(lspci | grep ${PCIE_DEVICE_VENDOR} | cut -d' ' -f 1)"
QEMU_DEVICE_PCIE_PT=(
	# PassThrough PCIE
	"-machine q35,accel=kvm,kernel-irqchip=split" # ,acpi=off"
	"-device intel-iommu,intremap=on,caching-mode=on" #,eim=off,dma-translation=off,device-iotlb=on,pt=off"

	"-device vfio-pci,host=${PCIE_DEVICE_ID}" #,x-msix-relocation=bar1" # x-no-kvm-msi=on,x-no-kvm-msix=on,x-req=off,x-no-kvm-intx=on"
)

# Monitor
# host connect
#	"-chardev socket,id=monitor0,server=on,wait=off,telnet=on,host=192.168.0.59,port=1234,ipv4=on,ipv6=off"
#  $ nc <host ip> <port>
QEMU_MONITOR_SOCKET=(
	"-mon chardev=monitor0"
	"-chardev socket,id=monitor0,server=on,wait=off,telnet=on,host=$(hostname -i | awk '{print $1}'),port=1234"
)

QEMU_MONITOR=( ${QEMU_MONITOR_SOCKET[*]} )

###############################################################################
# Linux + buildroot
###############################################################################
TARGET_ARCH="x86_64"
QEMU_LINUX_ARGS="root=/dev/ram rdinit=/init rw console=ttyS0 oops=panic panic=1 nokaslr iommu.passthrough=1"
QEMU_LINUX_KERNEL="${ROOT_DIR}/result/${TARGET_ARCH}/bzImage"
QEMU_LINUX_ROOTFS="${ROOT_DIR}/result/${TARGET_ARCH}/rootfs.cpio"

QEMU_LINUX_ROOTFS_RUN=(
#	"sudo gdb --args ${QEMU_SYSTEM_EXE}"
	"${QEMU_SYSTEM_EXE}"
	"-enable-kvm"
	"-cpu host"    # "-cpu max" "-cpu qemu64,+x2apic" "-cpu host,+x2apic" "-cpu qemu64,arch-capabilities=on,hypervisor=on"
	"-smp 2"
	"-m 1G"		# memory
	"-kernel ${QEMU_LINUX_KERNEL}"
	"-initrd ${QEMU_LINUX_ROOTFS}"
	"-append '${QEMU_LINUX_ARGS}'"
	"${QEMU_DEVICE_NET[*]}"
	"${QEMU_DEVICE_PCIE_PT[*]}"
	"-nographic"
	"-s"
	"-bios ${ROOT_DIR}/output/x86_64/buildroot-2023.02/images/OVMF.fd"
	"${QEMU_MONITOR[*]}"
)

declare -A QEMU_LINUX_BAREMETAL=(
	["sudo"]=true
	["name"]="linux"
	["descript"]="Linux bare-metal (linux and root image)"
	["run"]="${QEMU_LINUX_ROOTFS_RUN[*]}"
)

###############################################################################
# ubuntu-20.04 ISO - server
# - wget "https://releases.ubuntu.com/20.04.6/ubuntu-20.04.6-live-server-amd64.iso"
###############################################################################
UBUNTU_20_04_SERVER_NAME="ubuntu-20.04.6-live-server-amd64"
QEMU_UBUNTU_20_04_SERVER_ISO="${IMAGE_DIR}/${UBUNTU_20_04_SERVER_NAME}.iso"
QEMU_UBUNTU_20_04_SERVER_RAW="${IMAGE_DIR}/${UBUNTU_20_04_SERVER_NAME}.raw"

QEMU_UBUNTU_20_04_SERVER_INSTALL=(
	"${QEMU_SYSTEM_EXE}"
	"-enable-kvm"
	"-cpu host"
	"-m 1G"
	"-boot d"	# must: 'd' CDROM, 'c' Hard disk
	"-cdrom ${QEMU_UBUNTU_20_04_SERVER_ISO}"
	"-drive file=${QEMU_UBUNTU_20_04_SERVER_RAW},format=raw"
	"${QEMU_DEVICE_NET[*]}"
)

QEMU_UBUNTU_20_04_SERVER_RUN=(
	"${QEMU_SYSTEM_EXE}"
	"-enable-kvm"
	"-cpu host"
	"-smp 2"
	"-m 1G"		# memory
	"-drive file=${QEMU_UBUNTU_20_04_SERVER_RAW},format=raw"
	"${QEMU_DEVICE_NET[*]}"
	"${QEMU_DEVICE_PCIE_PT[*]}"
	"${QEMU_DEVICE_DISPLAY[*]}"
	"-s"
)

declare -A QEMU_UBUNTU_20_04_SERVER=(
	["sudo"]=true
	["name"]="u20s"
	["descript"]="Ubuntu20.04.6 server"
	["down"]="wget https://releases.ubuntu.com/20.04.6/${UBUNTU_20_04_SERVER_NAME}.iso -O ${QEMU_UBUNTU_20_04_SERVER_ISO}"
	["iso"]="${QEMU_UBUNTU_20_04_SERVER_ISO}"
	["raw"]="${QEMU_UBUNTU_20_04_SERVER_RAW}"
	["size"]=20G
	["install"]="${QEMU_UBUNTU_20_04_SERVER_INSTALL[*]}"
	["run"]="${QEMU_UBUNTU_20_04_SERVER_RUN[*]}"
)

###############################################################################
# ubuntu-20.04 ISO - desktop
# - wget "https://releases.ubuntu.com/20.04.6/ubuntu-20.04.6-desktop-amd64.iso"
###############################################################################
UBUNTU_20_04_DESKTOP_NAME="ubuntu-20.04.6-desktop-amd64"
QEMU_UBUNTU_20_04_DESKTOP_ISO="${IMAGE_DIR}/${UBUNTU_20_04_DESKTOP_NAME}.iso"
QEMU_UBUNTU_20_04_DESKTOP_RAW="${IMAGE_DIR}/${UBUNTU_20_04_DESKTOP_NAME}.raw"

QEMU_UBUNTU_20_04_DESKTOP_INSTALL=(
	"${QEMU_SYSTEM_EXE}"
	"-enable-kvm"
	"-cpu host"
	"-m 1G"
	"-boot d"	# must: 'd' CDROM, 'c' Hard disk
	"-cdrom ${QEMU_UBUNTU_20_04_DESKTOP_ISO}"
	"-drive file=${QEMU_UBUNTU_20_04_DESKTOP_RAW},format=raw"
	"${QEMU_DEVICE_NET[*]}"
)

QEMU_UBUNTU_20_04_DESKTOP_RUN=(
	"${QEMU_SYSTEM_EXE}"
	"-enable-kvm"
	"-cpu host"
	"-smp 2"
	"-m 1G"		# memory
	"-drive file=${QEMU_UBUNTU_20_04_DESKTOP_RAW},format=raw"
	"${QEMU_DEVICE_NET[*]}"
	"${QEMU_DEVICE_PCIE_PT[*]}"
	"${QEMU_DEVICE_DISPLAY[*]}"
	"-s"
)

declare -A QEMU_UBUNTU_20_04_DESKTOP=(
	["sudo"]=true
	["name"]="u20d"
	["descript"]="Ubuntu20.04.6 desktop"
	["down"]="wget https://releases.ubuntu.com/20.04.6/${UBUNTU_20_04_DESKTOP_NAME}.iso -O ${QEMU_UBUNTU_20_04_DESKTOP_ISO}"
	["iso"]="${QEMU_UBUNTU_20_04_DESKTOP_ISO}"
	["raw"]="${QEMU_UBUNTU_20_04_DESKTOP_RAW}"
	["size"]=20G
	["install"]="${QEMU_UBUNTU_20_04_DESKTOP_INSTALL[*]}"
	["run"]="${QEMU_UBUNTU_20_04_DESKTOP_RUN[*]}"
)

###############################################################################
# Set targets
# declare -n QEMU_TARGET=QEMU_UBUNTU_20_04
###############################################################################

QEMU_TARGET_LISTS=(
	QEMU_UBUNTU_20_04_SERVER
	QEMU_UBUNTU_20_04_DESKTOP
	QEMU_LINUX_BAREMETAL
)
declare -A QEMU_TARGET

function logerr () { echo -e "\033[0;31m$*\033[0m"; }
function logmsg () { echo -e "\033[0;33m$*\033[0m"; }
function logext () { echo -e "\033[0;31m$*\033[0m"; exit -1; }

function exec_cmd () {
	local cmd=${1} root=${2}
	local su="sudo";

	cmd="$(echo "${cmd}" | tr '\n' ' ')"
	cmd="$(echo "${cmd}" | sed 's/^[ \t]*//;s/[ \t]*$//')"

	if [[ ${root} != true ]] || [[ $(whoami) == "root" ]]; then
		su="";
	fi

	logmsg "$ ${cmd}"
	${su} bash -c "${cmd}"
}

# copy array from src to dst : $1=src $2=dst
function qemu_set_target () {
    set -- "$(declare -p $1)" "$2"
    eval "$2=${1#*=}"
}

###############################################################################
# Build Function
###############################################################################

function qemu_download () {
	[[ -f ${QEMU_TARGET["iso"]} || -z ${QEMU_TARGET["down"]} ]] && return;

	mkdir -p ${IMAGE_DIR}

	logmsg "Download: ${QEMU_TARGET["down"]}"
	exec_cmd "${QEMU_TARGET["down"]}"
}

function qemu_install_iso () {
	[[ -z ${QEMU_TARGET["iso"]} ]] && return;

	qemu_download

	[[ ! -f ${QEMU_TARGET["iso"]} ]] && logext "Not found ISO : ${QEMU_TARGET["iso"]} !!!";

	logmsg "Create hard disk: ${QEMU_TARGET["raw"]} (${QEMU_TARGET["size"]})"
	if [[ -f ${QEMU_TARGET["raw"]} ]]; then
		echo -en "\033[0;31mExist Hard Disk, Overwrite [y/n] : \033[0m";
		read answer
		[[ "${answer}" != "y" ]] && return;
	fi

	exec_cmd "qemu-img create ${QEMU_TARGET["raw"]} ${QEMU_TARGET["size"]}"
	wait;

	logmsg "Install: ${QEMU_TARGET["iso"]}"
	exec_cmd "${QEMU_TARGET["install"]}"
	[[ ${?} ]] && exit 1;
}

function qemu_run  () {
	local opt=( "-pidfile vm-${QEMU_TARGET["name"]}.pid" )
	[[ -n ${1} ]] && opt+=( ${1} );

	logmsg "Run: ${QEMU_TARGET["raw"]}"
	[[ -f ${QEMU_LOG_DUMP_FILE} ]] && rm -f ${QEMU_LOG_DUMP_FILE};

	exec_cmd "${QEMU_TARGET["run"]} ${opt[*]}" "${QEMU_TARGET["sudo"]}"
	[[ ${?} ]] && exit 1;
}

function qemu_kill () {
	pid=$(pidof ${QEMU_SYSTEM_EXE})

	if [[ ${pid} ]]; then
		user=$(ps -o user= -p ${pid})
		echo "Kill ${QEMU_SYSTEM_EXE} pid [${user}:${pid}]"
		[[ ${user} == root ]] && _sudo_=${su}
		bash -c "${_sudo_} kill ${pid}"
	else
		echo "No such process ${QEMU_SYSTEM_EXE}"
	fi
}

declare -A __qemu_functions=(
	["install"]=qemu_install_iso
	["delete"]=qemu_delete_image
	["run"]=qemu_run
	["kill"]=qemu_kill
)

function usage () {
	echo " Usage:"
	echo -e  "\t$(basename "${0}") [options]"
	echo -e  ""
	echo -e  " options:"
	echo -e  "\t-t [target]\tselect target"
	for i in "${QEMU_TARGET_LISTS[@]}"; do
		declare -n t=${i}
		echo -e "\t\t\t- ${t["name"]}\t: ${t["descript"]}";
	done
	echo -e "\t-c [command]\t${!__qemu_functions[@]}"
	echo -e  "\t-d\t\tlog dump to '${QEMU_LOG_DUMP_FILE}'"
	echo -e  "\t-v\t\tcommand verbose"
	echo ""
	exit 1;
}

function qemu_execute () {
	local target="" cmd=""
	local func="" options="" debug="";

	while getopts "t:c:dvh" opt; do
	case ${opt} in
		t )	target=${OPTARG};;
		c )	cmd=${OPTARG};;
		d )	options+=( ${QEMU_LOG_DUMP[*]} );;
		v ) debug="> /dev/null";;
		h )	usage;;
		*)	exit 1;;
	esac
	done

	for i in ${QEMU_TARGET_LISTS[@]}; do
		declare -n t=${i}
		if [[ ${t["name"]} == ${target} ]]; then
			qemu_set_target ${i} QEMU_TARGET
			break;
		fi
	done

	if [[ -z ${QEMU_TARGET[@]} ]]; then
		logerr "Not support qemu target : ${target} !!!"
		usage;
	fi

	for i in ${!__qemu_functions[@]}; do
		if [[ ${i} == ${cmd} ]]; then
			func=${__qemu_functions[${i}]}
		fi
	done

	if [[ -z ${func} ]]; then
		logerr "Unknown command : ${cmd} !!!"
		usage;
	fi

	${func} "${options[*]} ${debug}"
}

qemu_execute "${@}"
