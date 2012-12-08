# Allocate lvm

* /

		dd if=/dev/zero of=/dev/sda bs=4M
		mdadm --create --metadata=1.1 --homehost=$HOSTNAME --raid-devices=2 --size=152064M --level=1 /dev/md0 /dev/sda missing
		pvcreate /dev/md0
		vgcreate vg0 /dev/md0
		lvcreate -L32G -n $HOSTNAME vg0
		cryptsetup luksFormat --use-random /dev/vg0/$HOSTNAME
		cryptsetup luksOpen /dev/vg0/$HOSTNAME $HOSTNAME
		dd if=/dev/zero of=/dev/mapper/$HOSTNAME bs=4M
		mke2fs -t ext4 /dev/mapper/$HOSTNAME
		mount /dev/mapper/$HOSTNAME /mnt

* /boot (gpt)

		parted /dev/sdc
			mklabel gpt
			mkpart primary 2048s 20479s	#512B sectors; ~10MB partition
			mkpart primary 20480s 282623s	#~128MB /boot partition
			mkpart primary 282624s -1s	#rest of drive
			set 1 bios_grub on
		fdisk /dev/sdc
			# mark gpt pseudo partition bootable
		mke2fs -t ext2 /dev/sdc2
		mkdir /mnt/boot
		mount /dev/sdc2 /mnt/boot

# Install OS

1. Edit `/etc/pacman.d/mirrorlist` to suit:

	awk '{print prefix $0} {prefix=""} $2 == "Score:" && $0 !~ /, United States$/ {prefix="#"}' < /etc/pacman.d/mirrorlist > mirrorlist.us
	mv mirrorlist.us /etc/pacman.d/mirrorlist

2. Install base system, skipping the following modules, using: `pacstrap -i /mnt base`

	* ^19 - heirloop-mailx
	* ^23 - jfsutils
	* ^32 - nano
	* ^37 - pcmciautils
	* ^39 - ppp
	* ^42 - reiserfsprogs
	* ^53 - xfsprogs

3. Install grub using: `pacstrap /mnt grub-bios`

4. Configure os:

		genfstab -p /mnt >> /mnt/etc/fstab
		mdadm --detail --scan >> /mnt/etc/mdadm.conf
		arch-chroot /mnt
		echo $HOSTNAME > /etc/hostname
		ln -fns /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
		echo 'LANG="en_US.UTF-8"' > /etc/locale.conf
		vi /etc/locale.gen #enable relevant locales
		locale-gen
		vi /etc/mkinitcpio.conf
			# add video driver (i915, radeon, etc.) to MODULES list
			# i.e. MODULES="i915"
			# add mdadm_udev, lvm2, encrypt to HOOKS list
			# i.e. HOOKS="base udev autodetect pata scsi sata mdadm_udev lvm2 usbinput encrypt filesystems fsck"
		mkinitcpio -p linux
		passwd #set root password

5. Configure grub:

		grub-mkconfig -o /boot/grub/grub.cfg
		grub-install /dev/sdc
		rm -f /boot/grub/grub.cfg.example
		vi /boot/grub/grub.cfg
			# change "set root='hd2,gpt2'" to "set root='hd0,gpt2'"
			# add "lvmwait=/dev/mapper/vg0-$HOSTNAME cryptdevice=/dev/mapper/vg0-$HOSTNAME:$HOSTNAME" to linux command
			# remove search statements

6. Cleanup:

		exit #out of chroot
		umount /mnt/boot /mnt
		reboot

7. Setup networking:

		cp /etc/network.d/examples/ethernet-dhcp /etc/network.d/eth0
		systemctl enable netcfg@eth0

## Resources

* [Installation Guide](https://wiki.archlinux.org/index.php/Arch_Install_Scripts)
* [GRUB2 - ArchWiki](https://wiki.archlinux.org/index.php/Grub2)
* [RAID system encryption with LUKS & LVM](https://bbs.archlinux.org/viewtopic.php?id=120265)
* [[Solved] Pure UEFI GRUB2 LVM2 on LUKS encrypted GPT 3xSSD RAID0](https://bbs.archlinux.org/viewtopic.php?id=126502)
* [Kernel Mode Setting](https://wiki.archlinux.org/index.php/KMS#Disabling_modesetting)

# Additional Software

Run `pacman -Syy` and `pacman-key --populate` first before installing.

* base-devel
* dnsutils
* fortune-mod
* git
* mlocate
* nmap
* ntp
* openssh
* p7zip
* parted
* pkgfile
* rsync
* screen
* squashfs-tools
* sudo
* unzip
* vim
* wget
* wxgtk (optional dependency for p7zip)

Configuration:

* fortune-mod

		cat > /etc/cron.hourly/fortune-motd << 'EOF'
		#!/bin/sh
		/usr/bin/fortune computers cookie definitions linux magic startrek | sed -e '1i\\' -e '$a\\' > /etc/motd
		EOF
		chmod 755 /etc/cron.hourly/fortune-motd
		/etc/cron.hourly/fortune-motd

* screen

		cat >> /etc/sudoers << 'EOF'
		Defaults timestamp_timeout=0
		%wheel ALL=(ALL) ALL
		EOF

* vim

		cp /usr/share/vim/vim73/vimrc_example.vim /etc/skel/.vimrc
		echo 'set viminfo=""' >> /etc/skel/.vimrc
		sed -i 's/\(set backup\)/"\1/' /etc/ske/.vimrc
		mkdir /etc/skel/.vim
		cat > /etc/skel/.vim/.netrwhist << 'EOF'
		let g:netrw_dirhistmax  =0
		let g:netrw_dirhist_cnt =0
		EOF

* other

		updatedb
		systemctl enable ntpd
		systemctl enable sshd
		pkgfile --update
		vi /etc/screenrc
			#uncomment `startup_message off`

# OS Configuration

* agetty

	1. Replace `/etc/issue`: `echo -e '[\l]\n' > /etc/issue`

* audio

	1. Blacklist `i82975x_edac` by creating `/etc/modprobe.d/sound.conf` containing `blacklist i82975x_edac`

* bash

	1. Install `$basedir/etc/bash.bashrc` to `/etc/bash.bashrc`
	2. Install `$basedir/home/bashrc` to `/etc/skel/.bashrc`
	3. Add `set mark-symlinked-directories on` to `/etc/inputrc`

* cronie

	1. Enable `cronie` service: `systemctl enable cronie`

* disable ipv6

	1. Add `net.ipv6.conf.eth0.disable_ipv6 = 1` to `/etc/sysctl.conf`
	2. Add `noipv6rs` to `/etc/dhcpcd.conf`

* filesystem

	1. Disable mounting `tmpfs` on `/tmp`: `systemctl mask tmp.mount`

* iptables

	1. Install `$basedir/etc/iptables.rules` to `/etc/iptables/iptables.rules`
	2. Install `$basedir/etc/ip6tables.rules` to `/etc/iptables/ip6tables.rules`
	3. Enable `iptables` and `ip6tables` services via `systemctl enable ...`

* login.defs

	1. Add `CREATE_HOME yes` to `/etc/login.defs`

# GUI

## X

* xorg-server
* xorg-server-utils
* xf86-video-intel
* xf86-video-ati

## Display Manager

* xorg-xauth
* slim

Configuration:

	systemctl enable slim

Themes:

Themes are defined in `/usr/share/slim/themes`. Simplest customization is to just replace `default/background.jpg` with an image of your choice.

## Window Manager

* i3

Configuration:

1. Install `$basedir/home/i3.conf` to `/etc/skel/.i3/i3.conf`
2. Install `$basedir/home/i3.conf` to `/etc/skel/.i3/i3-nx.conf`
3. Modify `/etc/skel/.i3/i3-nx.conf`, changing the `$mod` variable from `Mod4` to `Mod1`
3. Install `$basedir/home/i3status.conf` to `/etc/skel/.i3/i3status.conf`
4. Install `$basedir/home/xinitrc` to `/etc/skel/.xinitrc`
5. Install `$basedir/home/Xdefaults` to `/etc/skel/.Xdefaults`

Background:

Use feh to change the background image. `~/.xinitrc` will automatically detect `.fehbg` and run it at login.

The screen locker will use ~/.i3/i3lock.png as the lock image if it exists. Otherwise it displays a black screen.

## Desktop Apps

* alsa-utils
* chromium
* cups
* dmenu
* feh
* flashplugin
* ibus-anthy
* ibus-qt
* imagemagick
* libao (pre-req for rdesktop-ipv6)
* otf-ipafonts (aur)
* pidgin
* rdesktop-ipv6 (aur)
* rxvt-unicode
* thunderbird
* vlc
* xautolock
* xorg-xclipboard
* xorg-xprop

Configuration:

	systemctl enable cups
	ibus-setup

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

1. Add `kvm` and `kvm-intel` to `/etc/modules-load.d/kvm.conf`

2. Install `$basedir/contrib/kvm-wrapper.sh` to `/usr/local/bin`

3. Add yourself to the `disk`, `kvm`, and `wheel` groups

4. Note `Hugepagesize` in `/proc/meminfo`. Take the amount of memory to allocate for vms and divide by this number. Add some buffer and cat it to `/proc/sys/vm/nr_hugepages` like so:

		echo 140 > /proc/sys/vm/nr_hugepages

5. If all goes well add it to /etc/sysctl.conf:

		vm.nr_hugepages = 140

6. Add `Options=mode=1770,gid=kvm` to the end of `/usr/lib/systemd/system/dev-hugepages.mount`

7. Restart systemd:

		systemctl --system daemon-reload
		systemctl restart dev-hugepages.mount

## Guest Networking

* Enable packet forwarding:

	1. Change `net.ipv4.ip_forward = 0` to `net.ipv4.ip_forward = 1` in `/etc/sysctl.conf`
	2. Change `net.ipv6.conf.all.forwarding = 0` to `net.ipv6.conf.all.forwarding = 1` in `/etc/sysctl.conf`
	3. Reload kernel parameters: `sysctl -p`

* Configure br0 device:

		pacman -S bridge-utils
		cp $basedir/guest-networking/br0 /etc/network.d/br0
		systemctl enable netcfg@br0

* Configure nat64 device:

		cp $basedir/guest-networking/nat64 /etc/network.d/nat64
		systemctl enable netcfg@br0

* Allow qemu to use bridge br0:

		echo 'allow br0' > /etc/qemu/bridge.conf

* Install and configure bind:

	1. Install `$basedir/guest-networking/named.conf` to `/etc/named.conf`
	2. Set `forwarders` in `/etc/named.conf` to desired dns server
	3. Install `$basedir/guest-networking/named.zone` to `/var/named/named.zone`
	4. Install `$basedir/guest-networking/named.reverse` to `/var/named/named.reverse`
	5. Edit `/var/named/root.hint` commenting out the ipv6 entries
	6. Enable named daemon: `systemctl enable named`
	7. `chmod 770 /var/named`
	8. Create `/etc/resolv.conf.head`:

			search <domainname>
			nameserver ::1

	9. Create `/etc/resolv.conf.tail`:

			domain <domainname>

* Install and configure dhcp:

	1. Install `$basedir/guest-networking/dhcpd.conf` to `/etc/dhcpd.conf`
	2. Enable dhcpd6 daemon: `systemctl enable dhcpd6`

* Install and configure radvd:

	1. Install `$basedir/guest-networking/radvd.conf` to `/etc/radvd.conf`
	2. Enable radvd daemon: `systemctl enable radvd`

* Install and configure tayga:

	1. Compile and install tayga 0.9.2-1 from aur:

			wget http://aur.archlinux.org/packages/ta/tayga/tayga.tar.gz
			tar -xf tayga.tar.gz
			cd tayga
			makepkg
			sudo pacman -U tayga-0.9.2-1-i686.pkg.tar.xz

	2. Install `$basedir/guest-networking/tayga.conf` to `/etc/tayga.conf`
	3. Install `$basedir/contrib/tayga.service` to `/usr/lib/systemd/system/tayga.service`
	4. Enable tayga daemon: `systemctl enable tayga`

## Samba

* samba

Configuration:

1. Install `$basedir/etc/smb.conf` to `/etc/samba/smb.conf`
2. Enable smb daemon: `systemctl enable smbd`
3. Add users: `smbpasswd -a <username>`

