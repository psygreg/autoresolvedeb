#!/bin/bash

# dependency checker
depcheck () {

    local dependencies=(fakeroot xorriso libqt5gui5 curl wget whiptail libxcb-dri2-0:i386 libxcb-dri2-0 libcrypt1 libglu1-mesa libglib2.0-0t64 libglib2.0-0t64:i386 libapr1 libaprutil1)
    for dep in "${dependencies[@]}"; do
        if dpkg -s "$dep" 2>/dev/null 1>&2; then
            continue
        else
            sudo apt install -y "$dep"
        fi
    done

}

#create JSON, user agent and download Resolve
getresolve() {
  	local pkgname="$_upkgname"
  	local major_version="20.1"
  	local minor_version="0"
  	pkgver="${major_version}"
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
    		_archive_run_name="DaVinci_Resolve_${pkgver}_Linux"
  	elif [ "$pkgname" == "davinci-resolve-studio" ]; then
    		_product="DaVinci Resolve Studio"
    		_referid='0978e9d6e191491da9f4e6eeeb722351'
    		_siteurl="https://www.blackmagicdesign.com/api/support/latest-stable-version/davinci-resolve-studio/linux"
    		sha256sum='5fb4614834c5a9f990afa977b7d5dcd2675c26529bc09a468e7cd287bbaf5097'
    		_archive_name="DaVinci_Resolve_Studio_${pkgver}_Linux"
    		_archive_run_name="DaVinci_Resolve_Studio_${pkgver}_Linux"
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

# get makeresolvedeb
makeresolvedeb () {
	mrdver='1.8.2'
	curl --output makeresolvedeb_${mrdver}_multi.sh.tar.gz https://www.danieltufvesson.com/download/?file=makeresolvedeb/makeresolvedeb_${mrdver}_multi.sh.tar.gz;
	tar zxvf makeresolvedeb_${mrdver}_multi.sh.tar.gz;
}

# runtime start
depcheck
# menu
while :; do
	CHOICE=$(whiptail --title "AutoResolveDeb" --menu "Which version do you want to install?" 25 78 16 \
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
		mkdir resolvedeb
		cd resolvedeb
		getresolve 
		makeresolvedeb
		unzip ${_archive_name}.zip
		./makeresolvedeb_${mrdver}_multi.sh ${_archive_run_name}.run 
		sudo dpkg -i davinci-resolve_${pkgver}-mrd${mrdver}_amd64.deb
		whiptail --title "AutoResolveDeb" --msgbox "Installation succesful." 8 78
		cd ..
		rm -rf resolvedeb
		exit 0 ;;
	1) 	_upkgname='davinci-resolve-studio'
		cd $HOME
		mkdir resolvedeb
		cd resolvedeb
		getresolve 
		makeresolvedeb
		unzip ${_archive_name}.zip
		./makeresolvedeb_${mrdver}_multi.sh ${_archive_run_name}.run 
		sudo dpkg -i davinci-resolve-studio_${pkgver}-mrd${mrdver}_amd64.deb
		whiptail --title "AutoResolveDeb" --msgbox "Installation succesful." 8 78
		cd ..
		rm -rf resolvedeb
		exit 0 ;;
	2 | q) break ;;
	*) echo "Invalid Option" ;;
	esac
done

