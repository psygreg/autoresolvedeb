#!/bin/bash
# fix issue with .0 releases
runver="20.0"
# dependency checker
depcheck () {

    local dependencies=()
    if [ "$ID_LIKE" == "suse" ]; then
        dependencies=(xorriso curl wget newt libxcb-dri2-0 libxcb-dri2-0-32bit libgthread-2_0-0 libgthread-2_0-0-32bit libapr1 libapr-util1 libQt5Gui5 libglib-2_0-0 libglib-2_0-0-32bit libgio-2_0-0 libgmodule-2_0-0 mesa-libGLU libxcrypt-compat)
    else
        dependencies=(xorriso qt5-qtgui curl wget newt libxcb libxcb.i686 glib2 glib2.i686 apr apr-util mesa-libGLU libxcrypt-compat)
    fi
    for dep in "${dependencies[@]}"; do
        if rpm -qi "$dep" 2>/dev/null 1>&2; then
            continue
        else
            if [ "$ID_LIKE" == "suse" ]; then
                sudo zypper in "$dep" -y
            else
                sudo dnf in "$dep" -y
            fi
        fi
    done

}

#create JSON, user agent and download Resolve
getresolve() {
  	local pkgname="$_upkgname"
  	local major_version="20.0"
  	local minor_version="0"
  	pkgver="${major_version}.${minor_version}"
  	local _product=""
  	local _referid=""
  	local _siteurl=""
  	local sha256sum=""
  	_archive_name=""
  	_archive_run_name=""

  	if [ "$pkgname" == "davinci-resolve" ]; then
    		_product="DaVinci Resolve"
    		_referid='dfd43085ef224766b06b579ce8a6d097'
    		_siteurl="https://www.blackmagicdesign.com/api/support/latest-stable-version/davinci-resolve/linux"
    		sha256sum='40bf13b7745b420ed9add11c545545c2ba2174429b6c8eafe8fceb94aa258766'
    		_archive_name="DaVinci_Resolve_${pkgver}_Linux"
    		_archive_run_name="DaVinci_Resolve_${runver}_Linux"
  	elif [ "$pkgname" == "davinci-resolve-studio" ]; then
    		_product="DaVinci Resolve Studio"
    		_referid='0978e9d6e191491da9f4e6eeeb722351'
    		_siteurl="https://www.blackmagicdesign.com/api/support/latest-stable-version/davinci-resolve-studio/linux"
    		sha256sum='5fb4614834c5a9f990afa977b7d5dcd2675c26529bc09a468e7cd287bbaf5097'
    		_archive_name="DaVinci_Resolve_Studio_${pkgver}_Linux"
    		_archive_run_name="DaVinci_Resolve_Studio_${runver}_Linux"
  	fi

  	local _useragent="User-Agent: Mozilla/5.0 (X11; Linux ${CARCH}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.75 Safari/537.36"
  	local _releaseinfo
  	_releaseinfo=$(curl -Ls "$_siteurl")

  	local _downloadId
  	_downloadId=$(printf "%s" "$_releaseinfo" | sed -n 's/.*"downloadId":"\([^"]*\).*/\1/p')
  	local _pkgver
  	_pkgver=$(printf "%s" "$_releaseinfo" | awk -F'[,:]' '{for(i=1;i<=NF;i++){if($i~/"major"/){print $(i+1)} if($i~/"minor"/){print $(i+1)} if($i~/"releaseNum"/){print $(i+1)}}}' | sed 'N;s/\n/./;N;s/\n/./')

  	if [[ $pkgver != "$_pkgver" ]]; then
    		echo "Version mismatch"
    		return 1
  	fi

  	local _reqjson
  	_reqjson="{\"firstname\": \"Arch\", \"lastname\": \"Linux\", \"email\": \"someone@archlinux.org\", \"phone\": \"202-555-0194\", \"country\": \"us\", \"street\": \"Bowery 146\", \"state\": \"New York\", \"city\": \"AUR\", \"product\": \"$_product\"}"
  	_reqjson=$(printf '%s' "$_reqjson" | sed 's/[[:space:]]\+/ /g')
  	_useragent=$(printf '%s' "$_useragent" | sed 's/[[:space:]]\+/ /g')
  	local _useragent_escaped="${_useragent// /\\ }"

  	_siteurl="https://www.blackmagicdesign.com/api/register/us/download/${_downloadId}"
  	local _srcurl
  	_srcurl=$(curl -s \
    		-H 'Host: www.blackmagicdesign.com' \
    		-H 'Accept: application/json, text/plain, */*' \
    		-H 'Origin: https://www.blackmagicdesign.com' \
    		-H "$_useragent" \
    		-H 'Content-Type: application/json;charset=UTF-8' \
    		-H "Referer: https://www.blackmagicdesign.com/support/download/${_referid}/Linux" \
    		-H 'Accept-Encoding: gzip, deflate, br' \
    		-H 'Accept-Language: en-US,en;q=0.9' \
    		-H 'Authority: www.blackmagicdesign.com' \
    		-H 'Cookie: _ga=GA1.2.1849503966.1518103294; _gid=GA1.2.953840595.1518103294' \
    		--data-ascii "$_reqjson" \
    		--compressed \
    		"$_siteurl")

  	curl -L -o "${_archive_name}.zip" "$_srcurl"
}

# runtime start
. /etc/os-release
depcheck

# menu
while :; do
	CHOICE=$(whiptail --title "AutoResolveRpm" --menu "Which version do you want to install?" 25 78 16 \
	"0" "Free" \
	"1" "Studio" \
	"2" "Cancel" 3>&1 1>&2 2>&3)
	
	exitstatus=$?
	if [ $exitstatus != 0 ]; then
    	# Exit the script if the user presses Esc
    	break
	fi

	case $CHOICE in
	0) 	_upkgname='davinci-resolve'
		cd $HOME
		mkdir resolverpm
		cd resolverpm
		getresolve
		unzip ${_archive_name}.zip
		chmod +x ${_archive_run_name}.run
		export SKIP_PACKAGE_CHECK=1
		./${_archive_run_name}.run
    cd /opt/resolve/libs
    sudo mkdir disabled
    sudo mv libglib* disabled
    sudo mv libgio* disabled
    sudo mv libgmodule* disabled
		cd $HOME
		rm -rf resolverpm
		exit 0 ;;
	1) 	_upkgname='davinci-resolve-studio'
		cd $HOME
		mkdir resolverpm
		cd resolverpm
		getresolve
		unzip ${_archive_name}.zip
		chmod +x ./${_archive_run_name}.run
		export SKIP_PACKAGE_CHECK=1
		./${_archive_run_name}.run
    cd /opt/resolve/libs
    sudo mkdir disabled
    sudo mv libglib* disabled
    sudo mv libgio* disabled
    sudo mv libgmodule* disabled
		cd $HOME
		rm -rf resolverpm
		exit 0 ;;
	2 | q) break ;;
	*) echo "Invalid Option" ;;
	esac
done
