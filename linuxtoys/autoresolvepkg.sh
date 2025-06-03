#!/bin/bash

# runtime start
# menu
while :; do
	CHOICE=$(whiptail --title "AutoResolvePkg" --menu "Which version do you want to install?" 25 78 16 \
	"0" "Free" \
	"1" "Studio" \
	"2" "Cancel" 3>&1 1>&2 2>&3)
	
	exitstatus=$?
	if [ $exitstatus != 0 ]; then
    	# Exit the script if the user presses Esc
    	break
	fi

	case $CHOICE in
	0) 	cd $HOME
		mkdir resolvepkg
		cd resolvepkg
        wget https://raw.githubusercontent.com/psygreg/linuxtoys/refs/heads/main/linuxtoys-aur/resources/davinci/free/PKGBUILD
        wget davinci-resolve.install https://raw.githubusercontent.com/psygreg/linuxtoys/refs/heads/main/linuxtoys-aur/resources/davinci/free/davinci-resolve.install
        makepkg -si
		cd ..
		rm -rf resolvepkg
		exit 0 ;;
	1) 	cd $HOME
		mkdir resolvepkg
		cd resolvepkg
        wget https://raw.githubusercontent.com/psygreg/linuxtoys/refs/heads/main/linuxtoys-aur/resources/davinci/studio/PKGBUILD
        wget https://raw.githubusercontent.com/psygreg/linuxtoys/refs/heads/main/linuxtoys-aur/resources/davinci/studio/davinci-resolve.install
        makepkg -si
		cd ..
		rm -rf resolvepkg
		exit 0 ;;
	2 | q) break ;;
	*) echo "Invalid Option" ;;
	esac
done
