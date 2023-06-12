#!/bin/bash
#
# https://wiki.archlinux.org/title/network_bridge
#
# Requirements
# iproute2
#  $ apt-get install dhcp-client iproute2
# bridge-utils
#  $ apt-get install dhcp-client iproute2 bridge-utils
# network-manager
#  $ apt-get install network-manager

function logerr () { echo -e "\033[0;31m$*\033[0m"; }
function logmsg () { echo -e "\033[0;33m$*\033[0m"; }
function logext () { echo -e "\033[0;31m$*\033[0m"; exit -1; }

NET_HOST_IF_NAME="$(basename -a $(ls /sys/class/net/en* -d))"  # network device name (get from system)
NET_BR_NAME="br0"	# bridge name (user defined)
NET_BR_SLAVE_NAME="bridge-br0"

function set_interface_ipaddr () {
	local net="${1}" addr="${2}"
	if [[ -z ${addr} ]]; then
		${su} bash -c "dhclient -v ${net}"
	else
		${su} bash -c "ip addr add ${addr} dev ${net}"
	fi
}

function bridge_iproute2 () {	
	su="sudo"
	if [[ ! $(which ip) ]]; then
		logext " Require iproute2: $ sudo apt install dhcp-client iproute2"
	fi

	[[ $(whoami) == "root" ]] && su="";

	if [[ ${__br_remove} == true ]]; then
		logmsg "- Remove bridge named ${NET_BR_NAME} and restor ${NET_HOST_IF_NAME}"
		${su} bash -c "ip link del ${NET_BR_NAME} type bridge"
		set_interface_ipaddr "${NET_HOST_IF_NAME}" "${__br_ipaddr}"
		return;
	fi

	logmsg "- Add a net bridge named ${NET_BR_NAME}"
	${su} bash -c "ip link add ${NET_BR_NAME} type bridge"
	${su} bash -c "ip link set ${NET_BR_NAME} up"

	logmsg "- Add physical interface(${NET_HOST_IF_NAME}) to the bridge(${NET_BR_NAME})"
	${su} bash -c "ip link set ${NET_HOST_IF_NAME} master ${NET_BR_NAME}"

	set_interface_ipaddr "${NET_BR_NAME}" "${__br_ipaddr}"
}

function bridge_bridge_utils () {	
	su="sudo"
	if [[ ! $(which brctl) ]]; then
		logext " Require bridge-utils: $ sudo apt install dhcp-client iproute2 bridge-utils"
	fi

	[[ $(whoami) == "root" ]] && su="";

	if [[ ${__br_remove} == true ]]; then
		logmsg "- Remove bridge named ${NET_BR_NAME} and restor ${NET_HOST_IF_NAME}"
		${su} bash -c "ip link set dev ${NET_BR_NAME} down"
		${su} bash -c "brctl delbr ${NET_BR_NAME}"

		set_interface_ipaddr "${NET_HOST_IF_NAME}" "${__br_ipaddr}"
		return;
	fi

	logmsg "- Add a net bridge named ${NET_BR_NAME}"
	${su} bash -c "brctl addbr ${NET_BR_NAME}"

	logmsg "- Add physical interface(${NET_HOST_IF_NAME}) to the bridge(${NET_BR_NAME})"
	${su} bash -c "brctl addif ${NET_BR_NAME} ${NET_HOST_IF_NAME}"
	${su} bash -c "ip link set ${NET_BR_NAME} up"

	set_interface_ipaddr "${NET_BR_NAME}" "${__br_ipaddr}"
}

function bridge_network_manager () {
	su="sudo"
	if [[ ! $(which nmcli) ]]; then
		logext " Require Network-Manage: $ sudo apt install dhcp-client network-manager"
	fi

	[[ $(whoami) == "root" ]] && su="";

	if [[ ${__br_remove} == true ]]; then
		logmsg "- Remove bridge named ${NET_BR_NAME} and restor ${NET_HOST_IF_NAME}"
		${su} bash -c "nmcli conn delete ${NET_BR_NAME}"
		${su} bash -c "nmcli conn delete ${NET_BR_SLAVE_NAME}"

		set_interface_ipaddr "${NET_HOST_IF_NAME}" "${__br_ipaddr}"
		return;
	fi

	logmsg "- Add a net bridge named ${NET_BR_NAME}"
	${su} bash -c "nmcli conn add ifname ${NET_BR_NAME} type bridge con-name ${NET_BR_NAME} stp no"

	logmsg "- Add physical interface(${NET_HOST_IF_NAME}) to the bridge(${NET_BR_NAME}/${NET_BR_SLAVE_NAME})"
	${su} bash -c "nmcli conn add type ethernet slave-type bridge con-name ${NET_BR_SLAVE_NAME} ifname ${NET_HOST_IF_NAME} master ${NET_BR_NAME}"
	${su} bash -c "nmcli conn down ${NET_HOST_IF_NAME}"
	${su} bash -c "nmcli conn up ${NET_BR_SLAVE_NAME}"

	set_interface_ipaddr "${NET_BR_NAME}" "${__br_ipaddr}"
}

declare -A __brdige_functions=(
	["iproute"]=bridge_iproute2
	["brctl"]=bridge_bridge_utils
	["nmcli"]=bridge_network_manager
)

function fn_usage () {
	echo " Usage:"
	echo -e "\t$(basename "${0}") [options]"
	echo ""
	echo " options:"
	echo -e  "\t-i [interface]\t set network interface name: default '${NET_HOST_IF_NAME}'"
	echo -e  "\t-b [bridge]\t set bridge interface name: default '${NET_BR_NAME}'"
	echo -ne "\t-t [tool]\t select tool: ${!__brdige_functions[@]} (default iproute)"
	echo -e ""
	echo -e  "\t-s [ipaddr]\t set static ip addr: n.n.n.n"
	echo -e  "\t-r\t\t remove bridge (${NET_BR_NAME}"
	echo ""
	exit 1;
}

__br_function=bridge_iproute2
__br_remove=false

function fn_args () {
	while getopts "i:b:t:rvh" opt; do
	case ${opt} in
		i )	NET_HOST_IF_NAME=${OPTARG};;
		b )	NET_BR_NAME=${OPTARG};;
		t )	for i in "${!__brdige_functions[@]}"; do
				if [[ ${OPTARG} == ${i} ]]; then
					__br_function=${__brdige_functions[${i}]}
					break
				fi
			done;;
		r )	__br_remove=true;;
		s )	__br_ipaddr="${OPTARG}";;
		h )	fn_usage;;
		*)	exit 1;;
	esac
	done
}

# parse arguments
fn_args "${@}"

[[ -z ${__br_function} ]] && usage;

if ! basename -a $(ls /sys/class/net/* -d) | grep -w ${NET_HOST_IF_NAME} > /dev/null; then
	logext "Not found network interface '${NET_HOST_IF_NAME}'"
fi

# Create network bridge
${__br_function}
