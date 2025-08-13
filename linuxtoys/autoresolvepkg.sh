#!/bin/bash

# runtime start
# menu
while true; do
	CHOICE=$(zenity --list --title "AutoResolvePkg" --text "Which version do you want to install?" \
		--column="Version" \
		"0" "Free" \
		"1" "Studio" \
		"2" "Cancel" \
		--height=330 --width=300)

	if [ $? -ne 0 ]; then
		break
	fi

	case $CHOICE in
	0) 	cd $HOME
		mkdir resolvepkg
		cd resolvepkg
        wget https://raw.githubusercontent.com/psygreg/linuxtoys/refs/heads/main/src/resources/other/davinci/free/PKGBUILD
        wget davinci-resolve.install https://raw.githubusercontent.com/psygreg/linuxtoys/refs/heads/main/src/resources/other/davinci/free/davinci-resolve.install
        makepkg -si
		cd ..
		rm -rf resolvepkg
		zenity --info --text "DaVinci Resolve Free has been installed successfully." --width 300 --height 300
		exit 0 ;;
	1) 	cd $HOME
		mkdir resolvepkg
		cd resolvepkg
        wget https://raw.githubusercontent.com/psygreg/linuxtoys/refs/heads/main/src/resources/other/davinci/studio/PKGBUILD
        wget https://raw.githubusercontent.com/psygreg/linuxtoys/refs/heads/main/src/resources/other/davinci/studio/davinci-resolve.install
        makepkg -si
		cd ..
		rm -rf resolvepkg
		zenity --info --text "DaVinci Resolve Studio has been installed successfully." --width 300 --height 300
		exit 0 ;;
	2 | q) break ;;
	*) echo "Invalid Option" ;;
	esac
done
