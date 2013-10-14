#!/bin/bash
#
###############################################################
# title		: archinstaller.sh
# description	: automated installation script for arch linux
# authors	: Dennis Anfossi & teateawhy
# contact	: bbs.archlinux.org/profile.php?id=57887
# date		: 10-11
# version	: 0.4.3
# license	: GPLv2
# usage		: edit ari.conf and run ./archinstaller.sh
###############################################################
#
# BIOS ONLY, NO UEFI SUPPORT.
# Don't forget to edit ari.conf .
#

# functions
config_fail() {
echo -e "\033[31m"
echo '| archinstaller.sh:'
echo "| Error, please check variable $1 !"
echo -e "\033[0m"
exit 1
}

fail() {
echo -e "\033[31m"
echo '| archinstaller.sh:'
echo "| Error, $1"
echo -e "\033[0m"
exit 1
}

message() {
echo -e "\033[31m"
echo '| archinstaller.sh:'
echo "| $1"
echo -e "\033[0m"
sleep 2
}

# check root priviledges
[ "$EUID" != '0' ] && fail 'you must execute the script as the root user.'

# check arch linux
[ ! -e /etc/arch-release ] && fail 'you must execute the script on arch linux.'

start_time=$(date +%s)

echo -e "\033[31m"
echo  '======================================'
echo  '     Welcome to archinstaller.sh!     '
echo  '======================================'
echo -e "\033[0m"

# paranoid shell
set -e -u

# check if configuration file is here
[ ! -s "./ari.conf" ] && fail "configuration file ari.conf not found in $(pwd) ."

# source configuration file
source ./ari.conf

# check configuration
message 'Checking configuration..'
## confirm
[[ "$confirm" = 'yes' || "$confirm" = 'no' ]] || config_fail 'confirm'
## dest_disk
### check if dest_disk is a valid block device
udevadm info --query=all --name="$dest_disk" | grep DEVTYPE=disk || config_fail 'dest_disk'
# partition_table
[[ "$partition_table" = 'gpt' || "$partition_table" = 'mbr' || "$partition_table" = 'auto' ]] || \
config_fail 'partition_table'
## bootloader
[[ "$bootloader" = 'grub' || "$bootloader" = 'syslinux' ]] || config_fail 'bootloader'
[[ "$bootloader" = 'grub' && "$partition_table" = 'gpt' ]] && config_fail \
'bootloader, grub is not supported for gpt partition tables'
## swap
if [ "$swap" = 'yes' ]; then
	### swap_size
	[ -z "$swap_size" ] && config_fail 'swap_size'
else
	[ "$swap" != 'no' ] && config_fail 'swap'
fi
## root_size
[ -z "$root_size" ] && config_fail 'root_size'
## fstpye
[ -z "$fstype" ] && config_fail 'fstype'
fstypes='btrfs ext2 ext3 ext4 f2fs jfs minix nilfs2 ntfs reiserfs vfat xfs'
fstype_correct=0
for fs in ${fstypes[@]}; do
        if [ "$fstype" = "$fs" ]; then
                fstype_correct=1
                break
        fi
done
[ "$fstype_correct" != 1 ] && config_fail 'fstype'
## encrypt_home
if [ "$encrypt_home" = 'yes' ]; then
	### cipher
	[ -z "$cipher" ] && config_fail 'cipher'
	### hash_alg
	[ -z "$hash_alg" ] && config_fail 'hash_alg'
	### key_size
	[ -z "$key_size" ] && config_fail 'key_size'
else
	[ "$encrypt_home" != 'no' ] && config_fail 'encrypt_home'
fi
## mirrorlist
[ -z "$mirrorlist" ] && config_fail 'mirrorlist'
## base_devel
[[ "$base_devel" = 'yes' || "$base_devel" = 'no' ]] || config_fail 'base_devel'
## locale_gen
[ -z "$locale_gen" ] && config_fail 'locale_gen'
## locale_conf
[ -z "$locale_conf" ] && config_fail 'locale_conf'
## keymap
[ -z "$keymap" ] && config_fail 'keymap'
## font
[ -z "$font" ] && config_fail 'font'
## timezone
[ -z "$timezone" ] && config_fail 'timezone'
## hardware_clock
[[ "$hardware_clock" = 'utc' || "$hardware_clock" = 'localtime' ]] || config_fail 'hardware_clock'
## hostname
[ -z "$hostname" ] && config_fail 'hostname'
## wired
[[ "$wired" = 'no' || "$wired" = 'dhcpcd' || "$wired" = 'netctl' || "$wired" = 'ifplugd' || "$wired" = 'static' ]] \
 || config_fail 'wired'
if [ "$wired" = 'static' ]; then
	### adress
	[ -z "$adress" ] && config_fail 'adress'
	### gateway
	[ -z "$gateway" ] && config_fail 'gateway'
	### dns
	[ -z "$dns" ] && config_fail 'dns'
fi
## set_root_password
[[ "$set_root_password" = 'yes' || "$set_root_password" = 'no' ]] || config_fail 'set_root_password'
## add_user
if [ "$add_user" = 'yes' ]; then
	### user_name
	[ -z "$user_name" ] && config_fail 'user_name'
else
	[ "$add_user" != 'no' ] && config_fail 'user_name'
fi
## xorg
[ -z "$xorg" ] && config_fail 'xorg'
## install desktop environment
if [ "$install_desktop_environment" = 'yes' ]; then
        ### desktop environment
        [ -z "$desktop_environment" ] && config_fail 'desktop_environment'
fi
## install display manager
if [ "$install_display_manager" = 'yes' ]; then
        ### display manager
        [ -z "$display_manager" ] && config_fail 'display_manager'
fi

## Graphical boot
[ -z "$graphical_boot" ] && config_fail 'graphical_boot'

## no config_fail beyond this point
message 'Configuration appears to be complete.'

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

# check internet connection
message 'Checking internet connection..'
if wget -q --tries=10 --timeout=5 http://mirrors.kernel.org -O /tmp/index.html; then
	[ -s /tmp/index.html ] || fail 'please configure your network connection.'
else
	fail 'please configure your network connection.'
fi

# ask for confirmation
if [ "$confirm" = 'yes' ]; then
	echo -e "\033[31m"
	echo 'archinstaller.sh:'
	echo 'WARNING:'
	echo '---------------------------------------'
	echo 'The destination drive will be formatted.'
	echo "All data on "$dest_disk" will be lost!"
	echo '---------------------------------------'
	echo -ne "\033[0m"
	answer='x'
	while [ "$answer" != 'yes' ]; do
		echo -n 'Continue (yes/no) '
		read answer
		if [ "$answer" = 'no' ]; then
			message 'Script cancelled!'
			exit 0
		fi
	done
fi

# prepare disk
message 'Preparing disk..'
umount "$dest_disk"* || :
wipefs -a "$dest_disk"
dd if=/dev/zero of="$dest_disk" count=100 bs=512; partprobe "$dest_disk"
sync; partprobe -s "$dest_disk"; sleep 5

# partitioning
message 'Creating partitions..'

if [ "$swap" = 'yes' ]; then
	swap_part_number=1
	root_part_number=2
	home_part_number=3
else
	root_part_number=1
	home_part_number=2
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
	echo -e "n\n \
                  p\n \
                   "$home_part_number"\n \
                   \n \
                  \n \
                 w" | fdisk "$dest_disk"

## GPT
else

	## swap partition
	if [ "$swap" = 'yes' ]; then
		#DO NOT INSERT WHITESPACES OR GDISK WILL FAIL
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
	echo -e "n\n\
"$home_part_number"\n\
\n\
\n\
8300\n\
w\n\
Y" | gdisk "$dest_disk"

fi

# encrypt home partition
if [ "$encrypt_home" = 'yes' ]; then
	message 'Setting up encryption..'
	modprobe dm_mod
	## erase partition with /dev/zero
	message 'Secure erasure of partition. This may take a while..'
	dd if=/dev/zero of="$dest_disk""$home_part_number" || :
	message 'You will be asked for the new encryption passphrase soon.'
	## map physical partition to LUKS
	cryptsetup -q -y -c "$cipher" -h "$hash_alg" -s "$key_size" luksFormat "$dest_disk""$home_part_number"
	## open encrypted volume
	message 'Please enter the encryption passphrase again to open the container.'
	cryptsetup open "$dest_disk""$home_part_number" home
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

## home
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

# mirrorlist
if [ "$mirrorlist" != 'keep' ]; then
	message 'Configuring mirrorlist..'
	echo "$mirrorlist" > /etc/pacman.d/mirrorlist
	wget -q --tries=10 --timeout=5 -O - \
	'https://www.archlinux.org/mirrorlist/?country=all&protocol=http&ip_version=4&use_mirror_status=on' | \
	sed 's/#Server/Server/' >> /etc/pacman.d/mirrorlist
fi

# pacstrap base
message 'Installing base system..'
if [ "$base_devel" = 'yes' ]; then
	pacstrap /mnt base base-devel
else
	pacstrap /mnt base
fi
message 'Successfully installed base system.'

# configure system
message 'Configuring system..'
## crypttab
[ "$encrypt_home" = 'yes' ] && echo "home "$dest_disk""$home_part_number" none luks,timeout=60s" \
				>> /mnt/etc/crypttab

## fstab
genfstab -L /mnt > /mnt/etc/fstab

## locale
echo "$locale_gen" >> /mnt/etc/locale.gen
echo "LANG="$locale_conf"" > /mnt/etc/locale.conf
arch-chroot /mnt /usr/bin/locale-gen

## console font and keymap
echo "KEYMAP="$keymap"" > /mnt/etc/vconsole.conf
echo "FONT="$font"" >> /mnt/etc/vconsole.conf

## timezone
ln -s /usr/share/zoneinfo/"$timezone" /mnt/etc/localtime

## hardware clock
if [ "$hardware_clock" = 'localtime' ]; then
	hwclock --systohc --localtime
else
	hwclock --systohc --utc
fi

## hostname
echo "$hostname" > /mnt/etc/hostname

## wired network service
if [ "$wired" != 'no' ]; then
	### network interface shall always be named eth0
	touch /mnt/etc/udev/rules.d/80-net-name-slot.rules
	if [ "$wired" = 'dhcpcd' ]; then
		arch-chroot /mnt /usr/bin/systemctl enable dhcpcd@eth0.service
	elif [ "$wired" = 'netctl' ]; then
		cp /mnt/etc/netctl/examples/ethernet-dhcp /mnt/etc/netctl/ethernet_dynamic
		arch-chroot /mnt /usr/bin/netctl enable ethernet_dynamic
	elif [ "$wired" = 'ifplugd' ]; then
		pacstrap /mnt ifplugd
		arch-chroot /mnt /usr/bin/systemctl enable netctl-ifplugd@eth0.service
	elif [ "$wired" = 'static' ]; then
		head -n 4 /mnt/etc/netctl/examples/ethernet-static > /mnt/etc/netctl/ethernet_static
		echo -e "Adress="$adress"\nGateway="$gateway"\nDNS="$dns"" >> /mnt/etc/netctl/ethernet_static
		arch-chroot /mnt /usr/bin/netctl enable ethernet_static
	fi
fi

##  mkinitcpio
arch-chroot /mnt mkinitcpio -p linux

# bootloader
if [[ "$partition_table" = 'gpt' || "$bootloader" = 'syslinux' ]]; then
	## install syslinux & gptfdisk packages
	message 'Installing bootloader..'
	pacstrap /mnt syslinux gptfdisk

	## write syslinux to disk
	message 'Writing bootloader to disk..'
	syslinux-install_update -i -a -m -c /mnt

	## configure syslinux
	message 'Configuring bootloader..'
	echo "PROMPT 1
TIMEOUT 50
DEFAULT arch

LABEL arch
        LINUX ../vmlinuz-linux
        APPEND root="$dest_disk""$root_part_number" rw
        INITRD ../initramfs-linux.img

LABEL archfallback
        LINUX ../vmlinuz-linux
        APPEND root="$dest_disk""$root_part_number" rw
        INITRD ../initramfs-linux-fallback.img" > /mnt/boot/syslinux/syslinux.cfg
else
	## install grub & os prober packages
	message 'Installing bootloader..'
	pacstrap /mnt grub os-prober

	## write grub to MBR
	message 'Writing bootloader to MBR..'
	arch-chroot /mnt /usr/bin/grub-install $dest_disk
	
	## configure grub
	message 'Configuring bootloader..'
	arch-chroot /mnt /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
fi

# root password
if [ "$set_root_password" = 'yes' ]; then
	message 'Setting password for root user..'
	arch-chroot /mnt /usr/bin/passwd root
fi

# add user
if [ "$add_user" = 'yes' ]; then
	message 'Adding new user..'
	arch-chroot /mnt /usr/bin/useradd -m -g users -G wheel -s /bin/bash "$user_name"
	## set user password
	message "Setting new password for "$user_name".."
	arch-chroot /mnt /usr/bin/passwd "$user_name"
fi
# install xorg
if [ "$xorg" = 'yes' ]; then
        pacstrap /mnt xorg-server xf86-video-vesa xorg-xinit
fi

# install desktop environment
if [ "$install_desktop_environment" = 'yes' ]; then
        if [ "$desktop_environment" = 'xfce4' ]; then
                pacstrap /mnt xfce4 xfce4-goodies
        elif [ "$desktop_environment" = 'gnome' ]; then
                pacstrap /mnt gnome gnome-extra
        elif [ "$desktop_environment" = 'kde' ]; then
                pacstrap /mnt kde
        elif [ "$desktop_environment" = 'cinnamon' ]; then
                pacstrap /mnt cinnamon
        elif [ "$desktop_environment" = 'lxde' ]; then
                pacstrap /mnt lxde
        elif [ "$desktop_environment" = 'enlightenment17' ]; then
                pacstrap /mnt enlightenment17
        fi
fi

# install display manager
if [ "$install_display_manager" = 'yes' ]; then
        if [ "$display_manager" = 'gdm' ]; then
                pacstrap /mnt gdm
                if [ "$graphical_boot" = 'yes' ]; then
                arch-chroot /mnt /usr/bin/systemctl enable gdm.service
                fi
        elif [ "$display_manager" = 'kdebase-workspace' ]; then
                pacstrap /mnt kdebase-workspace
                if [ "$graphical_boot" = 'yes' ]; then
                arch-chroot /mnt /usr/bin/systemctl enable kdm.service
                fi
        elif [ "$display_manager" = 'lxdm' ]; then
                pacstrap /mnt lxdm
		if [ "$graphical_boot" = 'yes' ]; then
                arch-chroot /mnt /usr/bin/systemctl enable lxdm.service
                fi
        elif [ "$display_manager" = 'xdm' ]; then
                pacstrap /mnt xorg-xdm
                if [ "$graphical_boot" = 'yes' ]; then
                arch-chroot /mnt /usr/bin/systemctl enable xdm.service
                fi
        fi

fi

# additional packages
if [ ! -z "$packages" ]; then
	message 'Installing additional packages..'
	pacstrap /mnt "$packages"
fi

# finish
message 'Finalizing..'

## unmount
cd /
umount /mnt/home
umount /mnt

## close encrypted volume
[ "$encrypt_home" = 'yes' ] && cryptsetup close home

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
echo
echo 'Tip: Be sure to remove the installation media,'
echo '     otherwise you will boot back into it.'
if [ "$encrypt_home" = 'yes' ]; then
	echo
	echo 'Tip: You have an encrypted home partition,'
	echo '     remember to enter your passphrase when'
	echo '     the system asks for it during boot.'
fi

exit 0
