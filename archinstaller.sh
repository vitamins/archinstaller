#!/bin/bash

###############################################################
# title		: archinstaller.sh
# description	: Automated installation script for arch linux
# authors	: Dennis Anfossi & teateawhy
# contact	: https://github.com/vitamins/archinstaller
# date		: 6.11.2013
# version	: 0.4.9
# license	: GPLv2
# usage		: Edit ari.conf and run ./archinstaller.sh
###############################################################

# functions
config_fail() {
echo -ne "\033[31m"
echo '| archinstaller.sh:'
echo "| Error, please check variable $1 !"
echo -ne "\033[0m"
exit 1
}

fail() {
echo -ne "\033[31m"
echo '| archinstaller.sh:'
echo "| Error, $1"
echo -ne "\033[0m"
exit 1
}

message() {
echo -e "\033[31m"
echo '| archinstaller.sh:'
echo "| $1"
echo -e "\033[0m"
sleep 2
}

pacman_install() {
pacman --color always --noconfirm --needed -r /mnt --cachedir=/mnt/var/cache/pacman/pkg -S $@
}

check_conf() {
message 'Checking configuration..'
## confirm
[[ "$confirm" = 'yes' || "$confirm" = 'no' ]] || config_fail 'confirm'
## edit_conf
[[ "$edit_conf" = 'yes' || "$edit_conf" = 'no' ]] || config_fail 'edit_conf'
## dest_disk
[ -z "$dest_disk" ] && config_fail 'dest_disk'
### check if dest_disk is a valid block device
udevadm info --query=all --name="$dest_disk" | grep DEVTYPE=disk > /dev/null || config_fail 'dest_disk'
# decide for gpt or mbr
if [ "$partition_table" = 'auto' ]; then
	dest_disk_size=$(blockdev --getsize64 "$dest_disk")
	# check if disk is larger than 1099511627776 bytes ( 1TiB )
	if [ "$dest_disk_size" -gt 1099511627776 ]; then
		partition_table='gpt'
	else
		partition_table='mbr'
	fi
fi
## manual_part
if [ "$manual_part" = 'yes' ]; then
	findmnt -nfo TARGET /mnt > /dev/null || fail 'no mounted filesystem found on /mnt!'
	[ -z "$root_part_number" ] && config_fail 'root_part_number'
	[ -b "$dest_disk""$root_part_number" ] || config_fail 'root_part_number'
else
	[ "$manual_part" = 'no' ] || config_fail 'manual_part'
	# check /mnt for availability
	findmnt -nfo TARGET /mnt > /dev/null && fail 'working directory /mnt is blocked by mounted filesystem!'
	## check dest_disk for mounted filesystems
	mount | grep "$dest_disk" > /dev/null && fail 'found mounted filesystem on destination disk!'
	## swap
	if [ "$swap" = 'yes' ]; then
		### swap_size
		[ -z "$swap_size" ] && config_fail 'swap_size'
	else
		[ "$swap" = 'no' ] || config_fail 'swap'
	fi
	## root_size
	[ -z "$root_size" ] && config_fail 'root_size'
	## home
	if [ "$home" = 'yes' ]; then
		## home_size
		if [ "$home_size" != 'free' ]; then
			[ -z "$home_size" ] && config_fail 'home_size'
		fi
		## encrypt_home
		if [ "$encrypt_home" = 'yes' ]; then
			### cipher
			[ -z "$cipher" ] && config_fail 'cipher'
			### hash_alg
			[ -z "$hash_alg" ] && config_fail 'hash_alg'
			### key_size
			[ -z "$key_size" ] && config_fail 'key_size'
		else
			[ "$encrypt_home" = 'no' ] || config_fail 'encrypt_home'
		fi
	else
		[ "$home" = 'no' ] || config_fail 'home'
	fi
	## fstpye
	[ -z "$fstype" ] && config_fail 'fstype'
	fstypes='btrfs ext2 ext3 ext4 jfs nilfs2 reiserfs xfs'
	correct=0
	for fs in ${fstypes[@]}; do
	        if [ "$fstype" = "$fs" ]; then
	                correct=1
	                break
	        fi
	done
	[ "$correct" = 1 ] || config_fail 'fstype'
	if [ "$fstype" = 'btrfs' ]; then
		which mkfs.btrfs > /dev/null || fail 'this script requires the btrfs-progs package!'
		packages+=( btrfs-progs )
	elif [ "$fstype" = 'nilfs2' ]; then
		which mkfs.nilfs2 > /dev/null || fail 'this script requires the nilfs-utils package!'
		packages+=( nilfs-utils )
	fi
fi
## partition_table
if [ "$partition_table" = 'gpt' ]; then
	if [ "$manual_part" = 'no' ]; then
		which gdisk > /dev/null || fail 'this script requires the gptfdisk package!'
	fi
else
	[ "$partition_table" = 'mbr' ] || config_fail 'partition_table'
fi
## uefi
if [ "$uefi" = 'yes' ]; then
	### check if install host is booted in uefi mode
	if [ -z "$(mount -t efivarfs)" ]; then
		mount -t efivarfs efivarfs /sys/firmware/efi/efivars > /dev/null || config_fail 'uefi'
	fi
	efivar -l > /dev/null || config_fail 'uefi'
	## bootloader
	[[ "$bootloader" = 'grub' || "$bootloader" = 'gummiboot' ]] || config_fail 'bootloader'
	## partition_table
	[ "$partition_table" = 'gpt' ] || config_fail 'partition_table'
	if [ "$manual_part" = 'no' ]; then
		which mkfs.vfat > /dev/null || fail 'this script requires the dosfstools package!'
	fi
else
	[ "$uefi" = 'no' ] || config_fail 'uefi'
	## bootloader
	[[ "$bootloader" = 'grub' || "$bootloader" = 'syslinux' ]] || config_fail 'bootloader'
fi
## mirror
[ -z "$mirror" ] && config_fail 'mirror'
## base_devel
[[ "$base_devel" = 'yes' || "$base_devel" = 'no' ]] || config_fail 'base_devel'
## locale_gen
[ -z "$locale_gen" ] && config_fail 'locale_gen'
## locale_conf
[ -z "$locale_conf" ] && config_fail 'locale_conf'
## keymap
[ -z "$keymap" ] && config_fail 'keymap'
localectl --no-pager list-keymaps | grep -x "$keymap" > /dev/null || config_fail 'keymap'
## font
[ -z "$font" ] && config_fail 'font'
## timezone
[ -z "$timezone" ] && config_fail 'timezone'
timedatectl --no-pager list-timezones | grep -x "$timezone" > /dev/null || config_fail 'timezone'
## hardware_clock
[[ "$hardware_clock" = 'utc' || "$hardware_clock" = 'localtime' ]] || config_fail 'hardware_clock'
## hostname
[ -z "$hostname" ] && config_fail 'hostname'
## wired
case "$wired" in
	no)	;;
	dhcpcd)	;;
	netctl)	;;
	ifplugd);;
	*)	config_fail 'wired';;
esac
## set_root_password
[[ "$set_root_password" = 'yes' || "$set_root_password" = 'no' ]] || config_fail 'set_root_password'
## add_user
if [ "$add_user" = 'yes' ]; then
	### user_name
	[ -z "$user_name" ] && config_fail 'user_name'
else
	[ "$add_user" = 'no' ] || config_fail 'user_name'
fi

## xorg
if [ "$xorg" = 'yes' ]; then
	### install_desktop_environment
	if [ "$install_desktop_environment" = 'yes' ]; then
		#### desktop_environment
		case "$desktop_environment" in
			xfce4)		;;
			gnome)		;;
			kde)		;;
			cinnamon)	;;
			lxde)		;;
			enlightenment17);;
			*)		config_fail 'desktop_environment';;
		esac
	else
		[ "$install_desktop_environment" = 'no' ] || config_fail 'install_desktop_environment'
	fi
	### install_display_manager
	if [ "$install_display_manager" = 'yes' ]; then
		#### display_manager
		case "$display_manager" in
			gdm)	;;
			kdm)	;;
			lxdm)	;;
			xdm)	;;
			*)	config_fail 'display_manager';;
		esac
		### graphical login
		[[ "$graphical_login" = 'yes' || "$graphical_login" = 'no' ]] || config_fail 'graphical_login'
	else
		[ "$install_display_manager" = 'no' ] || config_fail 'install_display_manager'
	fi
else
	[ "$xorg" = 'no' ] || config_fail 'xorg'
fi

## no config_fail beyond this point
message 'Configuration appears to be complete.'
}

make_part() {
# ask for confirmation
if [ "$confirm" = 'yes' ]; then
	echo -e "\033[31m"
	echo '----------------------------------------'
	echo 'The destination drive will be formatted.'
	echo "All data on "$dest_disk" will be lost!"
	echo '----------------------------------------'
	echo -ne "\033[0m"
	answer='x'
	while [ "$answer" != 'YES' ]; do
		echo -n 'Continue? (YES/no) '
		read answer
		if [ "$answer" = 'no' ]; then
			fail 'Script cancelled!'
		fi
	done
fi

# prepare disk
message 'Preparing disk..'
umount "$dest_disk"* || :
wipefs -a "$dest_disk"
dd bs=1K count=17 iflag=nocache oflag=direct if=/dev/zero of="$dest_disk"; blockdev --rereadpt "$dest_disk"
sync; blockdev --rereadpt "$dest_disk"; sleep 5

# partitioning
message 'Creating partitions..'

## partition layout
if [ "$uefi" = 'yes' ]; then
	if [ "$swap" = 'yes' ]; then
		efi_part_number=1
		swap_part_number=2
		root_part_number=3
		home_part_number=4
	else
		efi_part_number=1
		root_part_number=2
		home_part_number=3
	fi
else
	if [[ "$bootloader" = 'grub' && "$partition_table" = 'gpt' ]]; then
		if [ "$swap" = 'yes' ]; then
			bios_part_number=1
			swap_part_number=2
			root_part_number=3
			home_part_number=4
		else
			bios_part_number=1
			root_part_number=2
			home_part_number=3
		fi
	else
		if [ "$swap" = 'yes' ]; then
			swap_part_number=1
			root_part_number=2
			home_part_number=3
		else
			root_part_number=1
			home_part_number=2
		fi
	fi
fi

## MBR
if [ "$partition_table" = 'mbr' ]; then

	## swap partition
	if [ "$swap" = 'yes' ]; then
		echo -e "n\n \
		p\n \
		"$swap_part_number"\n \
		\n \
		+"$swap_size"\n \
		t\n \
		82\n
		w" | fdisk "$dest_disk"

		## wait a moment
		sleep 1
	fi

	## root partition
	echo -e "n\n \
	p\n \
	"$root_part_number"\n \
	\n \
	+"$root_size"\n \
	w" | fdisk "$dest_disk"

	## wait a moment
	sleep 1

	## home partition
	if [ "$home" = 'yes' ]; then
		if [ "$home_size" = 'free' ]; then
			echo -e "n\n \
			p\n \
			"$home_part_number"\n \
			\n \
			\n \
			w" | fdisk "$dest_disk"
		else
			echo -e "n\n \
			p\n \
			"$home_part_number"\n \
			\n \
			+"$home_size"\n \
			w" | fdisk "$dest_disk"
		fi
	fi
## GPT
else
	## EFI system partition
	if [ "$uefi" = 'yes' ]; then
		# DO NOT INSERT WHITESPACES OR GDISK WILL FAIL
		echo -e "n\n\
"$efi_part_number"\n\
\n\
+"$esp_size"\n\
EF00\n\
w\n\
Y" | gdisk "$dest_disk"

		# wait a moment
		sleep 1
	else
		## BIOS boot partition
		if [ "$bootloader" = 'grub' ]; then
			echo -e "n\n\
"$bios_part_number"\n\
\n\
+1007K\n\
EF02\n\
w\n\
Y" | gdisk "$dest_disk"

			# wait a moment
			sleep 1
		fi
	fi

	## swap partition
	if [ "$swap" = 'yes' ]; then
		echo -e "n\n\
"$swap_part_number"\n\
\n\
+"$swap_size"\n\
8200\n\
w\n\
Y" | gdisk "$dest_disk"

		# wait a moment
		sleep 1
	fi

	## root partition
	echo -e "n\n\
"$root_part_number"\n\
\n\
+"$root_size"\n\
8300\n\
w\n\
Y" | gdisk "$dest_disk"

	# wait a moment
	sleep 1

	## home partition
	if [ "$home" = 'yes' ]; then
		if [ "$home_size" = 'free' ]; then
			echo -e "n\n\
"$home_part_number"\n\
\n\
\n\
8300\n\
w\n\
Y" | gdisk "$dest_disk"
		else
			echo -e "n\n\
"$home_part_number"\n\
\n\
+"$home_size"\n\
8300\n\
w\n\
Y" | gdisk "$dest_disk"
		fi
	fi
fi

# encrypt home partition
if [ "$home" = 'yes' ]; then
	if [ "$encrypt_home" = 'yes' ]; then
		message 'Setting up encryption..'
		modprobe dm_mod
		## erase partition with /dev/zero
		message 'Secure erasure of partition. This may take a while..'
		dd bs=4M iflag=nocache oflag=direct if=/dev/zero of="$dest_disk""$home_part_number" || sync
		message 'You will be asked for the new encryption passphrase soon.'
		## map physical partition to LUKS
		cryptsetup -qyc "$cipher" -h "$hash_alg" -s "$key_size" luksFormat "$dest_disk""$home_part_number"
		## open encrypted volume
		message 'Please enter the encryption passphrase again to open the container.'
		cryptsetup open "$dest_disk""$home_part_number" home
	fi
fi

# Create and mount filesystems
## swap
if [ "$swap" = 'yes' ]; then
	message 'Formatting swap..'
	mkswap "$dest_disk""$swap_part_number"
	swapon "$dest_disk""$swap_part_number"
fi

## root
message 'Formatting root..'
mkfs."$fstype" "$dest_disk""$root_part_number"
message 'Mounting root..'
mount -t "$fstype" "$dest_disk""$root_part_number" /mnt

## ESP
if [ "$uefi" = 'yes' ]; then
	message 'Formatting ESP..'
	mkfs.vfat -F32 "$dest_disk""$efi_part_number"
	mkdir -p /mnt/boot
	message 'Mounting ESP..'
	mount "$dest_disk""$efi_part_number" /mnt/boot
fi

## home
if [ "$home" = 'yes' ]; then
	message 'Formatting home..'
	if [ "$encrypt_home" = 'yes' ]; then
		mkfs."$fstype" /dev/mapper/home
		mkdir /mnt/home
		message 'Mounting home..'
		mount -t "$fstype" /dev/mapper/home /mnt/home
	else
		mkfs."$fstype" "$dest_disk""$home_part_number"
		mkdir /mnt/home
		message 'Mounting home..'
		mount -t "$fstype" "$dest_disk""$home_part_number" /mnt/home
	fi
fi
}

configure_system() {
message 'Configuring system..'
## crypttab
if [ "$manual_part" = 'no' ]; then
	if [ "$home" = 'yes' ]; then
		if [ "$encrypt_home" = 'yes' ]; then
			home_part_uuid=$(lsblk -dno UUID "$dest_disk""$home_part_number")
			echo "home UUID="$home_part_uuid" none luks,timeout=60s" >> /mnt/etc/crypttab
			[ "$edit_conf" = 'yes' ] && "$EDITOR" /mnt/etc/crypttab
		fi
	fi
fi

## fstab
genfstab -U -p /mnt > /mnt/etc/fstab
[ "$edit_conf" = 'yes' ] && "$EDITOR" /mnt/etc/fstab

## locale
[ "$locale_gen" = 'en_US.UTF-8 UTF-8' ] || echo 'en_US.UTF-8 UTF-8' >> /mnt/etc/locale.gen
echo "$locale_gen" >> /mnt/etc/locale.gen
echo "LANG="$locale_conf"" > /mnt/etc/locale.conf
arch-chroot /mnt /usr/bin/locale-gen

## console font and keymap
echo "KEYMAP="$keymap"" > /mnt/etc/vconsole.conf
echo "FONT="$font"" >> /mnt/etc/vconsole.conf

## timezone
ln -s /usr/share/zoneinfo/"$timezone" /mnt/etc/localtime

## hardware clock
hwclock --systohc --"$hardware_clock"

## kernel modules
if [ "$configure_modules" = 'yes' ]; then
	for m in ${modules[@]}; do
		echo "$m" >> /mnt/etc/modules-load.d/modules.conf
	done
fi

## hostname
echo "$hostname" > /mnt/etc/hostname

## wired network service
if [ "$wired" != 'no' ]; then
	### network interface shall always be named eth0
	touch /mnt/etc/udev/rules.d/80-net-name-slot.rules
	case "$wired" in
		dhcpcd)	arch-chroot /mnt /usr/bin/systemctl enable dhcpcd@eth0.service;;
		netctl)	cp /mnt/etc/netctl/examples/ethernet-dhcp /mnt/etc/netctl/ethernet_dynamic
			arch-chroot /mnt /usr/bin/netctl enable ethernet_dynamic;;
		ifplugd)pacman_install ifplugd
			arch-chroot /mnt /usr/bin/systemctl enable netctl-ifplugd@eth0.service;;
	esac
fi

##  mkinitcpio
if [ "$edit_conf" = 'yes' ]; then
	"$EDITOR" /mnt/etc/mkinitcpio.conf
	arch-chroot /mnt /usr/bin/mkinitcpio -p linux
fi
}

install_bootloader() {
message 'Installing bootloader..'
if [ "$uefi" = 'yes' ]; then
	## UEFI
	if [ "$bootloader" = 'grub' ]; then
		## install grub
		pacman_install grub efibootmgr dosfstools os-prober
		# in special cases: --target='i386-efi'
		echo 'mount -t efivarfs efivarfs /sys/firmware/efi/efivars; grub-install --target=x86_64-efi \
		--efi-directory=/boot --bootloader-id=arch_grub --recheck; grub-mkconfig -o /boot/grub/grub.cfg' \
		| arch-chroot /mnt /bin/bash
	else
		## install gummiboot
		pacman_install gummiboot
		echo 'mount -t efivarfs efivarfs /sys/firmware/efi/efivars; gummiboot install' \
		| arch-chroot /mnt /bin/bash

		## configure gummiboot
		root_part_partuuid=$(lsblk -dno PARTUUID "$dest_disk""$root_part_number")
		echo "title	Arch Linux
linux	/vmlinuz-linux
initrd	/initramfs-linux.img
options	root=PARTUUID="$root_part_partuuid" rw" > /mnt/boot/loader/entries/arch.conf
	fi
else
	## BIOS
	if [ "$bootloader" = 'syslinux' ]; then
		## install syslinux
		pacman_install syslinux gptfdisk
		arch-chroot /mnt /usr/bin/syslinux-install_update -i -a -m

		## configure syslinux
		root_part_uuid=$(lsblk -dno UUID "$dest_disk""$root_part_number")
		echo "PROMPT 1
TIMEOUT 50
DEFAULT arch

LABEL arch
	LINUX ../vmlinuz-linux
	APPEND root=UUID="$root_part_uuid" rw
	INITRD ../initramfs-linux.img

LABEL archfallback
	LINUX ../vmlinuz-linux
	APPEND root=UUID="$root_part_uuid" rw
	INITRD ../initramfs-linux-fallback.img" > /mnt/boot/syslinux/syslinux.cfg
	else
		## install grub
		pacman_install grub os-prober
		arch-chroot /mnt /usr/bin/grub-install --target=i386-pc --recheck "$dest_disk"

		## configure grub
		arch-chroot /mnt /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
	fi
fi
}

install_xorg() {
if [ "$xorg" = 'yes' ]; then
	pacman_install xorg-server xorg-server-utils xorg-xinit xf86-video-vesa
	# install desktop environment
	if [ "$install_desktop_environment" = 'yes' ]; then
		case "$desktop_environment" in
			xfce4)		 pacman_install xfce4 xfce4-goodies;;
			gnome)		 pacman_install gnome gnome-extra;;
			kde)		 pacman_install kde;;
			cinnamon)	 pacman_install cinnamon;;
			lxde)		 pacman_install lxde;;
			enlightenment17) pacman_install enlightenment17;;
		esac
	fi
	# install display manager
	if [ "$install_display_manager" = 'yes' ]; then
		case "$display_manager" in
			gdm)	pacman_install gdm;;
			kdm)	pacman_install kdebase-workspace;;
			lxdm)	pacman_install lxdm;;
			xdm)	pacman_install xorg-xdm;;
		esac
		[ "$graphical_login" = 'yes' ] && \
		arch-chroot /mnt /usr/bin/systemctl enable "$display_manager".service
	fi
fi
}

# check root priviledges
[ "$EUID" = '0' ] || fail 'this script must be executed as root!'

# check arch linux
[ -e /etc/arch-release ] || fail 'this script must be executed on arch linux!'

# arch-install-scripts required
which pacstrap > /dev/null || fail 'this script requires the arch-install-scripts package!'

# wget required
which wget > /dev/null || fail 'this script requires the wget package!'

# set defaults
confirm='yes'
edit_conf='yes'
manual_part='no'
esp_size='512M'
home='yes'
home_size='free'
cipher='aes-xts-plain64'
hash_alg='sha1'
key_size='256'

[ -z "$EDITOR" ] && EDITOR='/usr/bin/nano'

# check if configuration file is here
[ -s ./ari.conf ] || fail "configuration file ari.conf not found in $(pwd) !"

start_time=$(date +%s)

echo -ne "\033[31m"
echo  '--------------------------------------'
echo  '     Welcome to archinstaller.sh!     '
echo  '--------------------------------------'
echo -ne "\033[0m"

# source configuration file
source ./ari.conf

# check configuration
check_conf

# load package list
[ -s ./pkglist.txt ] && packages+=( $( < ./pkglist.txt ) )
if [ -z "$packages" ]; then
	install_packages='no'
else
	install_packages='yes'
fi

# module list
if [ -z "$modules" ]; then
	configure_modules='no'
else
	configure_modules='yes'
fi

# check internet connection
message 'Checking internet connection..'
if wget -q --tries=10 --timeout=5 http://mirrors.kernel.org -O /tmp/index.html; then
	[ -s /tmp/index.html ] || fail 'please check the network connection!'
else
	fail 'please check the network connection!'
fi

# check mirror status
if [ "$mirror" != 'keep' ]; then
	if wget -q --tries 10 --timeout=5 "$mirror"lastsync -O /tmp/lastsync.txt; then
		[ -s /tmp/lastsync.txt ] || fail 'please check the mirror status and configuration!'
	else
		fail 'please check the mirror status and configuration!'
	fi
fi

# paranoid shell
set -e -u

# create partitions & filesystems, mount filesystems
[ "$manual_part" = 'no' ] && make_part

# mirror
if [ "$mirror" != 'keep' ]; then
	mirror='Server = '"$mirror"'$repo/os/$arch'
	echo "$mirror" > /etc/pacman.d/mirrorlist
fi

# pacstrap base
message 'Installing base system..'
if [ "$base_devel" = 'yes' ]; then
	pacstrap /mnt base base-devel
else
	pacstrap /mnt base
fi

# configure system
configure_system

# bootloader
install_bootloader

# root password
if [ "$set_root_password" = 'yes' ]; then
	message 'Setting password for root user..'
	arch-chroot /mnt /usr/bin/passwd root
fi

# add user
if [ "$add_user" = 'yes' ]; then
	arch-chroot /mnt /usr/bin/useradd -m -g users -G wheel -s /bin/bash "$user_name"
	## set user password
	message "Setting password for "$user_name".."
	arch-chroot /mnt /usr/bin/passwd "$user_name"
fi

# install xorg
install_xorg

# install additional packages
if [ "$install_packages" = 'yes' ]; then
	message 'Installing additional packages..'
	pacman_install ${packages[@]} || :
fi

# unmount
if [ "$manual_part" = 'yes' ]; then
	message 'Unmount the manually mounted partitions before rebooting!'
else
	umount -R /mnt
	if [ "$home" = 'yes' ]; then
		## close encrypted volume
		[ "$encrypt_home" = 'yes' ] && cryptsetup close home
	fi
fi

# report
finish_time=$(date +%s)
min=$(( $((finish_time - start_time)) /60 ))

echo -e "\033[31m"
echo '-----------------------------'
echo '   Installation completed!   '
echo 'Reboot the computer: # reboot'
echo '-----------------------------'
echo -e "\033[0m"
echo "Total install time: "$min" minutes"

exit 0
