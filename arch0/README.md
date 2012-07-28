# Installation

## /

	dd if=/dev/zero of=/dev/sda
	mdadm --create --metadata=1.1 --homehost=${HOSTNAME} --raid-devices=2 --level=1 /dev/md0 /dev/sda missing
	pvcreate /dev/md0
	vgcreate vg0 /dev/md0
	lvcreate -L8G -n ${HOSTNAME}_root vg0
	cryptsetup luksFormat --use-random /dev/vg0/${HOSTNAME}_root
	cryptsetup luksOpen /dev/vg0/${HOSTNAME}_root ${HOSTNAME}-root
	dd if=/dev/zero of=/dev/mapper/${HOSTNAME}-root
	mke2fs -t ext4 /dev/mapper/${HOSTNAME}-root
	mount /dev/mapper/${HOSTNAME}-root /mnt

## /boot

	parted /dev/sdc mklabel gpt
	parted /dev/sdc mkpart primary 2048s 20479s	#512B sectors; ~10MB partition
	parted /dev/sdc mkpart primary 20480s -1s	#rest of drive
	parted /dev/sdc set 1 bios_grub on
	mke2fs -t ext2 /dev/sdc2
	mkdir /mnt/boot
	mount /dev/sdc2 /mnt/boot

## pacstrap base

Modify pacstrap so we can customize the modules to install:

	sed -i 's/ --noconfirm / /' /usr/bin/pacstrap

Skip installing the following modules:

* ^19 - heirloop-mailx
* ^23 - jfsutils
* ^35 - pcmciautils
* ^37 - ppp
* ^40 - reiserfsprogs
* ^53 - wpa_supplicant
* ^54 - xfsprogs

## mdadm.conf

	mdadm --detail --scan >> /mnt/etc/mdadm.conf

## mkinitcpio.conf

Add video driver to MODULES:

	MODULES="i915"

Add mdadm_udev, lvm2, encrypt to HOOKS:

	HOOKS="base udev autodetect pata scsi sata mdadm_udev lvm2 usbinput encrypt filesystems fsck"

## grub2

	grub-mkconfig -o /boot/grub/grub.cfg
	grub-install /dev/sdc
	rm -f /boot/grub/grub.cfg.example
	sed -i "s/set root=.*$/set root='hd0,gpt2'/" /boot/grub/grub.cfg
	sed -i '/vmlinuz-linux/ s!$! cryptdevice=/dev/mapper/vg0-${HOSTNAME}_root:${HOSTNAME}-root!' /boot/grub/grub.cfg

Can also delete the search statements from grub.cfg.

## Resources

* [Installation Guide](https://wiki.archlinux.org/index.php/Arch_Install_Scripts)
* [GRUB2 - ArchWiki](https://wiki.archlinux.org/index.php/Grub2)
* [RAID system encryption with LUKS & LVM](https://bbs.archlinux.org/viewtopic.php?id=120265)
* [[Solved] Pure UEFI GRUB2 LVM2 on LUKS encrypted GPT 3xSSD RAID0](https://bbs.archlinux.org/viewtopic.php?id=126502)
* [Kernel Mode Setting](https://wiki.archlinux.org/index.php/KMS#Disabling_modesetting)

# Core Apps

## dnsutils

## fortune-mod

1. Install etc/fortune-motd to /etc/cron.hourly/fortune-motd
2. Remove pam_motd.so from /etc/pam.d/system-login

## iptables

1. Install etc/iptables.rules to /etc/iptables/iptables.rules.
2. Add iptables to DAEMONS list in /etc/rc.conf

## mlocate

1. Run updatedb

## nmap

## ntp

1. Add ntpd to DAEMONS list in /etc/rc.conf

## openssh

1. Add sshd to DAEMONS list in /etc/rc.conf

## pkgfile

## screen

1. Uncomment "startup_message off" in /etc/screenrc

## sudo

1. Add the following to /etc/sudoers:

	Defaults timestamp_timeout=0
	%wheel ALL=(ALL) ALL

## vim

1. Create /etc/skel/.vimrc:

	cp /usr/share/vim/vim73/vimrc_example.vim /etc/skel/.vimrc
	echo 'set viminfo=""' >> /etc/skel/.vimrc
	sed -i 's/\(set backup\)/"\1/' /etc/ske/.vimrc

# OS Tweaks

## agetty

1. Replace /etc/issue:

	echo -e '[\l]\n' > /etc/issue

2. Reduce the number of terminals in /etc/inittab to 3.

## bash

1. Replace /etc/bash.bashrc with custom bash.bashrc
2. Remove PS1 from /etc/skel/.bashrc
3. Add "alias vi=vim" to /etc/skel/.bashrc

## login.defs

1. Add 'CREATE_HOME yes' to /etc/login.defs

# GUI

## X

* xorg-server
* xorg-server-utils
* xf86-video-intel
* xf86-video-vesa
* xf86-video-fbdev

## Display Manager

* xorg-xauth
* slim

1. Edit /etc/rc.conf:

	1. add dbus to DAEMONS

2. Edit /etc/inittab:

	1. comment out "id:3:initdefault:"
	2. uncomment "id:5:initdefault:"
	3. comment out "x:5:respawn:/usr/bin/xdm -nodaemon"
	4. uncomment "x:5:respawn:/usr/bin/slim >/dev/null 2>&1"
	5. add "xt:5:wait:/usr/bin/chvt 7"

## Window Manager

* i3-wm
* i3lock
* i3status

1. Install skel/i3.conf to /etc/skel/.i3/config
2. Install skel/i3status.conf to /etc/skel/.i3/i3status.conf
3. Install skel/xinitrc to /etc/skel/.xinitrc
4. Install skel/Xdefaults to /etc/skel/.Xdefaults

## Desktop Apps

* alsa-utils
* autocutsel
* dmenu
* feh
* firefox
* sylpheed
* xautolock
* xterm

# KVM

* bridge-utils
* gtk-vnc
* qemu-kvm
* uml_utilities

1. Add kvm and kvm-intel to MODULES list in /etc/rc.conf
2. Install etc/qemu-ifup to /etc/qemu-ifup
3. Install etc/bridge.conf to /etc/qemu/bridge.conf
4. Install win_vm.sh to home dir

## Windows VM

1. Create a partition for the primary hdd:

	lvcreate -L16G -n ${VM_HOSTNAME}_root vg0
	cryptsetup luksFormat --use-random /dev/vg0/${VM_HOSTNAME}_root
	cryptsetup luksOpen /dev/vg0/${VM_HOSTNAME}_root ${VM_HOSTNAME}-root
	dd if=/dev/zero of=/dev/mapper/${VM_HOSTNAME}-root

2. Boot up the vm and install the os:

	./win_vm.sh ${VM_HOSTNAME} 1 os /path/to/win.iso
	gvncviewer localhost:1 &
	telnet localhost 5801 #enter c to start the vm

3. Install virtio drivers:

	1. Download virtio driver iso from: [virtio drivers](http://www.linux-kvm.org/page/WindowsGuestDrivers/Download_Drivers)
	2. Boot the vm and install th virtio drivers

## Switching cdrom iso

	ctrl+alt+2 (to switch to monitor console if using sdl)
	info block (to display current block devices)
	change ide1-cd0 /path/to/iso (mount iso)

