#!/bin/bash

###############################################################
# title          : ari_gen.sh
# description    : Automated ari.conf generator.
# authors        : Dennis Anfossi & teateawhy
# contact        : bbs.archlinux.org/profile.php?id=57887
# date           : 29.10.2013
# version        : 0.5.2
# license        : GPLv2
# usage          : run ./ari_gen.sh.
###############################################################

# functions
## check for blank input
check_blank_input(){
if [ -z $input ]; then
dialog --title "Blank Input" \
--msgbox "\n You can't leave it blank!" 6 30
rm -f /tmp/inputbox.tmp.$$
exit 1
fi
}

# intro
dialog --title "Welcome" \
--msgbox "\n Welcome to automatic ari.conf generator!" 6 46

# Confirm
dialog --title "Confirm" \
--backtitle "./ari.conf generator" \
--yesno "Ask for confirmation ?\nDon't ask before initializing disk!" 6 40
if [ $? = 0 ]; then
	confirm=yes
	echo "confirm='yes'" > ./ari.conf
else
	confirm=no
	echo "confirm='no'" > ./ari.conf
fi

# dest disk
dialog --title "Select Destination" \
--backtitle "./ari.conf generator" \
--inputbox "Enter destination device here: (eg. /dev/sda)" 8 55 2> /tmp/inputbox.tmp.$$
retval=$?
input=`cat /tmp/inputbox.tmp.$$`
check_blank_input
rm -f /tmp/inputbox.tmp.$$
case $retval in
	0)
		echo "dest_disk='"$input"'">> ./ari.conf;;
	*)
	# exit
	dialog --title "Error" \
	--msgbox "\n Setup cannot continue without a valid block device!" 6 58
	exit 1
esac

#UEFI
dialog --title "UEFI" \
--backtitle "./ari.conf generator" \
--yesno "Enable UEFI support?" 6 24
if [ $? = 0 ]; then
	uefi=yes
	echo "uefi='yes'" >> ./ari.conf
else
	uefi=no
	echo "uefi='no'" >> ./ari.conf
fi

#Partition Table
part_table=$(dialog --radiolist "Select Partition Table" 10 50 5 \
        "mbr"  "MBR" off \
        "gpt"  "GPT" off \
	"auto" "Automatic mode" on 2>&1 >/dev/tty)
if [ $? = 0 ]; then
	echo "partition_table='"$part_table"'" >> ./ari.conf
else
	# exit
	dialog --title "Error" \
	--msgbox "\n Setup cannot continue without a valid partition table!" 6 60
	exit 1
fi

#bootloader
## UEFI (gummiboot/grub)
if [ $uefi = 'yes' ]; then
	bootloader=$(dialog --radiolist "Select Bootloader" 10 50 5 \
	"gummiboot"  "Gummiboot" on \
	"grub" "GRUB" off 2>&1 >/dev/tty)
	echo "bootloader='"$bootloader"'" >> ./ari.conf
else
	## BIOS & MBR (syslinux/grub)
	if [ $part_table = "mbr" ]; then
		bootloader=$(dialog --radiolist "Select Bootloader" 10 50 5 \
		"syslinux"  "syslinux" on \
		"grub" "GRUB" off 2>&1 >/dev/tty)
		if [ $? = 0 ]; then
			echo "bootloader='"$bootloader"'" >> ./ari.conf
		else
			# exit
			dialog --title "Error" \
			--msgbox "\n Setup cannot continue without a valid bootloader!" 6 58
			exit 1
		fi
	## BIOS & GPT (syslinux)
	elif [ $part_table = "gpt" ]; then
		bootloader=$(dialog --radiolist "Select Bootloader" 10 50 5 \
		"syslinux" "syslinux" on 2>&1 >/dev/tty)
		if [ $? = 0 ]; then
			echo "bootloader='"$bootloader"'" >> ./ari.conf
		else
			# exit
			dialog --title "Error" \
			--msgbox "\n Setup cannot continue without a valid bootloader!" 6 58
			exit 1
		fi	
	
	else
		## BIOS & Auto
		if [ $part_table = "auto" ]; then
                        bootloader=$(dialog --radiolist "Select Bootloader" 10 50 5 \
                        "syslinux" "syslinux" on 2>&1 >/dev/tty)
                        if [ $? = 0 ]; then
                                echo "bootloader='"$bootloader"'" >> ./ari.conf
                        else
                                # exit
                                dialog --title "Error" \
                                --msgbox "\n Setup cannot continue without a valid bootloader!" 6 58
                                exit 1
                        fi
                fi
	fi
fi

# swap
dialog --title "Swap" \
--backtitle "./ari.conf generator" \
--yesno "Create a swap partition?" 6 28
if [ $? = 0 ]; then
	swap=yes
	echo "swap='yes'" >> ./ari.conf
	# swap size
	dialog --title "swap size" \
	--backtitle "./ari.conf generator" \
	--inputbox " * Add G for a size of GiB, and M for MiB. \n
	* The home partition spans the remaing space.\n
	* Partition sizes are not checked, please\n
  	make sure the drive is big enough. (eg. 500M)" 0 0 2> /tmp/inputbox.tmp.$$
	retval=$?
	input=`cat /tmp/inputbox.tmp.$$`
	check_blank_input
	rm -f /tmp/inputbox.tmp.$$
	case $retval in
		0)
		echo "swap_size='"$input"'">> ./ari.conf;;
		*)
		# exit
		dialog --title "Error" \
		--msgbox "\n You need to set a swap size!" 6 35
		exit 1
	esac
else
	swap=no
	echo "swap='no'" >> ./ari.conf
fi

# root size
 dialog --title "root size" \
--backtitle "./ari.conf generator" \
--inputbox "* Add G for a size of GiB, and M for MiB. \n
* The home partition spans the remaing space.\n
* Partition sizes are not checked, please \n
  make sure the drive is big enough. (eg. 25G)" 0 0 2> /tmp/inputbox.tmp.$$
retval=$?
input=`cat /tmp/inputbox.tmp.$$`
rm -f /tmp/inputbox.tmp.$$
case $retval in
	0)
	echo "root_size='"$input"'">> ./ari.conf;;
*)
	# exit
	dialog --title "Error" \
	--msgbox "\n You need to set a root size!" 6 48
	exit 1
esac

# filesystem
fstype=$(dialog --radiolist "Select filesystem type" 16 50 10 \
"btrfs"  "btrfs" off \
"ext2"  "ext2" off \
"ext3"  "ext3" off \
"ext4"  "ext4" on \
"jfs"  "jfs" off \
"nilfs2"  "nilfs2" off \
"reiserfs"  "reiserfs" off \
"xfs" "xfs" off 2>&1 >/dev/tty)
if [ $? = 0 ]; then
	echo "fstype='"$fstype"'" >> ./ari.conf
else
	# exit
	dialog --title "Error" \
	--msgbox "\n You need to select a filesystem!" 6 48
	exit 1
fi

# encrypt home partition (yes/no)
dialog --title "Encypt Home Partition" \
--backtitle "./ari.conf generator" \
--yesno "Encrypt home partition?" 6 28
if [ $? = 0 ]; then
	encrypt_home=yes
	echo "encrypt_home='yes'" >> ./ari.conf
	## cipher
	dialog --title "Select cipher" \
	--backtitle "./ari.conf generator" \
	--inputbox "Select cipher: (eg. aes-xts-plain64)" 0 40 2> /tmp/inputbox.tmp.$$
	retval=$?
	input=`cat /tmp/inputbox.tmp.$$`
	check_blank_input
	rm -f /tmp/inputbox.tmp.$$
	case $retval in
	0)
		echo "cipher='"$input"'">> ./ari.conf;;
	*)
		# exit
		dialog --title "Error" \
		--msgbox "\n You need to select a cipher!" 6 55
		exit 1
	esac
	## hash alg
	dialog --title "Hash Algorithm" \
	--backtitle "./ari.conf generator" \
	--inputbox "Select hash algorithm: (eg. sha512)" 0 50 2> /tmp/inputbox.tmp.$$
	retval=$?
	input=`cat /tmp/inputbox.tmp.$$`
	check_blank_input
	rm -f /tmp/inputbox.tmp.$$
	case $retval in
	0)
		echo "hash_alg='"$input"'">> ./ari.conf;;
	*)
		# exit
		dialog --title "Error" \
		--msgbox "\n You need to select an algorithm!" 6 55
		exit 1
	esac
	## key_size
	dialog --title "Select key size" \
	--backtitle "./ari.conf generator" \
	--inputbox "Select key size: (eg. 512)" 0 40 2> /tmp/inputbox.tmp.$$
	retval=$?
	input=`cat /tmp/inputbox.tmp.$$`
	check_blank_input
	rm -f /tmp/inputbox.tmp.$$
	case $retval in
	0)
		echo "key_size='"$input"'">> ./ari.conf;;
	*)
		# exit
		dialog --title "Error" \
		--msgbox "\n You need to select a key size!" 6 55
		exit 1
	esac
else
	encrypt_home=no
	echo "encrypt_home='no'" >> ./ari.conf
fi

# mirror
dialog --title "Select Mirror" \
--backtitle "./ari.conf generator" \
--inputbox "Select mirror \n
To use the mirrorlist on the install host, set 'keep'." 0 0 2> /tmp/inputbox.tmp.$$
retval=$?
input=`cat /tmp/inputbox.tmp.$$`
check_blank_input
rm -f /tmp/inputbox.tmp.$$
case $retval in
	0)
	echo "mirror='"$input"'">> ./ari.conf;;
*)
	# exit
	dialog --title "Error" \
	--msgbox "\n You need to set a mirror or use 'keep' to use host mirror!" 6 60
	exit 1
esac

#base_devel
dialog --title "base-devel" \
--backtitle "./ari.conf generator" \
--yesno "Install base devel group?" 6 30
if [ $? = 0 ]; then
	base_devel=yes
	echo "base_devel='yes'" >> ./ari.conf
else
	base_devel=no
	echo "base_devel='no'" >> ./ari.conf
fi

# additional packages
dialog --title "Additional Packages" \
--backtitle "./ari.conf generator" \
--inputbox "Install additional packages ? (separate with space)\n
To skip this step leave it blank." 10 55 2> /tmp/inputbox.tmp.$$
retval=$?
input=`cat /tmp/inputbox.tmp.$$`
rm -f /tmp/inputbox.tmp.$$
case $retval in
0)
	echo "packages=("$input")">> ./ari.conf;;
*)
	echo "packages=()" >> ./ari.conf;;
esac

# Language (locale_gen)
dialog --title "locale_gen" \
--backtitle "./ari.conf generator" \
--inputbox "Enter language here: (eg. en_US.UTF-8 UTF-8)" 0 50 2> /tmp/inputbox.tmp.$$
retval=$?
input=`cat /tmp/inputbox.tmp.$$`
check_blank_input
rm -f /tmp/inputbox.tmp.$$
case $retval in
0)
	echo "locale_gen='"$input"'">> ./ari.conf;;
*)
	# exit
	dialog --title "Error" \
	--msgbox "\n You need to set a language for locale_gen" 6 55
	exit 1
esac

# Language (locale_conf)
dialog --title "locale_conf" \
--backtitle "./ari.conf generator" \
--inputbox "Enter locale here: (eg. en_US.UTF-8)" 0 40 2> /tmp/inputbox.tmp.$$
retval=$?
input=`cat /tmp/inputbox.tmp.$$`
check_blank_input
rm -f /tmp/inputbox.tmp.$$
case $retval in
0)
	echo "locale_conf='"$input"'">> ./ari.conf;;
*)
	# exit
	dialog --title "Error" \
	--msgbox "\n You need to set a language for locale_conf!" 6 55
	exit 1
esac

# Keymap
dialog --title "Select Keymap" \
--backtitle "./ari.conf generator" \
--inputbox "Enter keymap here: (eg. de-latin1)" 0 40 2> /tmp/inputbox.tmp.$$
retval=$?
input=`cat /tmp/inputbox.tmp.$$`
check_blank_input
rm -f /tmp/inputbox.tmp.$$
case $retval in
0)
	echo "keymap='"$input"'">> ./ari.conf;;
*)
	# exit
	dialog --title "Error" \
	--msgbox "\n You need to set a keymap!" 6 55
	exit 1
esac

# font
dialog --title "Select Font" \
--backtitle "./ari.conf generator" \
--inputbox "Enter font here: (eg. Lat2-Terminus16)" 0 45 2> /tmp/inputbox.tmp.$$
retval=$?
input=`cat /tmp/inputbox.tmp.$$`
check_blank_input
rm -f /tmp/inputbox.tmp.$$
case $retval in
0)
	echo "font='"$input"'">> ./ari.conf;;
*)
	# exit
	dialog --title "Error" \
	--msgbox "\n You need to set a font type" 6 60
	exit 1
esac

# timezone
dialog --title "Select Timezone" \
--backtitle "./ari.conf generator" \
--inputbox "Enter timezone: (eg. Europe/Berlin)" 0 40 2> /tmp/inputbox.tmp.$$
retval=$?
input=`cat /tmp/inputbox.tmp.$$`
check_blank_input
rm -f /tmp/inputbox.tmp.$$
case $retval in
0)
	echo "timezone='"$input"'">> ./ari.conf;;
*)
	# exit
	dialog --title "Error" \
	--msgbox "\n You need to set a timezone" 6 60
	exit 1
esac

# hardware clock
hardware_clock=$(dialog --radiolist "Set hardware clock" 10 41 5 \
"utc"  "utc" On \
"localtime" "localtime" off 2>&1 >/dev/tty)
if [ $? = 0 ]; then
	echo "hardware_clock='"$hardware_clock"'" >> ./ari.conf
else
	# exit
	dialog --title "Error" \
	--msgbox "\n You need to set hardware clock!" 6 60
	exit 1
fi

# hostname
dialog --title "Select Hostname" \
--backtitle "./ari.conf generator" \
--inputbox "Select hostname: (eg. myhost)" 0 40 2> /tmp/inputbox.tmp.$$
retval=$?
input=`cat /tmp/inputbox.tmp.$$`
check_blank_input
rm -f /tmp/inputbox.tmp.$$
case $retval in
0)
	echo "hostname='"$input"'">> ./ari.conf;;
*)
	# exit
	dialog --title "Error" \
	--msgbox "\n You need to set a hostname!" 6 55
	exit 1
esac

# set root password
dialog --title "passowrd" \
--backtitle "./ari.conf generator" \
--yesno "Set a root password?" 6 25
if [ $? = 0 ]; then
	set_root_password=yes
	echo "set_root_password='yes'" >> ./ari.conf
else
	set_root_password=no
	echo "set_root_password='no'" >> ./ari.conf
fi

# add user
dialog --title "add user" \
--backtitle "./ari.conf generator" \
--yesno "Add user ?" 6 20
if [ $? = 0 ]; then
  	add_user=yes
  	echo "add_user='yes'" >> ./ari.conf
	# username
	dialog --title "Select username" \
	--backtitle "./ari.conf generator" \
	--inputbox "Select username: (eg. myuser)" 0 40 2> /tmp/inputbox.tmp.$$
	retval=$?
	input=`cat /tmp/inputbox.tmp.$$`
	check_blank_input
	rm -f /tmp/inputbox.tmp.$$
	case $retval in
	0)
		echo "user_name='"$input"'">> ./ari.conf;;
	*)
		# exit
		dialog --title "Error" \
		--msgbox "\n You need to set an username!" 6 55
		exit 1
	esac
else
	add_user=no
	echo "add_user='no'" >> ./ari.conf
fi

# network connection
network=$(dialog --radiolist "Configuriung network:" 13 40 6 \
"no"  "no" off \
"dhcpcd"  "dhcpcd" on \
"netctl"  "netctl" off \
"netctl-dhcp"  "netctl-dhcp" off \
"netctl-custom"  "netctl-custom" off \
"ifplugd" "ifplugd" off 2>&1 >/dev/tty)
if [ $? = 0 ]; then
	echo "network='"$network"'" >> ./ari.conf
else
	# exit
	dialog --title "Error" \
	--msgbox "\n You need to choose an option!" 6 55
	exit 1
fi

# xorg
dialog --title "Xorg" \
--backtitle "./ari.conf generator" \
--yesno "Do you want to install xorg ?" 6 35
if [ $? = 0 ]; then
	xorg=yes
	echo "xorg='yes'" >> ./ari.conf
	# install desktop environment
	dialog --title "Desktop Environment" \
	--backtitle "./ari.conf generator" \
	--yesno "Do you want to install a desktop environment ?" 6 30
	if [ $? = 0 ]; then
		install_desktop_environment=yes
		echo "install_desktop_environment='yes'" >> ./ari.conf
		# desktop environment
		desktop_environment=$(dialog --radiolist "Select Desktop Environment" 15 45 6 \
		"xfce4"  "xfce4" on \
		"gnome"  "gnome" off \
		"kde"  "kde" off \
		"cinnamon"  "cinnamon" off \
		"lxde"  "lxde" off \
		"enlightenment17" "enlightenment17" off 2>&1 >/dev/tty)
		if [ $? = 0 ]; then
			echo "desktop_environment='"$desktop_environment"'" >> ./ari.conf
		else
			# exit
			dialog --title "Error" \
			--msgbox "\n You need to select a desktop environment!" 6 60
			exit 1
		fi
	else
		install_desktop_environment=no
		echo "install_desktop_environment='no'" >> ./ari.conf
	fi
	# install display manager
	dialog --title "Install a display manager" \
	--backtitle "./ari.conf generator" \
	--yesno "Dow you want to install a display manager?" 6 30
	if [ $? = 0 ]; then
		install_display_manager=yes
		echo "install_display_manager='yes'" >> ./ari.conf
		# display manager
		display_manager=$(dialog --radiolist "Select a display manager" 15 30 6 \
		"gdm"  "gdm" off \
		"kdm"  "kdm" off \
		"lxdm"  "lxdm" on \
		"xdm" "xdm" off 2>&1 >/dev/tty)
		if [ $? = 0 ]; then
			echo "display_manager='"$display_manager"'" >> ./ari.conf
		else
			# exit
			dialog --title "Error" \
			--msgbox "\n You need to select a display manager!" 6 55
			exit 1
		fi	
		# Graphical login
		dialog --title "Graphical Login" \
		--backtitle "./ari.conf generator" \
		--yesno "Dow you want to enable graphical login?" 6 30
		if [ $? = 0 ]; then
			graphical_login=yes
			echo "graphical_login='yes'" >> ./ari.conf
		else
			graphical_login=no
			echo "graphical_login='no'" >> ./ari.conf
		fi
	else
		install_display_manager=no
		echo "install_display_manager='no'" >> ./ari.conf
	fi
else
  xorg=no
  echo "xorg='no'" >> ./ari.conf
fi

# report
dialog --title "report" --backtitle "ari.conf generator" --textbox ari.conf 35 50

# exit
dialog --title "Completed" \
--msgbox "\n Setup was complete. Now you can run ./archinstaller.sh" 6 65 
exit 0
