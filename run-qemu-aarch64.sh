#!/bin/bash

BASE_DIR=$(realpath $(dirname $(realpath "$BASH_SOURCE"))/../../)
QEMU_VERSION="v6.1.0" # v5.1.0-rc3-aarch64, v6.10
QEMU_INSTALL="${BASE_DIR}/result/tools/qemu-${QEMU_VERSION}"
QEMU_SRC="${BASE_DIR}/qemu"
QEMU_OUT="${BASE_DIR}/result/qemu"
QEMU_BIN="${QEMU_INSTALL}/usr/local/bin"

qemu_system="qemu-system-aarch64"

QEMU_KERNEL="-kernel ${QEMU_OUT}/Image"
# execute on host pc $> vinagre :5900
#QEMU_DEVICE_GRAPHIC="-device virtio-gpu-pci -vnc localhost:0 -serial stdio" # '-vnc :0"
#QEMU_DEVICE_GRAPHIC="-device virtio-gpu-pci -spice port=5900 -serial stdio" # '-vnc :0"
QEMU_DEVICE_GRAPHIC="-serial stdio -device virtio-gpu-pci -vnc localhost:0 " # '-vnc :0"
QEMU_DEVICE_NET="-net nic -net tap,ifname=tap0"
QEMU_NET_HOST=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
QEMU_NET_GW="192.168.1.254"
QEMU_NET_MASK="255.255.255.0"
QEMU_GDB_NET_PORT="tcp::1234"
QEMU_GDB_WAIT="-s -S"
QEMU_KGDB_WAIT="kgdboc=ttyAMA0,115200 kgdbwait"
QEMU_BOOT_COMMAND=""
QEMU_DTB_DUMP="devicetree.dtb"
QEMU_DTS_DUMP="devicetree.dts"
QEMU_ROOT_IMAGE_NFS="${QEMU_OUT}/rootfs"
QEMU_ROOT_IMAGE_RDINIT="${QEMU_OUT}/initrd.img"
QEMU_ROOT_IMAGE_DISK="${QEMU_OUT}/disk.img"
QEMU_ROOT_IMAGE_FSIMAGE="${QEMU_OUT}/rootfs.ext2"

QEMU_OPT_CONSOLE="console=ttyAMA0"
QEMU_OPT_NET_IP="192.168.1.151"
QEMU_OPT_APPEND=""
QEMU_OPT_OPTION=""

# initrd's kernel image contains the root file system, so not need image macros.
declare -A QEMU_ROOT_INITRD=(
	["boot"]="--append '${QEMU_OPT_CONSOLE} root=/dev/ram rdinit=/init'"
	["opt"]=""
)

declare -A QEMU_ROOT_RDINIT=(
	["image"]="-initrd QEMU_ROOT_IMAGE"
	["boot"]="--append \"root=/dev/ram rdinit=/init QEMU_BOOT_COMMAND\""
	["disk0"]="-drive file=${QEMU_ROOT_IMAGE_FSIMAGE},format=raw,id=hd0"
#	["opt"]="-serial pty"
)

declare -A QEMU_ROOT_NFS=(
	["boot"]="--append \"${QEMU_OPT_CONSOLE} \
		root=/dev/nfs rw \
		nfsroot=${QEMU_NET_HOST}:QEMU_ROOT_IMAGE,tcp,v3 \
		ip=QEMU_OPT_NET_IP:${QEMU_NET_HOST}:${QEMU_NET_GW}:${QEMU_NET_MASK} QEMU_BOOT_COMMAND\""
	["opt"]="${QEMU_DEVICE_NET}"
)

# The disk image contains the kernel and root file system.
declare -A QEMU_ROOT_DISK=(
	["image"]="-drive file=QEMU_ROOT_IMAGE,format=raw,id=hd0"
        ["bios"]="-bios ${BASE_DIR}/firmware/bios/QEMU_EFI.fd" # /usr/share/qemu-efi/QEMU_EFI.fd
#	["bios"]="-L ${QEMU_SRC}/build/pc-bios"
#	["bios"]="-bios ${QEMU_SRC}/build/pc-bios/efi-virtio.rom"
	["opt"]=""
)

declare -A QEMU_COMMAND_ARCH=(
	["cpu"]="-cpu cortex-a57"
	["machine"]="-machine virt"
	["smp"]="-smp 2"
	["mem"]="-m 2048"	# 2G
	["kernel"]="${QEMU_KERNEL}"
	["acpi"]="-no-acpi"         # defalult ACPI replace DT
	["dtb"]=""
	["graphic"]="-nographic"
	["net"]=""
)

declare -A QEMU_COMMAND_ROOT

QEMU_ROOT_IMAGE=""
QEMU_NEW_TERMINAL=false
QEMU_TEST=false
QEMU_COMMAND_RUN=""

# for nfs
qemu_run_sudo=""

function msg () { echo -e "\033[0;33m$*\033[0m"; }
function err () { echo -e "\033[0;31m$*\033[0m"; }

function qemu_env () {
	msg ""
        if [[ -d ${QEMU_BIN} ]]; then
                export PATH=${QEMU_BIN}:${PATH}
	        msg "QEMU PATH       ${QEMU_INSTALL}"
        else
	        msg "QEMU PATH       Use host qemu"
        fi

	qemu_version=$(${qemu_system} --version | grep version|awk '{print $NF}')
	msg "QEMU VERSION    $qemu_version"
}

function qemu_check_nfs () {
	local fs=$(realpath ${1})
	if ! sudo exportfs | grep -qw "${fs}"; then
		echo "Not export nfs: ${fs}"
		exit 
	fi
}

function qemu_parse () {
	for key in ${!QEMU_COMMAND_ROOT[@]}; do
		QEMU_COMMAND_ROOT[${key}]=$(echo ${QEMU_COMMAND_ROOT[${key}]/QEMU_ROOT_IMAGE/"${QEMU_ROOT_IMAGE}"})
		QEMU_COMMAND_ROOT[${key}]=$(echo ${QEMU_COMMAND_ROOT[${key}]/QEMU_OPT_NET_IP/"${QEMU_OPT_NET_IP}"})
		QEMU_COMMAND_ROOT[${key}]=$(echo ${QEMU_COMMAND_ROOT[${key}]/QEMU_BOOT_COMMAND/"${QEMU_BOOT_COMMAND}"})
	done

	QEMU_COMMAND_RUN="${QEMU_COMMAND_ARCH[@]} ${QEMU_COMMAND_ROOT[@]} ${QEMU_OPT_APPEND} ${QEMU_OPT_OPTION}"
	
	msg ""
	msg "QEMU_CPU        ${QEMU_COMMAND_ARCH["cpu"]}"
	msg "QEMU_MACHINE    ${QEMU_COMMAND_ARCH["machine"]}"
	msg "QEMU_SMP        ${QEMU_COMMAND_ARCH["smp"]}"
	msg "QEMU_MEM        ${QEMU_COMMAND_ARCH["mem"]}"
	msg "QEMU_KERNEL     ${QEMU_COMMAND_ARCH["kernel"]}"
	msg "QEMU_DTB        ${QEMU_COMMAND_ARCH["dtb"]}"
	msg "QEMU_GRAPHIC    ${QEMU_COMMAND_ARCH["graphic"]}"
	msg "QEMU_NET        ${QEMU_COMMAND_ARCH["net"]}"
	msg "QEMU_OPT        ${QEMU_OPT_OPTION}"
	msg ""

	QEMU_COMMAND_RUN="$(echo "${QEMU_COMMAND_RUN}" | sed 's/^[ \t]*//;s/[ \t]*$//')"
	QEMU_COMMAND_RUN="$(echo "${QEMU_COMMAND_RUN}" | sed 's/\s\s*/ /g')"
	QEMU_COMMAND_RUN="$(echo "${QEMU_COMMAND_RUN}" | tr -d '\n')"

	msg "$> ${qemu_run_sudo} ${qemu_system} ${QEMU_COMMAND_RUN}\n"
	[[ ${QEMU_TEST} == true ]] && exit 0;
}

function qemu_run () {
	local command="${QEMU_COMMAND_RUN}"
	
	[[ -z ${command} ]] && exit 1;

	if [[ ${QEMU_COMMAND_ARCH["graphic"]} != "-nographic" ]]; then
		sleep 2;
		if [[ $(pidof ${qemu_system}) ]]; then
			msg "$> vinagre :5900\n"
			gnome-terminal -- bash -c "vinagre :5900"
		fi
	fi

	if [[ ${QEMU_NEW_TERMINAL} == true ]]; then
		gnome-terminal -- bash -c "${qemu_run_sudo} ${qemu_system} ${command}" &
	else
		bash -c "${qemu_run_sudo} ${qemu_system} ${command}"
	fi
}

function qemu_stop () {
	local pid=$(pidof ${qemu_system})

	if [[ ${pid} ]]; then
		user=$(ps -o user= -p ${pid})
		echo "Kill ${qemu_system} pid [$user:${pid}]"
		[[ $user == root ]] && qemu_run_sudo=sudo
		bash -c "${qemu_run_sudo} kill ${pid}"
	        if [[ ${QEMU_COMMAND_ARCH["graphic"]} != "-nographic" ]]; then
			pid=$(pidof vinagre)
			if [[ ${pid} ]]; then
				user=$(ps -o user= -p ${pid})
				[[ $user == root ]] && qemu_run_sudo=sudo
				echo "Kill vinagre pid [$user:${pid}]"
				bash -c "${qemu_run_sudo} kill ${pid}"
			fi
		fi
	else
		echo "No such process ${qemu_system}"
	fi
}

PROGNAME=${0##*/}
function usage() {
cat << EO
 Usage: $PROGNAME [options]
	Options:
EO
cat <<EO | column -s\& -t
        -k|--kernel [kernel]       kernel: ${QEMU_COMMAND_ARCH["kernel"]} with graphic
        -d|--dtb [dtb]             set dtb: ${QEMU_COMMAND_ARCH["dtb"]}
        -s|--smp [cores]           cpu cores: ${QEMU_COMMAND_ARCH["smp"]}
        -m|--mem [size]            memory size: ${QEMU_COMMAND_ARCH["mem"]}
        -gdb <s>	           run GDB with port. <s> is stop option ${QEMU_GDB_NET_PORT}
        -kgdb		           run KGDB and wait connect KGDB
        -nfs [root]	           nfs root, [root] is option: ${QEMU_ROOT_NFS["root"]}
        -disk [image]	           disk image, [disk] is option: ${QEMU_ROOT_DISK["root"]}
        -rd [rdinit]	           rdinit image, [rdinit] is option: ${QEMU_ROOT_DISK["root"]}
        -n|-net		   	   set network option
        -g|-graphic                enable graphic device
        -ip [ipaddr]	           nfs device ip: ${QEMU_ROOT_NFS["ip"]}
	-append [option]	   add append to ${QEMU_OPT_APPEND}
	-boot [option]		   add boot command ${QEMU_OPT_APPEND}
	-opt [option]		   add option
        -kill|--kill               kill ${qemu_system} program to stop
	-dumpdtb|--dumpdtb [dtb]   dump devicetree to ${QEMU_DTB_DUMP}
	-ds|--ds [dtb,dts]         devicetree bin to devicetree source, ${QEMU_DTB_DUMP} -> ${QEMU_DTS_DUMP}
	-sd|--sd [dts,dtb]         devicetree source to devicetree bin, ${QEMU_DTS_DUMP} -> ${QEMU_DTB_DUMP}
	-tty                       execute ${qemu_system} new terminal
	-test			   no execute ${qemu_system}
EO
}

function dtb2dts () {
	local dtb=${1} dts=${2}
	if [[ ! -f ${dtb} ]]; then
		err "Not found dtb: ${dtb}, first run '-dumpdtb'"
		exit 1;
	fi 
	msg "dtb to dts : ${dtb} -> ${dts}"
	bash -c "dtc -I dtb -O dts -o ${dts} ${dtb}"
}

function dts2dtb () {
	local dtb=${1} dts=${2}
	if [[ ! -f ${dts} ]]; then
		err "Not found dts: ${dts}"
		exit 1;
	fi 
	msg "dts to dtb : ${dts} -> ${dtb}"
	bash -c "dtc -I dts -O dtb -o ${dtb} ${dts}"
}

while true; do
	case $1 in
	-h|--help)
		usage
		exit 0;;
	-disk )
		for key in "${!QEMU_ROOT_DISK[@]}"; do 
			QEMU_COMMAND_ROOT[${key}]="${QEMU_ROOT_DISK[${key}]}" 
		done
		QEMU_ROOT_IMAGE=${QEMU_ROOT_IMAGE_DISK}
		QEMU_COMMAND_ARCH["kernel"]="" # The disk image contains the kernel and root file system.
		if [[ -n ${2} ]] && ! [[ ${2} =~ ^"-" ]]; then
			QEMU_ROOT_IMAGE=${2}
			shift
		fi;;
	-nfs )
		qemu_run_sudo="sudo"
		for key in "${!QEMU_ROOT_RDINIT[@]}"; do 
			QEMU_COMMAND_ROOT[${key}]="${QEMU_ROOT_NFS[${key}]}"
		done
		QEMU_ROOT_IMAGE=${QEMU_ROOT_IMAGE_NFS}
		if [[ -n ${2} ]] && ! [[ ${2} =~ ^"-" ]]; then
			QEMU_ROOT_IMAGE=$(realpath ${2})
			shift
		fi
		qemu_check_nfs "${QEMU_ROOT_IMAGE}"
		;;
	-rd )
		for key in "${!QEMU_ROOT_RDINIT[@]}"; do 
			QEMU_COMMAND_ROOT[${key}]="${QEMU_ROOT_RDINIT[${key}]}"
		done
		QEMU_ROOT_IMAGE=${QEMU_ROOT_IMAGE_RDINIT}
		if [[ -n ${2} ]] && ! [[ ${2} =~ ^"-" ]]; then
			QEMU_ROOT_IMAGE=${2}
			shift
		fi;;

	-k|--kernel )
		if [[ -n ${2} ]] && ! [[ ${2} =~ ^"-" ]]; then
			QEMU_COMMAND_ARCH["kernel"]="-kernel ${2}"
			shift 
		else
			usage
			exit 1
		fi;;
	-d|--dtb )
		if [[ -n ${2} ]] && ! [[ ${2} =~ ^"-" ]]; then
			QEMU_COMMAND_ARCH["dtb"]="-dtb ${2}"
			shift
		fi;;
	-s|--smp )
		if [[ -n ${2} ]] && ! [[ ${2} =~ ^"-" ]]; then
			QEMU_COMMAND_ARCH["smp"]="-smp ${2}"
			shift
		fi;;
	-m|--mem )
		if [[ -n ${2} ]] && ! [[ ${2} =~ ^"-" ]]; then
			QEMU_COMMAND_ARCH["mem"]="-m ${2}"
			shift
		fi;;
	-g|-graphic )
		QEMU_COMMAND_ARCH["graphic"]=${QEMU_DEVICE_GRAPHIC}
		;;
	-kgdb )
		QEMU_BOOT_COMMAND+="${QEMU_KGDB_WAIT} "
		;;
	-gdb )
		QEMU_OPT_APPEND+="-gdb ${QEMU_GDB_NET_PORT} "
		if [[ -n ${2} ]] && ! [[ ${2} =~ ^"-" ]] && [[ ${2} == 's' ]] ; then
			QEMU_OPT_APPEND+="-S "
			shift
		fi;;
	-n|-net )
		qemu_run_sudo="sudo"
		QEMU_COMMAND_ARCH["net"]=${QEMU_DEVICE_NET}
		if [[ -n ${2} ]] && ! [[ ${2} =~ ^"-" ]]; then
			QEMU_COMMAND_ARCH["net"]=${2}
			shift
		fi;;
	-ip )
		if [[ -n ${2} ]] && ! [[ ${2} =~ ^"-" ]]; then
			QEMU_OPT_NET_IP=${2}
			shift
		fi;;
	-append )
		if [[ -n ${2} ]] && ! [[ ${2} =~ ^"-" ]]; then
			QEMU_OPT_APPEND+="--append ${2} "
			shift
		fi;;
	-boot )
		if [[ -n ${2} ]]; then
			QEMU_BOOT_COMMAND+="${2} "
			shift
		fi;;
	-opt )
		if [[ -n ${2} ]]; then
			QEMU_OPT_OPTION="${2} "
                        shift
		fi;;
	-kill|--kill )
		qemu_stop
		exit 0;;
	-dumpdtb| --dumpdtb)
		QEMU_COMMAND_ARCH["machine"]+=",dumpdtb=${QEMU_DTB_DUMP}"
		if [[ -n ${2} ]] && ! [[ ${2} =~ ^"-" ]]; then
			QEMU_COMMAND_ARCH["machine"]+=",dumpdtb=${2}"
			shift
		fi;;
	-ds|--ds )
		dtb=${QEMU_DTB_DUMP}
		dts=${QEMU_DTS_DUMP}
		if [[ -n ${2} ]] && ! [[ ${2} =~ ^"-" ]]; then
			dtb=$(echo ${2} | cut  -d',' -f 1)
			dts=$(echo ${2} | cut -sd',' -f 2)
			[[ -n ${dtb} ]] && dtb=${dtb}; 
			[[ -n ${dts} ]] && dts=${dts}; 
		fi
		dtb2dts "${dtb}" "${dts}"
		exit 0;;
	-sd|--sd )
		dtb=${QEMU_DTB_DUMP}
		dts=${QEMU_DTS_DUMP}
		if [[ -n ${2} ]] && ! [[ ${2} =~ ^"-" ]]; then
			dts=$(echo ${2} | cut  -d',' -f 1)
			dtb=$(echo ${2} | cut -sd',' -f 2)
			[[ -n ${dtb} ]] && dtb=${dtb}; 
			[[ -n ${dts} ]] && dts=${dts}; 
		fi
		dts2dtb "${dtb}" "${dts}"
		exit 0;;
	-tty )
		QEMU_NEW_TERMINAL=true;;
	-test )
		QEMU_TEST=true;;
	-* )
		usage
		exit 1;;
	*)
       		shift
		break;;
	esac
	shift
done

qemu_env
qemu_parse
qemu_run "$QEMU_RUN"
