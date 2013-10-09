#!/bin/bash
#
##################################################################
#title		: archinstaller.sh
#description	: Automated installation script for arch linux
#author		: Dennis Anfossi & teateawhy
#contact	: https://bbs.archlinux.org/profile.php?id=57887
#date		: 10-09
#version	: 0.3
#license	: GPLv2
#usage		: ./archinstaller.sh
##################################################################
#

# NO UEFI SUPPORT

## -------------
## CONFIGURATION

# confirm before running (yes/no)
confirm='yes'

# select drive to be formatted
dest_disk=''
# example:
# dest_disk='/dev/sda'

# GUID Partition Table (gpt/mbr)
# ( left empty,the script uses MBR if a drive is smaller than 1 TiB, GPT otherwise )
partition_table=''
# example:
# partition_table='gpt'

# swap (yes/no)
swap=''
# example:
# swap='no'

# partition sizes
# ( size in GiB )
swap_size=''
root_size=''
# example:
# root_size='25'

# filesystem for root and home partition
fstype=''
# example:
# fstype='ext4'

# encrypt home partition (yes/no)
# ( if set to yes, you will be prompted for a encryption passphrase during installation )
encrypt_home=''
# example: encrypt_home='yes'

# mirror
# ( set to 'keep' for using the current mirrorlist )
mirrorlist=''
# example:
# mirrorlist='Server = http://mirror.de.leaseweb.net/archlinux/$repo/os/$arch'

# install base-devel group (yes/no)
base_devel=''

# additional packages
# ( set to 'none' to skip )
packages=''
# example:
# packages='zsh grml-zsh-config vim'

# language
locale_gen='en_US.UTF-8 UTF-8'
locale_conf='LANG=en_US.UTF-8'

# keymap
keymap='KEYMAP=us'

# font
font='FONT=Lat2-Terminus16'

# timezone
# (only insert one slash in the middle)
timezone=''
# example: timezone='Europe/Berlin'

# hardware clock
# ( utc/localtime )
hardware_clock=''
# recommended: hardware_clock='utc'

# hostname
hostname=''
# example:
# hostname='myhostname'

# set root password (yes/no)
# ( if set to yes, you will be prompted for a root password at the end of the installation )
set_root_password=''
# example: set_root_password='no'

## END CONFIGURATION
## -----------------

start_time=$(date +%s)

# check root priviledges
[ "$EUID" != '0' ] && fail 'you must execute the script as the root user.'

# check arch linux
[ ! -e /etc/arch-release ] && fail 'you must execute the script on arch linux.'

echo  '======================================'
echo  '     Welcome to archinstaller.sh!     '
echo  '======================================'

# functions
config_fail() {
echo "\narchinstaller.sh:"
echo "Error, please check variable $1 !"
exit 1
}

fail() {
echo "\narchinstaller.sh:"
echo "Error, $1"
exit 1
}

message() {
echo "\narchinstaller.sh:"
echo "$1\n"
sleep 1
}

# paranoid shell
set -e -u

# check configuration
message 'Checking configuration..'

[ -z "$confirm" ] && config_fail 'confirm'
[ -z "$dest_disk" ] && config_fail 'dest_disk'
[ -z "$swap" ] && config_fail 'swap'
if [ "$swap" = 'yes' ]; then
	[ -z "$swap_size" ] && config_fail 'swap_size'
fi
[ -z "$root_size" ] && config_fail 'root_size'
[ -z "$fstype" ] && config_fail 'fstype'
[ -z "$encrypt_home" ] && config_fail 'encrypt_home'
[ -z "$mirrorlist" ] && config_fail 'mirrorlist'
[ -z "$base_devel" ] && config_fail 'base_devel'
[ -z "$packages" ] && config_fail 'packages'
[ -z "$locale_gen" ] && config_fail 'locale_gen'
[ -z "$locale_conf" ] && config_fail 'locale_conf'
[ -z "$keymap" ] && config_fail 'keymap'
[ -z "$font" ] && config_fail 'font'
[ -z "$timezone" ] && config_fail 'timezone'
[ -z "$hardware_clock" ] && config_fail 'hardware_clock'
[ -z "$hostname" ] && config_fail 'hostname'
[ -z "$set_root_password" ] && config_fail 'set_root_password'

# check if dest_disk is a valid block device
udevadm info --query=all --name=$dest_disk | grep DEVTYPE=disk || config_fail 'dest_disk'

# check disk size
if [ -z "$partition_table" ]; then
	dest_disk_size=$(lsblk -dnbo size "$dest_disk")
	# check if disk is larger than 1099511627776 bytes ( 1TiB )
	if echo ""$dest_disk_size" > 1099511627776" | bc ; then
        	partition_table='gpt'
	else
        	partition_table='mbr'
	fi
fi

message 'Configuration appears to be complete.'

# check internet connection
message 'Checking internet connection..'
wget -q --tries=10 --timeout=5 http://www.google.com -O /tmp/index.google
if [ ! -s /tmp/index.google ];then
	fail 'please configure your network connection.'
else
	message 'Success.'
fi

# initializing
REPLY='yes'
if [ "$confirm" != 'no' ]; then
	message
	echo 'WARNING:'
	echo '---------------------------------------'
	echo 'The destination drive will be formatted.'
	echo "All data on "$dest_disk" will be lost!"
	echo '---------------------------------------'
	read -p 'Continue (yes/no)? '
fi
if [ "$REPLY" = 'yes' ]; then
	message 'Preparing disk..'
	umount "$dest_disk"* || :
        wipefs -a $dest_disk
        dd if=/dev/zero of=$dest_disk count=100 bs=512; partprobe $dest_disk; sync; partprobe -s $dest_disk; sleep 5
else
	message 'Script cancelled!'
	exit 0
fi

# partitioning
message 'Creating partitions..'
if [ "$partition_table" = 'gpt' ]; then
	parted -s "$dest_disk" mklabel gpt
else
	parted -s "$dest_disk" mklabel msdos
fi

## swap partition
if [ "$swap" = 'yes' ]; then
	swap_part_number=1
	root_part_number=2
	home_part_number=3
else
	root_part_number=1
	home_part_number=2
fi

if [ "$swap" = 'yes' ]; then
	parted -s "$dest_disk" mkpart primary linux-swap 1024KiB "$swap_size"GiB
	## wait a moment
	sleep 1
fi

## root partition
parted -s "$dest_disk" mkpart primary ext4 "$swap_size"GiB "$root_size"GiB
## wait a moment
sleep 1

# home partition
parted -s "$dest_disk" mkpart primary ext4 "$root_size"GiB 100%
# encrypt home partition
if [ "$encrypt_home" = 'yes' ]; then
	message 'Setting up encryption..'
	modprobe dm_mod
	## secure erasure using /dev/zero
	message 'Secure erasure of partition..'
	dd if=/dev/zero of="$dest_disk""$home_part_number"
	message 'You will be asked for the new encryption passphrase soon.'
	## map physical partition to LUKS
	cryptsetup luksFormat -c aes-xts-plain64 -s 512 "$dest_disk""$home_part_number"
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
message 'Configuring mirrorlist..'
[ "$mirrorlist" != 'keep' ] && echo "$mirrorlist" > /etc/pacman.d/mirrorlist

# pacstrap base
message 'Installing base system..'
if [ "$base_devel" = 'yes' ]; then
	pacstrap /mnt base base-devel
else
	pacstrap /mnt base
fi
message 'Successfully installed base system.'

# additional packages
if [ "$packages" != 'none' ]; then
	message 'Installing additional packages'
	pacstrap /mnt "$packages"
fi

# configure system
message 'Configuring system..'
## crypttab
[ "$encrypt_home" = 'yes' ] && echo "home "$dest_disk""$home_part_number" none luks,timeout=60s" >> /mnt/etc/crypttab

## fstab
genfstab -L /mnt > /mnt/etc/fstab

## locale
echo "$locale_gen" >> /mnt/etc/locale.gen
echo "$locale_conf" > /mnt/etc/locale.conf
arch-chroot /mnt /usr/bin/locale-gen

## console font and keymap
echo "$keymap" > /mnt/etc/vconsole.conf
echo "$font" >> /mnt/etc/vconsole.conf

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

##  mkinitcpio
arch-chroot /mnt mkinitcpio -p linux

# bootloader
## install grub & os prober packages
message 'Installing bootloader..'
pacstrap /mnt grub os-prober

## write grub to MBR
message 'Writing bootloader to MBR..'
arch-chroot /mnt /usr/bin/grub-install $dest_disk
## configure grub
message 'Configuring bootloader..'
arch-chroot /mnt /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg

# root password
if [ "$set_root_password" = 'yes' ]; then
	message 'Setting password for root user..'
	passwd root
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

echo '---------------------------------------'
echo 'Installation completed!'
echo 'Eject any DVD or USB and reboot!'
echo '---------------------------------------'

message "Total install time: "$min" minutes."

exit 0
