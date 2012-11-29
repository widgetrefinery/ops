#!/bin/bash

set -e
set -o pipefail
set -u

function f_fail {
	echo "*** $* ***"
	exit -1
}

function f_run {
	if [ 3 -gt ${#*} ]; then
		echo "Usage: $0 [name] [mem] [arch|win|win-install] [iso]"
		exit -1
	fi
	vm_name=$1
	vm_mem=$2
	vm_disk="-drive file=/dev/mapper/$vm_name,if=virtio,index=0,media=disk,cache=none,format=raw"
	case $3 in
		arch)		vm_rtc= ;;
		win)		vm_rtc="-rtc base=localtime,clock=rt,driftfix=slew -no-shutdown" ;;
		win-install)	vm_rtc="-rtc base=localtime,clock=rt,driftfix=slew"
				vm_tmpdisk=/tmp/tmp.img
				vm_disk="-hda /dev/mapper/$vm_name -drive file=$vm_tmpdisk,if=virtio,media=disk,format=qcow2"
				qemu-img create -f qcow2 $vm_tmpdisk 32M
				;;
		*) 		f_fail "unsupported os: $3" ;;
	esac
	vm_cdrom=
	if [ 4 -le ${#*} ]; then
		vm_cdrom="-cdrom $4 -boot once=d"
	fi

	echo 'checking disk image ...'
	vm_vg=vg0
	[ ! -e /dev/$vm_vg/$vm_name ] && f_fail "invalid image: $vm_name"
	grep -Eq "^/dev/(mapper|$vm_vg)/$vm_name " /proc/mounts && f_fail "image $vm_name in use"

	echo 'scanning for available port ...'
	vm_index=1
	while [ 100 -gt $vm_index ]; do
		if nmap -Pn -p $((5900+vm_index)) localhost | grep -q closed; then
			break;
		fi
		vm_index=$((1+vm_index))
	done
	[ 100 == $vm_index ] && f_fail 'no ports available'
	echo "monitor=$((5800+vm_index)), vnc=$((5900+vm_index))"

	vm_switch=br0
	vm_tap=tap_$vm_name
	vm_mac=$(md5sum <<< $vm_name | sed 's/\(..\)/\1 /g' | awk '{printf "00:16:3e:%s:%s:%s", $1, $2, $3}')
	vm_net="-net nic,macaddr=$vm_mac,model=virtio -net tap,ifname=$vm_tap,script=no,downscript=no"

	echo 'initializing resources ...'
	sudo $0 _init $vm_vg $vm_name $vm_switch $vm_tap

	qemu-kvm \
		-machine type=pc-1.1,accel=kvm,kernel_irqchip=off \
		-cpu host \
		$vm_disk \
		$vm_cdrom \
		-m $vm_mem \
		-mem-path /dev/hugepages \
		-mem-prealloc \
		-k en-us \
		-balloon none \
		-vga vmware \
		-vnc 127.0.0.1:$vm_index,lossy \
		$vm_net \
		-serial none \
		-parallel none \
		-monitor telnet:127.0.0.1:$((5800+vm_index)),server,nowait \
		-pidfile /tmp/kvm-$vm_name.pid \
		-S \
		-D /tmp/kvm-$vm_name.log \
		-enable-kvm \
		-daemonize \
		$vm_rtc

	vm_pid=$(</tmp/kvm-$vm_name.pid)
	echo "Shielding vm ($vm_pid) from oom killer ..."
	sudo bash -c "echo -17 > /proc/$vm_pid/oom_adj"
}

function f_init {
	vm_vg=$2
	vm_name=$3
	vm_switch=$4
	vm_tap=$5
	if [ ! -e /dev/mapper/$vm_name ]; then
		cryptsetup luksOpen /dev/$vm_vg/$vm_name $vm_name
	fi
	if [ ! -e /proc/net/dev_snmp6/$vm_tap ]; then
	        ip tuntap add mode tap user $SUDO_UID $vm_tap
	fi
	ip link set $vm_tap up
	if ! brctl show $vm_switch | grep -q $vm_tap; then
		brctl addif $vm_switch $vm_tap
	fi
}

function f_main {
	if [ 5 == ${#*} -a '_init' == "${1:-}" ]; then
		f_init $*
	else
		f_run $*
	fi
}

f_main $*
