# archinstaller.sh
This is an automated installation script for arch linux.
It overwrites the configured hard drive, so make sure to select the right device!

## Prerequisites
- You are booted into an arch linux environment
- An internet connection has been set up
- The configuration file ari.conf is found in the current working directory
- The script is run as 'root' user

### packages
The utitlities needed by the script can be installed with the following packages: arch-install-scripts, wget.
Based on your setup, other packages might be needed: gptfdisk for GPT support, dosfstools for UEFI support, btrfs-progs and nilfs-utils for the respective filesystems.
All utilities are included on the arch linux iso, which can be downloaded here: https://www.archlinux.org/download/

## How to get it:
### With git
- clone the repository: `git clone git://github.com/vitamins/archinstaller .`

### Without git:
- download the tarball: `wget --no-check-certificate https://github.com/vitamins/archinstaller/tarball/master -O - | tar xz`

## Usage
- Edit the configuration file ari.conf with your favorite editor: `nano ari.conf`
- Check if dest_disk refers to the correct drive with `lsblk`
- Make the script executable: `chmod +x ./archinstaller.sh`
- Run the script: `./archinstaller.0.4.6.sh`

## Features
- Simple configuration using a single file
- Linear script that is easily reviewed
- Can run completely automated
- Always downloads the latest packages
- Handles GPT and MBR partition tables
- Supports UEFI booting with GRUB or gummiboot
- Allows you to choose between GRUB and syslinux bootloader
- Configures basic system settings: language,timezone,keymap,font and hostname
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

## Passwords
Passwords are not stored in the script or configuration file. During installation, you are beeing asked for entering the passwords by the underlying program like `passwd`.
When using encryption, think about a strong passphrase before starting the installation.

## Partition sizes
The partition sizes are not checked by the script, if they are too big, the script will fail. The root partition requires at least 3 Gigabytes for the base system and a minimal set of applications.

## Help and Bugs
Please report bugs if you encounter them in the script.
A thread about it can be found on the arch linux forums:
https://bbs.archlinux.org/viewtopic.php?id=166112
