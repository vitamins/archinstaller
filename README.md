# archinstaller
Automated installation script for arch linux written in bash.

## Prerequisites
- You are booted into an arch linux environment
- The internet connection has been set up
- The configuration found in ari.conf is valid
- The script is run as 'root' user

### packages
The required utilities can be installed with the following packages:
- arch-install-scripts version 12-1 (30 Nov 2013) or later
- For UEFI support: dosfstools
- For GPT support: gptfdisk
- For btrfs filesystems: btrfs-progs
- For nilfs filesystems: nilfs-utils

All utilities are included on archiso, which can be downloaded at https://www.archlinux.org/download/ .

## Download
### With git
- clone the repository: `git clone git://github.com/vitamins/archinstaller`

### Without git
- download the tarball: `curl -L https://github.com/vitamins/archinstaller/tarball/master | tar xz`

## Usage
- Edit the configuration file ari.conf: `nano ari.conf`
- Check if dest_disk refers to the correct drive with `lsblk`
- Run the script: `./archinstaller`

## Features
- Configured in a single file
- Can run completely automated
- Handles GPT and MBR partition tables
- Supported bootloaders: GRUB or gummiboot for UEFI, GRUB or syslinux for BIOS
- Configure basic system settings like language,timezone,keymap and hostname
- Optionally create separate partitions for swap and home
- Choose how much space to allocate for swap, root and home partition
- Select filesystems for root and home partition
- Supports encrypting the home partition with LUKS and dm-crypt
- Allows you to download packages from the preferred mirror
- Allows you to set passwords for root and standard user
- Allows you to create an additional user
- Allows you to configure the network with dhcpcd, netctl or ifplugd
- Allows you to install Xorg and a desktop environment
- Optionally install additional packages

## Other
### Partitioning
A simple partitioning tool that creates partitions as well as filesystems is included in the script. It is controlled by variables in the configuration file. If you want to create more advanced partition layouts, see paragraph "Manual Partitioning".
The partition sizes are set via variables "swap_size", "root_size", and "home_size". The size must consist of a number with the letter K for Kib, M for Mib, G for Gib or T for Tib appended.
For the partition table choose between MBR and GPT by variable "partition_table". For UEFI booting, only GPT is supported as partition table.
The order of the partitions is from first to last ESP, swap, root, and home.

#### Examples
A list of possible partition layouts that can be created by archinstaller. For simplification UEFI System partition and BIOS Boot partition have been left out of the examples. Default options are included in (brackets).

<pre>
0. example:
   Single root partition spanning the whole disk.
	---------- 0
	| /
	---------- End
   => options: swap='no'; home='no'; root_size='free';

1. example:
   Root partition of size X GiB, with free space left.
	---------- 0
	| /
	---------- X GiB
	| free
	---------- End
   => options: swap='no'; home='no'; root_size='XG';

2. example:
   Swap partition of size Y GiB, root partition spanning the remaining space.
	---------- 0
	| [swap]
	---------- Y GiB
	| /
	---------- End
  => options: swap='yes'; home='no'; swap_size='YG'; root_size='free';

3. example:
   Swap partition of size Y GiB, root partition of size X GiB.
	---------- 0
	| [swap]
	---------- Y GiB
	| /
	---------- Y+X GiB
	| free
	---------- End
  => options: swap='yes'; home='no'; swap_size='YG'; root_size='XG';

4. example:
   Root partition of size X GiB, home partition spanning the remaining space.
	---------- 0
	| /
	---------- X GiB
	| /home
	---------- End
  => options: swap='no'; (home='yes'); root_size='XG'; (home_size='free');

5. example:
   Root partition of size X GiB, home partition of size Z GiB.
	---------- 0
	| /
	---------- X GiB
	| /home
	---------- X+Z GiB
	| free
	---------- End
   => options: swap='no'; (home='yes'); root_size='XG'; home_size='ZG';

6. example:
   Swap partition of size Y GiB, root partition of size X GiB, home partition
   spanning the remaining space.
	---------- 0
	| [swap]
	---------- Y GiB
	| /
	---------- Y+X GiB
	| /home
	---------- End
   => options: swap='yes'; (home='yes'); swap_size='YG'; root_size='XG';
               (home_size='free');

7. example:
   Swap partition of size Y GiB, root partition of size X GiB, home partition
   of size Z GiB.
	---------- 0
	| [swap]
	---------- Y GiB
	| /
	---------- Y+X GiB
	| /home
	---------- Y+X+Z GiB
	| free
	---------- End
   => options: swap='yes'; (home='yes'); swap_size='YG'; root_size='XG';
               home_size='ZG';
</pre>

### Manual Partitioning
If you want to create the partitions and filesystems on your own, set "manual_part" to "yes". Then the following assumptions are made by the script:
- The partitions contain newly created filesystems.
- The root partition is mounted to /mnt.
- If using UEFI, the ESP is mounted to /mnt/boot.
- Any other seperate partition like /usr or /var is mounted below the /mnt/ directory.
- The variables "dest_disk" and "root_partition_number" point to the root partition. This information is required for installing the bootloader.
- The variable "partition_table" is set according to the partition table used for the root partition.
- The partitions are manually unmounted before rebooting.

Choose manual partitioning for more complex setups, such as lvm, RAID or btrfs subvolumes.

### mirrors
The selected mirror should be specified in the same format as listed on https://www.archlinux.org/mirrors/status/. Do not leave out the last slash.
To use the mirrorlist from the install host, set mirror to 'keep'. This setting overwrites the mirrorlist on the host and on the installed system.

### fstab, crypttab and mkinitcpio.conf
The fstab and crypttab files should always be checked after they have been generated. This is done by opening them in the editor, which is 'nano' by default. The editor can be changed with the "EDITOR" environment variable or in ari.conf. After mkinitcpio.conf has been edited, the initramfs is regenerated. If you want to skip this step, set the configuration option edit_conf='no'.

### Language
The language setting in "locale" is not verified by the script, but english (en_US) is generated as fallback setting.

### Kernel Modules
For kernel modules to load during boot, add the module's name to the "k_modules" array in the configuration file.
example:
`k_modules=( 'dm_mod' kvm coretemp )`
All needed modules are automatically loaded by udev, so you will rarely need to add something here. Only add modules that you know are missing.

### nectl-custom
Configure netctl profiles of your choice by setting network='netctl-custom'. For example, you can use this option to configure static ip addresses or wireless connections. The netctl profile has to be copied from /etc/netctl/examples to the working directory of the script and edited to reflect your setup. It is necessary to set netctl_profile='filename' to the profile's name in ari.conf, so the script can find it. The network interface names are set to eth0 and wlan0 by the script.

### Additional Packages
There are two possibilities to make the script install additional packages. You can add them to the packages array in the configuration file. Alternatively you can write the packages to `pkglist.txt`, one on each line. To generate a list of explicitly installed packages on an existing installation, use this command: `pacman -Qqent > pkglist.txt` You can also use both options at the same time, duplicated entries are eliminated by pacman.
Should one of the packages not be found in the repositories, e.g. if you have misspelled it, no packages are installed. Leave the "packages" array empty to skip this step.

### Passwords
Passwords are not stored in the script or configuration file. Instead you are beeing asked for a password by the underlying program like `passwd` during installation. When using encryption, think about a strong passphrase before starting the installation.

### Encryption
If you want to encrypt the home partition with LUKS and dm-crypt set "encrypt_home" to "yes". Details like cipher, hash algorithm and key size can be configured in ari.conf. The respective variables are "cipher","hash_alg" and "key_size". Run `cryptsetup benchmark` for a list of available options and their performance. The defaults are set to cipher='aes-xts-plain64', hash_alg='sha1' and key_size='256'.
