# Allocate lvm

	lvcreate -L8G -n $VM_HOSTNAME vg0
	cryptsetup luksFormat --use-random /dev/vg0/$VM_HOSTNAME
	cryptsetup luksOpen /dev/vg0/$VM_HOSTNAME $VM_HOSTNAME
	dd if=/dev/zero of=/dev/mapper/$VM_HOSTNAME

# Boot up VM and install OS

1. Setup disks:

	parted /dev/vda
		mklabel gpt
		mkpart primary 2048s 20479s	#512B sectors; ~10MB partition
		mkpart primary 20480s -1s	#rest of drive
		set 1 bios_grub on
	mke2fs -t ext4 /dev/vda2
	mount /dev/vda2 /mnt

2. Enable networking:

	dhclient -6 eth0

3. Install OS:

	sed -i 's/ --noconfirm / /' /usr/bin/pacstrap
	vi /etc/pacman.d/mirrorlist #modify mirror list to suit
	pacstrap /mnt base
	pacstrap /mnt grub-bios
	pacstrap /mnt dhclient

4. Configure OS:

	genfstab -p /mnt >> /mnt/etc/fstab
	arch-chroot /mnt
	echo $VM_HOSTNAME > /etc/hostname
	ln -fns /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
	echo 'LANG="en_US.UTF-8"' > /etc/locale.conf
	vi /etc/locale.gen #enable relevant locales
	locale-gen
	vi /etc/mkinitcpio.conf #add virtio, virtio_pci, virtio_blk, virtio_net, and virtio_rng to MODULES list
	mkinitcpio -p linux
	vi /etc/rc.conf #remove network from list of DAEMONS
	echo 'dhclient -6 eth0' >> /etc/rc.local
	passwd #set root password

5. Configure grub:

	grub-mkconfig -o /boot/grub/grub.cfg
	grub-install /dev/vda
	rm -f /boot/grub/grub.cfg.example

6. Cleanup:

	exit #out of chroot
	umount /mnt
	reboot

# Additional Software

* dnsutils
* mlocate

	updatedb

* nmap
* openssh

	1. Add sshd to DAEMONS list in /etc/rc.conf

* sudo

	1. Add the following to /etc/sudoers:

		Defaults timestamp_timeout=0
		%wheel ALL=(ALL) ALL

* vim

	cp /usr/share/vim/vim73/vimrc_example.vim /etc/skel/.vimrc
	echo 'set viminfo=""' >> /etc/skel/.vimrc
	sed -i 's/\(set backup\)/"\1/' /etc/ske/.vimrc
	mkdir /etc/skel/.vim
	echo 'let g:netrw_dirhistmax  =0' >  /etc/skel/.vim/.netrwhist
	echo 'let g:netrw_dirhist_cnt =0' >> /etc/skel/.vim/.netrwhist

# Configuration

* agetty

	1. Replace /etc/issue:

		echo -e '[\l]\n' > /etc/issue

	2. Reduce the number of terminals in /etc/inittab to 3.

* bash

	1. Install custom bash.bashrc from arch-host to /etc/bash.bashrc
	2. Remove PS1 from /etc/skel/.bashrc
	3. Add "alias vi=vim" to /etc/skel/.bashrc

* dhclient

	1. Install custom dhclient to /etc/rc.d/dhclient
	2. Add dhclient to DAEMONS list in /etc/rc.conf

* login.defs

	1. Add 'CREATE_HOME yes' to /etc/login.defs

