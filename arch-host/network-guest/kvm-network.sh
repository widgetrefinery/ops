#!/bin/sh

set -e
set -o pipefail
set -u

switch_name=br0
switch_ip=$(sed -n 's/^\s*option\s*dhcp6.name-servers\s*\([^ \t;]*\).*$/\1/p' /etc/dhcpd.conf)
tunnel_name=$(awk '$1 == "tun-device" {print $2}' /etc/tayga.conf)
tunnel_ipv4=$(awk '$1 == "ipv4-addr" {print $2}' /etc/tayga.conf)
tunnel_ipv6=$switch_ip
tunnel_ipv4_subnet=$(awk '$1 == "dynamic-pool" {print $2}' /etc/tayga.conf)
tunnel_ipv6_subnet=$(awk '$1 == "prefix" {print $2}' /etc/tayga.conf)

function f_status {
	[ -e /proc/net/dev_snmp6/$1 ]
}

function f_start {
	if ! f_status $switch_name; then
		brctl addbr $switch_name
		ip addr add $switch_ip/64 dev $switch_name
	fi

	if ! f_status $tunnel_name; then
		tayga --mktun >/dev/null
		ip link set $tunnel_name up
		ip addr add $tunnel_ipv4/24 dev $tunnel_name
		ip addr add $tunnel_ipv6 dev $tunnel_name
		ip route add $tunnel_ipv6_subnet dev $tunnel_name
		tayga
	fi
}

function f_stop {
	if f_status $tunnel_name; then
		killall tayga || true
		ip link set $tunnel_name down
		tayga --rmtun >/dev/null
	fi
	if f_status $switch_name; then
		ip link set $switch_name down
		brctl delbr $switch_name
	fi
}

function f_usage {
	echo "Usage: $0 [start|stop]"
}

if [ ! -z "$*" ]; then
	case $1 in
	start) 	f_start ;;
	stop)	f_stop ;;
	*)	f_usage ;;
	esac
else
	f_usage
fi

