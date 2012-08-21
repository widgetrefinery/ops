#!/bin/sh

. /etc/rc.d/functions

set -e
set -o pipefail
set -u

switch_name=$(awk '$1 == "interface" {print $2}' /etc/radvd.conf)
switch_ip=$(sed -n 's/^\s*option\s*dhcp6.name-servers\s*\([^ \t;]*\).*$/\1/p' /etc/dhcpd.conf)
tunnel_name=$(awk '$1 == "tun-device" {print $2}' /etc/tayga.conf)
tunnel_ipv4=$(awk '$1 == "ipv4-addr" {print $2}' /etc/tayga.conf)
tunnel_ipv6=$switch_ip
tunnel_ipv6_subnet=$(awk '$1 == "prefix" {print $2}' /etc/tayga.conf)

function f_start {
	brctl addbr $switch_name
	ip addr add $switch_ip/64 dev $switch_name

	tayga --mktun >/dev/null
	ip link set $tunnel_name up
	ip addr add $tunnel_ipv4/24 dev $tunnel_name
	ip addr add $tunnel_ipv6 dev $tunnel_name
	ip route add $tunnel_ipv6_subnet dev $tunnel_name
	tayga
}

function f_stop {
	killall tayga || true
	ip link set $tunnel_name down
	tayga --rmtun >/dev/null

	ip link set $switch_name down
	brctl delbr $switch_name
}

case "${1:-}" in
	start)
		stat_busy 'Starting kvm-network'
		if ! f_start; then
			stat_fail
		else
			add_daemon kvm-network
			stat_done
		fi
		;;
	stop)
		stat_busy 'Stopping kvm-network'
		if ! f_stop; then
			stat_fail
		else
			rm_daemon kvm-network
			stat_done
		fi
		;;
	restart)
		$0 stop
		sleep 1
		$0 start
		;;
	*)
		echo "Usage: $0 {start|stop|restart}" ;;
esac

