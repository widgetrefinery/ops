# Allocate lvm

* /

	dd if=/dev/zero of=/dev/sda
	mdadm --create --metadata=1.1 --homehost=$HOSTNAME --raid-devices=2 --level=1 /dev/md0 /dev/sda missing
	pvcreate /dev/md0
	vgcreate vg0 /dev/md0
	lvcreate -L8G -n $HOSTNAME vg0
	cryptsetup luksFormat --use-random /dev/vg0/$HOSTNAME
	cryptsetup luksOpen /dev/vg0/$HOSTNAME $HOSTNAME
	dd if=/dev/zero of=/dev/mapper/$HOSTNAME
	mke2fs -t ext4 /dev/mapper/$HOSTNAME
	mount /dev/mapper/$HOSTNAME /mnt

* /boot

	parted /dev/sdc
		mklabel gpt
		mkpart primary 2048s 20479s	#512B sectors; ~10MB partition
		mkpart primary 20480s -1s	#rest of drive
		set 1 bios_grub on
	mke2fs -t ext2 /dev/sdc2
	mkdir /mnt/boot
	mount /dev/sdc2 /mnt/boot

# Install OS

1. Install base system, skipping the following modules, using: pacstrap -i /mnt base

	* ^19 - heirloop-mailx
	* ^23 - jfsutils
	* ^32 - nano
	* ^35 - pcmciautils
	* ^37 - ppp
	* ^40 - reiserfsprogs
	* ^53 - wpa_supplicant
	* ^54 - xfsprogs

2. Install grub using: pacstrap /mnt grub-bios

3. Configure os:

	genfstab -p /mnt >> /mnt/etc/fstab
	arch-chroot /mnt
	echo $HOSTNAME > /etc/hostname
	ln -fns /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
	echo 'LANG="en_US.UTF-8"' > /etc/locale.conf
	vi /etc/locale.get #enable relevant locales
	locale-gen
	mdadm --detail --scan >> /mnt/etc/mdadm.conf
	vi /etc/mkinitcpio.conf
		# add video driver (i915) to MODULES list
		# i.e. MODULES="i915"
		# add mdadm_udev, lvm2, encrypt to HOOKS list
		# i.e. HOOKS="base udev autodetect pata scsi sata mdadm_udev lvm2 usbinput encrypt filesystems fsck"
	mkinitcpio -p linux
	passwd #set root password

4. Configure grub:

	grub-mkconfig -o /boot/grub/grub.cfg
	grub-install /dev/sdc
	rm -f /boot/grub/grub.cfg.example
	vi /boot/grub/grub.cfg
		# change "set root='hd2,gpt2'" to "set root='hda0,gpt2'"
		# add "cryptdevice=/dev/mapper/vg0-$HOSTNAME:$HOSTNAME" to linux command
		# remove search statements

5. Cleanup:

	exit #out of chroot
	umount /mnt/boot /mnt
	reboot

## Resources

* [Installation Guide](https://wiki.archlinux.org/index.php/Arch_Install_Scripts)
* [GRUB2 - ArchWiki](https://wiki.archlinux.org/index.php/Grub2)
* [RAID system encryption with LUKS & LVM](https://bbs.archlinux.org/viewtopic.php?id=120265)
* [[Solved] Pure UEFI GRUB2 LVM2 on LUKS encrypted GPT 3xSSD RAID0](https://bbs.archlinux.org/viewtopic.php?id=126502)
* [Kernel Mode Setting](https://wiki.archlinux.org/index.php/KMS#Disabling_modesetting)

# OS Configuration

* agetty

	1. Replace /etc/issue:

		echo -e '[\l]\n' > /etc/issue

	2. Reduce the number of terminals in /etc/inittab to 3.

* bash

	1. Replace /etc/bash.bashrc with custom bash.bashrc
	2. Remove PS1 from /etc/skel/.bashrc
	3. Add "alias vi=vim" to /etc/skel/.bashrc
	4. Add "cat /etc/motd" to /etc/skel/.bashrc

* disable ipv6

	echo 'net.ipv6.conf.eth0.disable_ipv6 = 1' >> /etc/sysctl.conf
	echo noipv6rs >> /etc/dhcpcd.conf

* login.defs

	1. Add 'CREATE_HOME yes' to /etc/login.defs
	2. Add 'MOTD_FILE' to /etc/login.defs

# Core Software

Run "pacman -Syy" first to update database before installing.

* base-devel
* dnsutils
* fortune-mod

	cat > /etc/cron.hourly/fortune-motd << 'EOF'
	#!/bin/sh
	/usr/bin/fortune computers cookie definitions linux magic startrek | sed -e '1i\\' -e '$a\\' > /etc/motd
	EOF
	chmod 755 /etc/cron.hourly/fortune-motd
	/etc/cron.hourly/fortune-motd
	sed -i '/pam_motd\.so/d' /etc/pam.d/system-login

* iptables

	1. Install etc/iptables.rules to /etc/iptables/iptables.rules.
	2. Add iptables to DAEMONS list in /etc/rc.conf

* mlocate

	updatedb

* nmap
* ntp

	1. Add ntpd to DAEMONS list in /etc/rc.conf

* openssh

	1. Add sshd to DAEMONS list in /etc/rc.conf

* parted
* pkgfile

	pkgfile --update

* screen

	1. Uncomment "startup_message off" in /etc/screenrc

* sudo

	cat >> /etc/sudoers << 'EOF'
	Defaults timestamp_timeout=0
	%wheel ALL=(ALL) ALL
	EOF

* traceroute
* vim

	cp /usr/share/vim/vim73/vimrc_example.vim /etc/skel/.vimrc
	echo 'set viminfo=""' >> /etc/skel/.vimrc
	sed -i 's/\(set backup\)/"\1/' /etc/ske/.vimrc
	mkdir /etc/skel/.vim
	cat > /etc/skel/.vim/.netrwhist << 'EOF'
	let g:netrw_dirhistmax  =0
	let g:netrw_dirhist_cnt =0
	EOF

# Guest Networking

* Enable packet forwarding:

	1. Change "net.ipv4.ip_forward = 0" to "net.ipv4.ip_forward = 1" in /etc/sysctl.conf
	2. Change "net.ipv6.conf.all.forwarding = 0" to "net.ipv6.conf.all.forwarding = 1" in /etc/sysctl.conf
	3. Reload kernel parameters: sysctl -p

* Allow qemu to use bridge br0:

	echo 'allow br0' > /etc/qemu/bridge.conf

* Install and configure bind:

	1. Install network-guest/named.conf to /etc/named.conf
	2. Install network-guest/named.zone to /var/named/named.zone
	3. Install network-guest/named.reverse to /var/named/named.reverse
	4. Add named to DAEMONS list in /etc/rc.conf
	5. chmod 770 /var/named

* Install and configure dhcp:

	1. Install network-guest/dhcpd.conf to /etc/dhcpd.conf
	2. Add dhcp6 to DAEMONS list in /etc/rc.conf

* Install and configure kvm-network:

	1. Install bridge-utils
	1. Install network-guest/kvm-network.sh to /etc/rc.d/kvm-network
	2. Add kvm-network to DAEMONS list in /etc/rc.conf

* Install and configure radvd:

	1. Install network-guest/radvd.conf to /etc/radvd.conf
	2. Add radvd to DAEMONS list in /etc/rc.conf

* Install and configure tayga:

	1. Compile and install tayga 0.9.2-1 from aur:

		wget http://aur.archlinux.org/packages/ta/tayga/tayga.tar.gz
		tar -xf tayga.tar.gz
		cd tayga
		makepkg
		sudo pacman -U tayga-0.9.2-1-i686.pkg.tar.xz

	2. Install network-guest/tayga.conf to /etc/tayga.conf

* Install and configure totd:

	1. Compile and install totd 1.5.1-4 from aur:

		wget http://aur.archlinux.org/packages/to/totd/totd.tar.gz
		tar -xf totd.tar.gz
		cd totd
		makepkg
		sudo pacman -U totd-1.5.1-4-i686.pkg.tar.xz

	2. Install network-guest/totd.conf to /etc/totd.conf
	3. Set forwarder in /etc/totd.conf to desired dns server
	4. Add totd to DAEMONS list in /etc/rc.conf

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

## NX Server

1. Install freenx
2. Install xdialog
3. Edit /etc/nxserver/node.conf and add AGENT_EXTRA_OPTIONS_X="-norender"

## NX Client

1. Install client from [nomachine](http://www.nomachine.com)
2. Copy the client key from /var/lib/nxserver/home/nx/.ssh/client.id_dsa.key to your desktop.
3. Start the nx client and import the key
4. Choose custom desktop, use "/usr/bin/i3" as the application, choose a new virtual desktop
5. Exit using ctrl+alt+t

# KVM

* qemu-kvm
* tigervnc
* uml_utilities

1. Add kvm and kvm-intel to MODULES list in /etc/rc.conf
4. Install win_vm.sh to a convenient location
5. Add yourself to the disk, kvm, wheel groups
6. Modify /etc/rc.sysinit to create /dev/hugepages:
	sed -i 's!\(mkdir -p /dev/{\)!\1hugepages,!' /etc/rc.sysinit
7. Add hugepages to /etc/fstab:
	hugetlbfs	/dev/hugepages	hugetlbfs	mode=1770,gid=kvm	0 0
8. Note HugePagesize in /proc/meminfo. Take the amount of memory to allocate for vms and divide by this number. Cat it to /proc/sys/vm/nr_hugepages like so:
	echo 140 > /proc/sys/vm/nr_hugepages
9. If all goes well add it to /etc/sysctl.conf:
	vm.nr_hugepages = 140

