#!/bin/bash
# runtime start
source <(curl -s https://codeberg.org/psygreg/linuxtoys/raw/branch/master/p3/libs/linuxtoys.lib)
# menu
while true; do
	CHOICE=$(zenity --list --title "AutoResolvePkg" --text "Which version do you want to install?" \
		--column="Version" \
		"Free" \
		"Studio" \
		"Cancel" \
		--height=330 --width=300)

	if [ $? -ne 0 ]; then
		break
	fi

	case $CHOICE in
	"Free") if [ "$ID" != "cachyos" ]; then
			cd $HOME
			mkdir -p resolvepkg
			cd resolvepkg
        	wget https://codeberg.org/psygreg/linuxtoys/raw/branch/master/resources/davinci/free/PKGBUILD
        	wget https://codeberg.org/psygreg/linuxtoys/raw/branch/master/resources/davinci/free/davinci-resolve.install
			sudo_rq
        	makepkg -d
			sudo pacman --noconfirm -U davinci-resolve.pkg.tar.zst
			cd ..
			rm -rf resolvepkg
			zenity --info --text "DaVinci Resolve Free has been installed successfully." --width 300 --height 300
		else
			sudo_rq
			sudo pacman -S davinci-resolve
			zeninf "DaVinci Resolve Free has been installed successfully."
		fi
		exit 0 ;;
	"Studio") cd $HOME
		mkdir -p resolvepkg
		cd resolvepkg
        wget https://codeberg.org/psygreg/linuxtoys/raw/branch/master/resources/davinci/studio/PKGBUILD
        wget https://codeberg.org/psygreg/linuxtoys/raw/branch/master/resources/davinci/studio/davinci-resolve.install
		sudo_rq
        makepkg -d
		sudo pacman --noconfirm -U davinci-resolve-studio.pkg.tar.zst
		cd ..
		rm -rf resolvepkg
		zenity --info --text "DaVinci Resolve Studio has been installed successfully." --width 300 --height 300
		exit 0 ;;
	"Cancel") break ;;
	*) echo "Invalid Option" ;;
	esac
done
