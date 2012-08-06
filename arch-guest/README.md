# Installation

## Allocate lvm

	lvcreate -L8G -n $VM_HOSTNAME vg0
	cryptsetup luksFormat --use-random /dev/vg0/$VM_HOSTNAME
	cryptsetup luksOpen /dev/vg0/$VM_HOSTNAME $VM_HOSTNAME
	dd if=/dev/zero of=/dev/mapper/$VM_HOSTNAME

## Boot up VM and install OS

1. Setup disks:

	parted /dev/vda mklabel gpt
	parted /dev/vda mkpart primary 2048s 20479s	#512B sectors; ~10MB partition
	parted /dev/vda mkpart primary 20480s -1s	#rest of drive
	parted /dev/sdc set 1 bios_grub on
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
	vi /etc/locale.conf #enable relevant locales
	locale-gen
	vi /etc/mkinitcpio.conf #add virtio, virtio_pci, virtio_blk, virtio_net, and virtio_ring to MODULES list
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

