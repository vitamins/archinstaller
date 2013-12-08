# archinstaller.sh
This is an automated installation script for arch linux.

## Prerequisites
- You are booted into an arch linux environment
- The internet connection has been set up
- The configuration found in ari.conf is valid
- The script is run as 'root' user

### packages
The utitlities needed by the script can be installed with the following packages:
- arch-install-scripts version 12-1 (30 Nov 2013) or later
- wget
- For UEFI support: dosfstools
- For GPT support: gptfdisk
- For btrfs filesystems: btrfs-progs
- For nilfs filesystems: nilfs-utils

All utilities are included on archiso, which can be downloaded at https://www.archlinux.org/download/ .

## Download
### With git
- clone the repository: `git clone git://github.com/vitamins/archinstaller`

### Without git
- download the tarball: `wget https://github.com/vitamins/archinstaller/tarball/master -O - | tar xz`

## Usage
- Open the configuration file ari.conf with your editor: `nano ari.conf`
- Check if dest_disk refers to the correct drive with `lsblk`
- Make the script executable: `chmod +x ./archinstaller.sh`
- Run the script: `./archinstaller.sh`

## Features
- Simple configuration using a single file
- Can run completely automated
- Always downloads the latest packages
- Handles GPT and MBR partition tables
- Supports UEFI booting with GRUB or gummiboot
- Allows you to choose between GRUB and syslinux bootloader
- Configure basic system settings: language,timezone,keymap,font and hostname
- Optionally create and activate a swap partition
- Choose how much space to allocate for swap and root partition
- A home partition is created on the remaining space
- Decide which filesystems to use for root and home partition
- Supports encrypting the home partition using LUKS and dm-crypt
- Allows you to download packages from the preferred mirror
- Can install additional packages
- Allows you to set a root password
- Allows you to add an additional non-root user
- Allows you to configure the network with dhcpcd, netctl or ifplugd
- Allows you to install Xorg
- Officially supported desktop environments: xfce4,gnome,kde,cinnamon,lxde,enlightenment17
- Allows you to install a display manager

## Other
### Partitioning
At the beginning, the partition layout is cleared, and a new partition table is created on the storage device.
Partition sizes are not checked by the script, if they are too big, the script will fail. For accommodating the base system and a minimal set of applications, the root partition should be at least 3 Gigabytes in size. By default, the EFI System Partition "ESP" has a size of 512M, to override this set the variable "esp_size". A seperate home partition is created by default, but this can be avoided by setting home='no'. The home partition takes up remaining space on the storage device, unless you set "home_size". The order of the partitions is from first to last ESP, swap, root, and home.

### Manual Partitioning
If you want to create the partitions and filesystems on your own, set "manual_part" to "yes". Then the following assumptions are made by the script:
- The partitions contain newly created filesystems.
- The root partition is mounted to /mnt.
- If using UEFI, the ESP is mounted to /mnt/boot.
- Any other seperate partition like /usr or /var is mounted below the /mnt/ directory.
- The variables "dest_disk" and "root_partition_number" point to the root partition. This information is required for installing the bootloader.
- The variable "partition_table" is set according to the partition table used for the root partition.
- The partitions are manually unmounted before rebooting.

Manual partitioning allows you to use this script with more complex setups, such as lvm or RAID. In that case, you have to configure the necessary settings on your own. For example for lvm, it is necessary to add the lvm hook to mkinitcpio.conf .

### fstab, crypttab and mkinitcpio.conf
The fstab and crypttab files should always be checked after they have been generated. This is done by opening them in the editor, which is 'nano' by default. The editor can be changed with the "EDITOR" environment variable or in ari.conf.
After the configuration file mkinitcpio.conf has been opened in the editor, the initramfs is regenerated.
If you want to skip this step, set the configuration option check_conf='no'.

### Language
The language settings in "locale_gen" and "locale_conf" are not checked by the script. In case you make an configuration error here, locale settings fall back to en_US and the script continues.

### Kernel Modules
For kernel modules to load during boot, add the module's name to the "k_modules" array in the configuration file.
example:
`k_modules=( 'dm_mod' kvm coretemp )`
All needed modules are automatically loaded by udev, so you will rarely need to add something here. Only add modules that you know are missing.

### nectl-custom
It is possible to configure netctl profiles of your choice by setting network='netctl-custom'. For example, you can use this option to configure static ip addresses or wireless connections. The netctl profile has to be copied from /etc/netctl/examples to the working directory of the script and edited to reflect your setup. It is necessary to set netctl_profile='filename' to the profile's name in ari.conf, so the script can find it. The network interface names are set to eth0 and wlan0 by the script.

### Additional Packages
There are two possibilities to make the script install additional packages. You can add them to the packages array in the configuration file. Alternatively you can write the packages to `pkglist.txt`, one on each line. To generate a list of explicitly installed packages on an existing installation, use this command: `pacman -Qqent > pkglist.txt` You can also use both options at the same time, duplicate entries are eliminated by pacman.
All of the packages must be part of the core,extra or community repositories. It is not possible to install packages from the multilib repository by the script. Should one of the packages not be found in the repositories, e.g. if you have misspelled it, no packages are installed.

### Passwords
Passwords are not stored in the script or configuration file. Instead you are beeing asked for a password by the underlying program like `passwd` during installation.
When using encryption, think about a strong passphrase before starting the installation.

### Encryption
If you want to encrypt the home partition with LUKS and dm-crypt set "encrypt_home" to "yes". Details like cipher, hash algorithm and key size can be configured in ari.conf. The respective variables are "cipher","hash_alg" and "key_size". Run `cryptsetup benchmark` for a list of available options and their performance. The defaults are set to cipher='aes-xts-plain64', hash_alg='sha1' and key_size='256'.

## Help and Bugs
Please report bugs should you encounter them in the script.
A thread about it can be found on the arch linux forums:
https://bbs.archlinux.org/viewtopic.php?id=166112
