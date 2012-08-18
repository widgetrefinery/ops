# Support Software

* ntfsprogs
* rdesktop-ipv6 1.7.1-2

	wget http://aur.archlinux.org/packages/rd/rdesktop-ipv6/rdesktop-ipv6.tar.gz
	tar -xf rdesktop-ipv6.tar.gz
	cd rdesktop-ipv6
	makepkg
	sudo pacman -U rdesktop-ipv6-1.7.1-2-i686.pkg.tar.xz

* unrar

# Allocate lvm

	lvcreate -L10G -n $VM_HOSTNAME vg0
	cryptsetup luksFormat --use-random /dev/vg0/$VM_HOSTNAME
	cryptsetup luksOpen /dev/vg0/$VM_HOSTNAME $VM_HOSTNAME
	dd if=/dev/zero of=/dev/mapper/$VM_HOSTNAME

# Convert and Install Image

1. Extract and mount the image:

	unrar e /path/to/Windows_7_IE8.part01.exe Win7_IE8.vhd
	modprobe nbd max_part=4
	qemu-nbd -c /dev/nbd0 Win7_IE8.vhd

2. Shrink the image:

	ntfsresize -ns 10468982784 /dev/nbd0p2		#shrink partition down to 9.75G
	ntfsresize -s 10468982784 /dev/nbd0p2
	parted /dev/nbd0
		unit s
		p					#note the current partition info
		rm 2
		mkpart primary ntfs 206848s 20654080s	#9.75G; 512B sectors

3. Load onto lvm:

	dd if=/dev/nbd0 of=/dev/mapper/$VM_HOSTNAME bs=512 count=20654080
	parted /dev/mapper/$VM_HOSTNAME
		unit s
		p					#note the current partition info
		rm 2
		mkpart primary ntfs 206848s -1s		#expand partition to fill rest of drive
		unit b
		p					#note the current partition info
	qemu-nbd -c /dev/nbd1 /dev/mapper/$VM_HOSTNAME
	ntfsresize -fns 10629414912 /dev/nbd1p2		#size of partition, in bytes
	ntfsresize -fs 10629414912 /dev/nbd1p2

4. Cleanup:

	qemu-nbd -d /dev/nbd0
	qemu-nbd -d /dev/nbd1
	rmmod nbd
	rm -f Win7_IE8.vhd

# gzip-based Backup

* backup:

	dd if=/dev/mapper/$VM_HOSTNAME | gzip > $VM_HOSTNAME.bin.gz

* restore:

	gunzip -c $VM_HOSTNAME.bin.gz | dd of=/dev/mapper/$VM_HOSTNAME

# VirtIO Driver

* [virtio drivers](http://www.linux-kvm.org/page/WindowsGuestDrivers/Download_Drivers)

# VMware SVGA II Driver

1. Goto [vmware](www.vmware.com) -> Support & Downloads -> VMware Workstation
2. Download VMware Workstation for Linux
3. Extract the image using: VMware-workstation-Full-7.1.6-744570.i386 -x /some/path
4. Driver iso is in: vmware-tools-windows/windows.iso
5. Mount the iso and extract the contents by running: d:\setup.exe /a
6. VGA driver is in: Common\VMware\Drivers\video
7. Install the driver by going to Device Manager -> Standard VGA Graphics Adapter -> Update driver software

Workstation 8.x doesn't seem to have the VMware SVGA II driver so get
Workstation 7.x. The Windows version doesn't have the vmware tools iso so get
the Linux version.

* [kvm and windows vms](http://www.blah-blah.ch/it/general/kvm-and-windows-vms/)

# Configuration

* change IEUser to standard user; update passwords
* remove programs:
	* Virtual PC Integration Components
* remove features:
	* Media Features
	* Print and Document Services
		* Internet Printing Client
		* Windows Fax and Scan
	* Tablet PC Components
	* Windows Gadget Platform
	* XPS Services
* disable all power options
* disable aero theme
* disable services:
	* Computer Browser
	* Function Discovery Resource Publication
	* IP Helper
	* Offline Files
	* Security Center
	* Shell Hardware Detection
	* SSDP Discovery
	* Themes
	* Windows Audio
	* Windows Audio Endpoint Builder
	* WinHTTP Web Proxy Auto-Discovery Service
* free up disk space:
	* powercfg -h off
	* cleanmgr sageset:99
	* dism /online /cleanup-image /spsuperseded
* enable remote desktop:
	HKEY_LOCAL_MACHINE/SYSTEM/CurrentControlSet/Control/Terminal Server/fDenyTSConnections = 0
* disable ipv4

