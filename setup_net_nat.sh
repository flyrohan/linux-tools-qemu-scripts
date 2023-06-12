#!/bin/bash
#
# https://wiki.archlinux.org/title/network_bridge
#
# Requirements
# iproute2
#  $ apt-get install iproute2

function logerr () { echo -e "\033[0;31m$*\033[0m"; }
function logmsg () { echo -e "\033[0;33m$*\033[0m"; }
function logext () { echo -e "\033[0;31m$*\033[0m"; exit -1; }

NET_NAT_IF="tap0"
NET_NAT_IP_GW="192.168.100.1"
NET_NAT_IP_MASK="24"

function nat_iproute2 () {	
	su="sudo"
	if [[ ! $(which ip) ]]; then
		logext " Require iproute2: $ sudo apt install iproute2"
	fi

	[[ $(whoami) == "root" ]] && su="";

	if [[ ${__nat_remove} == true ]]; then
		logmsg "- Remove nat named ${NET_NAT_IF}"
		${su} bash -c "ip link del ${NET_NAT_IF}"
		return;
	fi

	if ! ip route list | grep -qw "${NET_NAT_IF}"; then
		logmsg "- Add a net NAT named ${NET_NAT_IF}"
		${su} bash -c "ip tuntap add ${NET_NAT_IF} mode tap"
		${su} bash -c "ip addr add ${NET_NAT_IP_GW}/${NET_NAT_IP_MASK} dev ${NET_NAT_IF}"
		${su} bash -c "ip link set ${NET_NAT_IF} up"
	fi

	ipaddr=$(ip route list | grep "${NET_NAT_IF}" | cut -d ' ' -f1)
	logmsg "- net NAT ${NET_NAT_IF}: ${ipaddr}"
}

function fn_usage () {
	echo " Usage:"
	echo -e "\t$(basename "${0}") [options]"
	echo ""
	echo " options:"
	echo -e  "\t-r\t\t remove NAT (${NET_NAT_IF}"
	echo ""
	exit 1;
}

__nat_function=nat_iproute2
__nat_remove=false

function fn_args () {
	while getopts "rh" opt; do
	case ${opt} in
		r )	__nat_remove=true;;
		h )	fn_usage;;
		*)	exit 1;;
	esac
	done
}

# parse arguments
fn_args "${@}"

[[ -z ${__nat_function} ]] && usage;
# Create network bridge
${__nat_function}
