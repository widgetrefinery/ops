# Allocate lvm

	lvcreate -L16G -n $VM_HOSTNAME vg0
	cryptsetup luksFormat --use-random /dev/vg0/$VM_HOSTNAME
	cryptsetup luksOpen /dev/vg0/$VM_HOSTNAME $VM_HOSTNAME
	dd if=/dev/zero of=/dev/mapper/$VM_HOSTNAME bs=4M

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

		awk '{print prefix $0} {prefix=""} $2 == "Score:" && $0 !~ /, United States$/ {prefix="#"}' < /etc/pacman.d/mirrorlist > mirrorlist.us
		mv mirrorlist.us /etc/pacman.d/mirrorlist

5. Install base system, skipping the following modules, using: `pacstrap -i /mnt base`

	* ^19 - heirloop-mailx
	* ^23 - jfsutils
	* ^32 - nano
	* ^37 - pcmciautils
	* ^39 - ppp
	* ^42 - reiserfsprogs
	* ^53 - xfsprogs

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
			#i.e. MODULES="virtio virtio_pci virtio_blk virtio_net virtio_ring"
		mkinitcpio -p linux
		passwd #set root password

8. Configure grub:

		grub-mkconfig -o /boot/grub/grub.cfg
		grub-install /dev/vda
		rm -f /boot/grub/grub.cfg.example

9. Cleanup:

		exit #out of chroot
		umount /mnt
		reboot

10. Setup networking:

		cp /etc/network.d/examples/ethernet-dhcp /etc/network.d/lan
		vi /etc/network.d/lan
			# change IP from dhcp to no
			# add IP6=dhcp
			# add DHCLIENT=yes
			# add DHCLIENT6_OPTIONS='-cf /etc/dhclient.conf'
		netcfg lan
		systemctl enable netcfg@lan
		# install $basedir/etc/dhclient.conf to /etc/dhclient.conf

# Additional Software

Run `pacman -Syy` and `pacman-key --populate` first before installing.

* base-devel

* dnsutils

* mlocate

		updatedb

* nmap

* openssh

		systemctl enable sshd

* sudo

		cat >> /etc/sudoers << 'EOF'
		Defaults timestamp_timeout=0
		%wheel ALL=(ALL) ALL
		EOF

* vim

		cp /usr/share/vim/vim73/vimrc_example.vim /etc/skel/.vimrc
		vi /etc/skel/.vimrc
			# add 'set viminfo=""'
			# change set backup to set nobackup
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
	2. Disable unneeded terminals: `systemctl mask getty@ttyX`

* bash

	1. Install `/etc/bash.bashrc` from arch-host
	2. Install `/etc/skel/.bashrc` from arch-host
	3. Add `set mark-symlinked-directories on` to `/etc/inputrc`

* filesystem

	1. Comment out `/tmp` from `/etc/fstab`
	2. Disable mounting `tmpfs` on `/tmp`: `systemctl mask tmp.mount`

* login.defs

	1. Add `CREATE_HOME yes` to `/etc/login.defs`

* sysctl.conf

	1. Add `net.ipv6.bindv6only = 1` to `/etc/sysctl.conf`

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
		virtual_mailbox_maps = hash:/etc/postfix/vmailbox, static:postmaster/
		virtual_minimum_uid = 99	# 99 is uid of nobody
		virtual_uid_maps = static:99
		virtual_gid_maps = static:99
		inet_protocols = ipv6

2. Create `/etc/postfix/vdomains` to route all recipients to the local machine:

		/.+/ true

3. Create `/etc/postfix/vmailbox` to map desired test accounts:

		testuser1@mydomain.org	testuser1/
		testuser2@mydomain.org	testuser2/

4. Update the postfix databases.

		postmap /etc/postfix/vdomains
		postmap /etc/postfix/vmailbox

5. Create the `/var/postfix` dir and make it owned by nobody:

		install -o nobody -g nobody -m 0775 -d /var/postfix

6. Enable postfix at boot:

		systemctl enable postfix

## Dovecot

1. Install `$basedir/etc/dovecot.conf` to `/etc/dovecot/dovecot.conf`

2. Create `/etc/dovecot/users`:

		testuser1:{passwd}
		testuser2:{passwd}
		postmaster:{passwd}

3. Generate the hashed password using: `doveadm pw -s ssha512`

4. Enable dovecot at boot: `systemctl enable dovecot`

## Attachment Extractor

* perl-mime-tools
* $basedir/contrib/save-attachments.pl

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

* libaio
* libstdc++5
* mksh

Fixes:

	ln -fns /usr/bin/basename /bin/basename
	ln -fns /usr/bin/grep     /bin/grep
	ln -fns /usr/bin/tr       /bin/tr
	ln -fns mksh              /bin/ksh
	ln -fns lib               /usr/lib64

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
	unzip -q $src/linux.x64_11gR2_database_1of2.zip -d /tmp/oracle.tmp
	unzip -q $src/linux.x64_11gR2_database_1of2.zip -d /tmp/oracle.tmp
	cd /tmp/oracle.tmp/database
	# run the following as root in another terminal
	while [ ! -e /opt/oracle/database/11.2.0/sysman/lib/ins_emagent.mk ]; do sleep 1; done; sudo -u oracle sed -i 's/$(MK_EMAGENT_NMECTL)/$(MK_EMAGENT_NMECTL) -lnnz11/' /opt/oracle/database/11.2.0/sysman/lib/ins_emagent.mk
	sudo -u oracle ./runInstaller -silent -responseFile $basedir/oracle/oracle-11gR2.rsp -ignoreSysPrereqs -ignorePrereq
	# ignore the error: /usr/lib/libstdc++.so.5: undefined reference to `memcpy@GLIBC_2.14'
	/opt/oracle/oraInventory/orainstRoot.sh
	/opt/oracle/database/11.2.0/root.sh
	sudo chmod 6751 /opt/oracle/database/11.2.0/bin/oracle
	install -o root   -g root   -m 0644 $basedir/oracle/ld.so.conf /etc/ld.so.conf.d/oracle.conf
	install -o root   -g root   -m 0755 $basedir/oracle/profile.sh /etc/profile.d/oracle.sh
	install -o oracle -g oracle -m 0644 $basedir/oracle/sqlnet.ora /opt/oracle/database/11.2.0/network/admin/sqlnet.ora
	ldconfig
	visudo # add 'Defaults env_keep += ORACLE_HOME'

## Creatig a Database

	# must be run from the local console, not over ssh
	sudo -u oracle /opt/oracle/database/11.2.0/bin/dbca -silent -createDatabase -templateName General_Purpose.dbc -gdbname <global database name> -sid <sid> -totalMemory 512
	install -o oracle -g oracle -m 0644 $basedir/oracle/listener.ora /opt/oracle/database/11.2.0/network/admin/
	# modify the hostname and sid id in listener.ora to suit

## Starting a Database

	sudo -u oracle ORACLE_SID=<sid> /opt/oracle/database/11.2.0/bin/sqlplus '/ as sysdba'
		startup
	sudo -u oracle /opt/oracle/database/11.2.0/bin/lsnrctl start

## Stopping a Database

	sudo -u oracle ORACLE_SID=<sid> /opt/oracle/database/11.2.0/bin/sqlplus '/ as sysdba'
		shutdown
	sudo -u oracle /opt/oracle/database/11.2.0/bin/lsnrctl stop

# Misc Services

* cronolog

		wget http://aur.archlinux.org/packages/cr/cronolog/cronolog.tar.gz
		tar -xf cronolog.tar.gz
		cd cronolog
		makepkg
		pacman -U cronolog-1.6.2-4-x86_64.pkg.tar.xz
		ln -fns /usr/sbin/cronolog /usr/local/sbin/cronolog

* daemontools

		wget http://aur.archlinux.org/packages/da/daemontools/daemontools.tar.gz
		tar -xf daemontools.tar.gz
		cd daemontools
		vi PKGBUILD #change /usr/sbin paths to /usr/local/bin
		vi daemontools.install #change /usr/sbin paths to /usr/local/bin
		makepkg
		pacman -U daemontools-0.76-5-x86_64.pkg.tar.xz
		chmod 4755 /usr/sbin/svstat

* memcached

	1. Remove `-l 127.0.0.1` from `ExecStart` in `/usr/lib/systemd/system/memcached.service`

	2. Enable memcached at boot: `systemctl enable memcached`

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
		* seccomp_sandbox=NO

	2. Create `/etc/conf.d/vsftpd.banner`

			***************************************************
			Welcome to the Test FTP Server
			***************************************************
			
			

	3. Add `vsftpd` to the `DAEMONS` list in `/etc/rc.conf`

