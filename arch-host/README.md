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

1. Install base system, skipping the following modules, using: `pacstrap -i /mnt base`

	* ^19 - heirloop-mailx
	* ^23 - jfsutils
	* ^32 - nano
	* ^35 - pcmciautils
	* ^37 - ppp
	* ^40 - reiserfsprogs
	* ^53 - wpa_supplicant
	* ^54 - xfsprogs

2. Install grub using: `pacstrap /mnt grub-bios`

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

# Additional Software

Run `pacman -Syy` first to update the database before installing.

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

	1. Install `etc/iptables.rules` to `/etc/iptables/iptables.rules`
	2. Install `etc/ip6tables.rules` to `/etc/iptables/ip6tables.rules`
	3. Add `iptables` and `ip6tables` to `DAEMONS` list in `/etc/rc.conf`

* mlocate

		updatedb

* nmap

* ntp

	1. Add `ntpd` to `DAEMONS` list in `/etc/rc.conf`

* openssh

	1. Add `sshd` to `DAEMONS` list in `/etc/rc.conf`

* parted

* pkgfile

		pkgfile --update

* screen

	1. Uncomment `startup_message off` in `/etc/screenrc`

* squashfs-tools

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

# OS Configuration

* agetty

	1. Replace `/etc/issue`: `echo -e '[\l]\n' > /etc/issue`
	2. Reduce the number of terminals in `/etc/inittab` to 3.

* bash

	1. Install `etc/bash.bashrc` to `/etc/bash.bashrc`
	2. Install `home/bashrc` to `/etc/skel/.bashrc`

* disable ipv6

	1. Add `net.ipv6.conf.eth0.disable_ipv6 = 1` to `/etc/sysctl.conf`
	2. Add `noipv6rs` to `/etc/dhcpcd.conf`

* login.defs

	1. Add `CREATE_HOME yes` to `/etc/login.defs`

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

Configuration:

1. Edit `/etc/rc.conf`:

	1. Add `dbus` to `DAEMONS` list

2. Edit `/etc/inittab`:

	1. Comment out `id:3:initdefault:`
	2. Uncomment `id:5:initdefault:`
	3. Comment out `x:5:respawn:/usr/bin/xdm -nodaemon`
	4. Uncomment `x:5:respawn:/usr/bin/slim >/dev/null 2>&1`
	5. Add `xt:5:wait:/usr/bin/chvt 7`

## Window Manager

* i3-wm
* i3lock
* i3status

Configuration:

1. Install `home/i3.conf` to `/etc/skel/.i3/i3.conf`
2. Install `home/i3.conf` to `/etc/skel/.i3/i3-nx.conf`
3. Modify `/etc/skel/.i3/i3-nx.conf`, changing the `$mod` variable from `Mod4` to `Mod1`
3. Install `home/i3status.conf` to `/etc/skel/.i3/i3status.conf`
4. Install `home/xinitrc` to `/etc/skel/.xinitrc`
5. Install `home/Xdefaults` to `/etc/skel/.Xdefaults`

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

* freenx
* xdialog

Configuration:

1. Edit `/etc/nxserver/node.conf`:

	1. Add `USER_X_STARTUP_SCRIPT=.xinitrc`
	2. Add `AGENT_EXTRA_OPTIONS_X="-norender"`

2. Ensure `~/.xinitrc` is executable.

## NX Client

1. Install client from [nomachine](http://www.nomachine.com)
2. Copy the key from `/var/lib/nxserver/home/nx/.ssh/client.id_dsa.key` to the client machine.
3. Start the nx client and import the key
4. Choose custom desktop, run default X client script on server, and new virtual desktop

Once the client is connected, you can exit using CTRL+ALT+T.

# KVM

* qemu-kvm
* tigervnc

Configuration:

1. Add `kvm` and `kvm-intel` to `MODULES` list in `/etc/rc.conf`

2. Install `kvm-wrapper.sh` to `/usr/local/bin`

3. Add yourself to the `disk`, `kvm`, and `wheel` groups

4. Modify `/etc/rc.sysinit` to create `/dev/hugepages` directory:

		sed -i 's!\(mkdir -p /dev/{\)!\1hugepages,!' /etc/rc.sysinit

7. Add `hugepages` to `/etc/fstab`:

		hugetlbfs	/dev/hugepages	hugetlbfs	mode=1770,gid=kvm	0 0

8. Note `Hugepagesize` in `/proc/meminfo`. Take the amount of memory to allocate for vms and divide by this number. Add some buffer and cat it to `/proc/sys/vm/nr_hugepages` like so:

		echo 140 > /proc/sys/vm/nr_hugepages

9. If all goes well add it to /etc/sysctl.conf:

		vm.nr_hugepages = 140

## Guest Networking

* Enable packet forwarding:

	1. Change `net.ipv4.ip_forward = 0` to `net.ipv4.ip_forward = 1` in `/etc/sysctl.conf`
	2. Change `net.ipv6.conf.all.forwarding = 0` to `net.ipv6.conf.all.forwarding = 1` in `/etc/sysctl.conf`
	3. Reload kernel parameters: `sysctl -p`

* Allow qemu to use bridge br0:

		echo 'allow br0' > /etc/qemu/bridge.conf

* Install and configure bind:

	1. Install `guest-networking/named.conf` to `/etc/named.conf`
	2. Install `guest-networking/named.zone` to `/var/named/named.zone`
	3. Install `guest-networking/named.reverse` to `/var/named/named.reverse`
	4. Add `named` to `DAEMONS` list in `/etc/rc.conf`
	5. `chmod 770 /var/named`
	6. Create `/etc/resolve.conf.head`:

			search <domainname>
			nameserver ::1

* Install and configure dhcp:

	1. Install `guest-networking/dhcpd.conf` to `/etc/dhcpd.conf`
	2. Add `dhcp6` to `DAEMONS` list in `/etc/rc.conf`

* Install and configure kvm-network:

	1. Install bridge-utils
	1. Install `guest-networking/kvm-network.sh` to `/etc/rc.d/kvm-network`
	2. Add `kvm-network` to `DAEMONS` list in `/etc/rc.conf`

* Install and configure radvd:

	1. Install `guest-networking/radvd.conf` to `/etc/radvd.conf`
	2. Add `radvd` to `DAEMONS` list in `/etc/rc.conf`

* Install and configure tayga:

	1. Compile and install tayga 0.9.2-1 from aur:

			wget http://aur.archlinux.org/packages/ta/tayga/tayga.tar.gz
			tar -xf tayga.tar.gz
			cd tayga
			makepkg
			sudo pacman -U tayga-0.9.2-1-i686.pkg.tar.xz

	2. Install `guest-networking/tayga.conf` to `/etc/tayga.conf`

* Install and configure totd:

	1. Compile and install totd 1.5.1-4 from aur:

			wget http://aur.archlinux.org/packages/to/totd/totd.tar.gz
			tar -xf totd.tar.gz
			cd totd
			makepkg
			sudo pacman -U totd-1.5.1-4-i686.pkg.tar.xz

	2. Install `guest-networking/totd.conf` to `/etc/totd.conf`

	3. Set `forwarder` in `/etc/totd.conf` to desired dns server

	4. Add `totd` to `DAEMONS` list in `/etc/rc.conf`

## Network Shares

* nfs-utils

Server Configuration:

1. Set the domain in `/etc/idmapd.conf`
2. Define shares in `/etc/exports`
3. Add `rpcbind`, `nfs-common`, and `nfs-server` to the `DAEMONS` list in `/etc/rc.conf`

Client Configuration:

1. Set the domain in `/etc/idmapd.conf`
2. Set `NEED_IDMAPD="yes"` in `/etc/conf.d/nfs-common.conf`
3. Add `rpcbind` and `nfs-common` to the `DAEMONS` list in `/etc/rc.conf`

