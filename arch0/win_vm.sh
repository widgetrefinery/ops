#!/bin/bash

set -e
set -o pipefail
set -u

if [ ! -z "$*" -a 2 -le ${#*} ]; then
	vm_name=$1
	vm_index=$2
	vm_disk="-drive file=/dev/mapper/${vm_name}-root,if=virtio,index=0,media=disk,cache=none,format=raw"
	vm_tap=tap_$vm_name
	vm_net="-net nic,model=virtio -net tap,ifname=$vm_tap"

	if [ 4 == ${#*} -a 'os' == $3 ]; then
		vm_disk="-hda /dev/mapper/${vm_name}-root -cdrom $4 -boot once=d"
		vm_net=
	elif [ 4 == ${#*} -a 'virtio' == $3 ]; then
		vm_tmpdisk=/tmp/tmp.img
		vm_disk="-hda /dev/mapper/${vm_name}-root -drive file=$vm_tmpdisk,if=virtio,media=disk,format=qcow2 -cdrom $4"
		if [ -e $vm_tmpdisk ]; then
			echo "$vm_tmpdisk already exists"
			exit -1
		fi
		qemu-img create -f qcow2 $vm_tmpdisk 32M
	fi

	if [ ! -e /dev/mapper/${vm_name}-root ]; then
		echo 'Unlocking disk'
		sudo cryptsetup luksOpen /dev/vg0/${vm_name}_root ${vm_name}-root
	fi

	if [ ! -e /proc/net/dev_snmp6/$vm_tap ]; then
		echo 'Creating tap'
	        sudo tunctl -u $USER -t $vm_tap
	fi

	qemu-kvm \
		-cpu host \
		$vm_disk \
		-m 512M \
		-k en-us \
		-vga vmware \
		-vnc localhost:$vm_index,lossy \
		$vm_net \
		-serial none \
		-parallel none \
		-monitor telnet:localhost:$((5800+vm_index)),server,nowait \
		-S \
		-daemonize \
		-rtc base=localtime

	if [ ! -z ${vm_tmpdisk:+ok} ]; then
		rm -f $vm_tmpdisk
	fi
else
	echo "Usage: $0 [name] [index] [os|virtio] [iso]"
	exit -1
fi

