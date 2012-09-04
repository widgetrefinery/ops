# Allocate lvm

	lvcreate -L16G -n $VM_HOSTNAME vg0
	cryptsetup luksFormat --use-random /dev/vg0/$VM_HOSTNAME
	cryptsetup luksOpen /dev/vg0/$VM_HOSTNAME $VM_HOSTNAME
	dd if=/dev/zero of=/dev/mapper/$VM_HOSTNAME

# Boot Up VM and Install OS

1. Setup disk:

		parted /dev/vda
			mklabel gpt
			mkpart primary 2048s 20479s	#512B sectors; ~10MB partition
			mkpart primary 20480s -1s	#rest of drive
			set 1 bios_grub on
		mke2fs -t ext4 /dev/vda2
		mount /dev/vda2 /mnt

2. Disable dhcpcd using: `dhcpcd -k`

3. Enable dhclient using: `dhclient -6 eth0`

4. Edit `/etc/pacman.d/mirrorlist` to suit

5. Install base system, skipping the following modules, using: `pacstrap -i /mnt base`

	* ^19 - heirloop-mailx
	* ^23 - jfsutils
	* ^32 - nano
	* ^35 - pcmciautils
	* ^37 - ppp
	* ^40 - reiserfsprogs
	* ^53 - wpa_supplicant
	* ^54 - xfsprogs

6. Install grub and dhclient using: `pacstrap /mnt grub-bios dhclient`

7. Configure os:

		genfstab -p /mnt >> /mnt/etc/fstab
		arch-chroot /mnt
		echo $VM_HOSTNAME > /etc/hostname
		ln -fns /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
		echo 'LANG="en_US.UTF-8"' > /etc/locale.conf
		vi /etc/locale.gen #enable relevant locales
		locale-gen
		vi /etc/mkinitcpio.conf
			#add virtio modules to MODULES list
			#i.e. MODULES="virtio virtio_pci virtio_blk virtio_net virtio_rng"
		mkinitcpio -p linux
		vi /etc/rc.conf #remove network from list of DAEMONS
		echo 'dhclient -6 eth0' >> /etc/rc.local
		passwd #set root password

8. Configure grub:

		grub-mkconfig -o /boot/grub/grub.cfg
		grub-install /dev/vda
		rm -f /boot/grub/grub.cfg.example

9. Cleanup:

		exit #out of chroot
		umount /mnt
		reboot

# Additional Software

Run `pacman -Syy` and `pacman-key --populate` first before installing.

* dnsutils

* mlocate

		updatedb

* nmap

* openssh

	1. Add `sshd` to `DAEMONS` list in `/etc/rc.conf`

* sudo

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

* unzip

* wget

# OS Configuration

* agetty

	1. Replace `/etc/issue`: `echo -e '[\l]\n' > /etc/issue`
	2. Reduce the number of terminals in `/etc/inittab` to 3.

* bash

	1. Install `bash.bashrc` from arch-host to `/etc/bash.bashrc`
	2. Install `home/bashrc` from arch-host to `/etc/skel/.bashrc`

* dhclient

	1. Install `etc/dhclient.init` to `/etc/rc.d/dhclient`
	2. Install `etc/dhclient.conf` to `/etc/dhclient.conf`
	3. Add `dhclient` to `DAEMONS` list in `/etc/rc.conf`
	4. Remove `dhclient ...` from `/etc/rc.local`

* login.defs

	1. Add `CREATE_HOME yes` to `/etc/login.defs`

* ssl certificate

		openssl genrsa -out /etc/ssl/private/server.key 1024
		chmod 440 /etc/ssl/private/server.key
		openssl req -new -x509 -out /etc/ssl/certs/server.crt -key /etc/ssl/private/server.key -days 3650

# Email Services

## Postfix

1. Add or modify the following in `/etc/postfix/main.cf`:

		mydestination = 
		mynetworks_style = host
		virtual_mailbox_domains = regexp:/etc/postfix/vdomains
		virtual_mailbox_base = /var/postfix/
		virtual_mailbox_maps = hash:/etc/postfix/vmailbox, regexp:/etc/postfix/vmailbox-catchall
		virtual_minimum_uid = 99	# 99 is uid of nobody
		virtual_uid_maps = static:99
		virtual_gid_maps = static:99
		inet_protocols = ipv6

2. Create `/etc/postfix/vdomains` to route all recipients to the local machine:

		/.+/ true

3. Create `/etc/postfix/vmailbox` to map desired test accounts:

		testuser1@mydomain.org	testuser1/
		testuser2@mydomain.org	testuser2/

4. Create `/etc/postfix/vmailbox-catchall` to route all other messages to a catchall account:

		/.+/ catchall/

5. Update the postfix databases.

		postmap /etc/postfix/vdomains
		postmap /etc/postfix/vmailbox
		postmap /etc/postfix/vmailbox-catchall

6. Create the `/var/postfix` dir and make it owned by nobody:

		install -o nobody -g nobody -m 0775 -d /var/postfix

7. Add `postfix` to the `DAEMONS` list in `/etc/rc.conf`

## Dovecot

1. Install `etc/dovecot.conf` to `/etc/dovecot/dovecot.conf`

2. Create `/etc/dovecot/users`:

		testuser1:{passwd}
		testuser2:{passwd}
		catchall:{passwd}

3. Generate the hashed password using: `doveadm pw -s ssha512`

4. Add `dovecot` to the `DAEMONS` list in `/etc/rc.conf`

## Attachment Extractor

* perl-mime-tools
* $src/contrib/save-attachments.pl

Configuration:

1. Add or modify the following in `/etc/postfix/main.cf`:

		mydestination = localhost.localdomain
		virtual_alias_maps = hash:/etc/postfix/valiases

2. Modify `/etc/postfix/vdomains` to exclude `localhost.localdomain`:

		!/^localhost\.localdomain$/ true

3. Create `/etc/postfix/valiases` to forward specific recipients to special mailboxes:

		testuser1@mydomain.org	testuser1@archive.mydomain.org testuser1@localhost.localdomain

4. Modify `/etc/postfix/vmailbox` to save the original messages to disk:

		testuser1@archive.mydomain.org testuser1/

5. Modify `/etc/postfix/aliases` to filter specific recipients through the extractor script:

		testuser1: "|/usr/bin/perl /usr/local/bin/save-attachments.pl /attachment/dir /db.file"

6. Update the postfix databases.

		postmap /etc/postfix/vdomains
		postmap /etc/postfix/valiases
		postmap /etc/postfix/vmailbox
		newaliases

# Oracle Database

* base-devel
> elfutils
* libaio
> libstdc++5
> icu
> unixodbc

Fixes:

	ln -fns /usr/bin/basename      /bin/basename
	ln -fns /usr/bin/grep          /bin/grep
	ln -fns /usr/bin/tr            /bin/tr

Increase OS Limits:

	vi /etc/sysctl.conf
		fs.aio-max-nr=1048576
		fs.file-max=6815744
		net.core.rmem_default=262144
		net.core.rmem_max=4194304
		net.core.wmem_default=262144
		net.core.wmem_max=1048576
		net.ipv4.ip_local_port_range=9000 65500
		kernel.sem=250 32000 100 128
		kernel.shmmax=536870912
	vi /etc/security/limits.conf
		@oracle hard nofile 65536
		@oracle hard nproc 16384
	sysctl -p

Installation:

	useradd -d /opt/oracle -m -k /dev/null -r -s /sbin/nologin oracle
	chmod 0755 /opt/oracle
	mkdir /tmp/oracle.tmp
	unzip -q $src/arch-guest/linux_11gR2_database_1of2.zip -d /tmp/oracle.tmp
	unzip -q $src/arch-guest/linux_11gR2_database_1of2.zip -d /tmp/oracle.tmp
	cd /tmp/oracle.tmp/database
	vi $src/arch-guest/oracle-11gR2.rsp
		oracle.install.db.config.starterdb.globalDBName=<database name>
		oracle.install.db.config.starterdb.SID=<sid>
		oracle.install.db.config.starterdb.password.ALL=<password>
	sudo -u oracle ./runInstaller -silent -responseFile $src/arch-guest/oracle-11gR2.rsp -ignoreSysPrereqs -ignorePrereq
	#/opt/oracle/oraInventory/orainstRoot.sh
	#/opt/oracle/11.2.0/root.sh

# Misc Services

* memcached

	1. Remove `-l 127.0.0.1` from `MEMCACHED_ARGS` in `/etc/conf.d/memcached`

	2. Add `memcached` to the `DAEMONS` list in `/etc/rc.conf`

* vsftpd

	1. Modify `/etc/vsftpd.conf`:

		* anonymous_enable=NO
		* local_enable=YES
		* write_enable=YES
		* local_umask=022
		* dirmessage_enable=NO
		* banner_file=/etc/conf.d/vsftpd.banner
		* chroot_local_user=YES
		* allow_writeable_chroot=YES
		* listen=NO
		* listen_ipv6=YES
		* pasv_min_port=2000
		* pasv_max_port=2048

	2. Create `/etc/conf.d/vsftpd.banner`

			***************************************************
			Welcome to the Test FTP Server
			***************************************************
			
			

	3. Add `vsftpd` to the `DAEMONS` list in `/etc/rc.conf`

