# Archinstaller

Install and configure archlinux has never been easier!

You can try it first with a `virtualbox`

## Prerequisites

- A working internet connection
- Logged in as 'root'
- Packages: wget, gptfdisk, dosfstools, btrfs-progs, nilfs-utils

## How to get it:
### With git
- get the script: `git clone git://github.com/vitamins/archinstaller .`

### Without git:
- get the script: `wget --no-check-certificate https://github.com/vitamins/archinstaller/tarball/master -O - | tar xz`

## How to use:
- Edit configuration: `nano ./ari.conf`
- Make script executable: `chmod a+x ./archinstaller.0.4.6.sh`
- Run script `./archinstaller.0.4.6.sh`

## Archinstaller features:
- Support GPT/MBR  (GPT is used by default for HDD > 1TiB)
- Support UEFI system
- Allows you to choose between GRUB/syslinux
- Allows you to choose whether to activate a swap partition
- Allows you to choose how much space to allocate for swap/root partition
- Allows you to choose which filesystem to use
- Can encrypt home partition (Allows you to choose chyper)
- Allows you to choose a preferred mirror for the installation / can be update by the script
- Allows you to choose a preferred mirror for the installation
- Can install additional packages after the installation of base system
- Allows you to choose which keymap/font/locale/timezone to use
- Set hostname
- Set hardware clock
- Allows you to set a root password
- Allows you to add an additional user (non privileged)
- Allows you to configure network with dhcpcd/netctl/ifplugd
- Allows you to install Xorg (only vesa driver are included by default)
- Allows you to install a desktop environment (xfce4/gnome/kde/cinnamon/lxde/enlightenment17)
- Allows you to install a display manager
- Allows you to choose if boot the system in graphical mode
