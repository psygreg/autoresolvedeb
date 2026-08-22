#!/bin/bash
# runtime start
source "$SCRIPT_DIR/libs/linuxtoys.lib"
# menu
depcheck () {
	pkg_install fakeroot debugedit
	if is_amd; then
		call_script rocm
	elif is_intel; then
		call_script icr
	elif is_nvidia && ! nvidia-smi; then
		die "Install Nvidia drivers before proceeeding."
	fi
}
# check if sufficient disk space is available
check_disk_space () {
	local pkgname="$1"
	local required_space_gb=0
	if [ "$pkgname" == "davinci-resolve" ]; then
		required_space_gb=12
	elif [ "$pkgname" == "davinci-resolve-studio" ]; then
		required_space_gb=28
	fi
	local required_space_kb=$((required_space_gb * 1024 * 1024))
	local home_available_kb=$(df "$HOME" | awk 'NR==2 {print $4}')
	local root_available_kb=$(df / | awk 'NR==2 {print $4}')

	if [ "$home_available_kb" -lt "$required_space_kb" ]; then
		die "$outofspace"
	fi
	if [ "$root_available_kb" -lt "$required_space_kb" ]; then
		die "$outofspace"
	fi
}
getresolve () {
  	local pkgname="$_upkgname"
  	local _product=""
  	local _referid=""
  	local _siteurl=""
  	_archive_name=""
  	_archive_run_name=""

  	if [ "$pkgname" == "davinci-resolve" ]; then
    		_product="DaVinci Resolve"
    		_referid='dfd43085ef224766b06b579ce8a6d097'
    		_siteurl="https://www.blackmagicdesign.com/api/support/latest-stable-version/davinci-resolve/linux"
            local _useragent="User-Agent: Mozilla/5.0 (X11; Linux ${CARCH}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.75 Safari/537.36"
  	        local _releaseinfo
  	        _releaseinfo=$(curl -Ls "$_siteurl")
            _pkgver=$(printf "%s" "$_releaseinfo" | awk -F'[,:]' '{for(i=1;i<=NF;i++){if($i~/"major"/){print $(i+1)} if($i~/"minor"/){print $(i+1)} if($i~/"releaseNum"/){print $(i+1)}}}' | sed 'N;s/\n/./;N;s/\n/./')
            _releaseNum=$(printf "%s" "$_releaseinfo" | awk -F'[,:]' '{for(i=1;i<=NF;i++){if($i~/"releaseNum"/){print $(i+1)}}}')
            if [ "$_releaseNum" == "0" ]; then
                _filever=$(printf "%s" "$_releaseinfo" | awk -F'[,:]' '{for(i=1;i<=NF;i++){if($i~/"major"/){print $(i+1)} if($i~/"minor"/){print $(i+1)}}}' | sed 'N;s/\n/./')
            else
                _filever="${_pkgver}"
            fi
    		_archive_name="DaVinci_Resolve_${_filever}_Linux"
    		_archive_run_name="DaVinci_Resolve_${_filever}_Linux"
  	elif [ "$pkgname" == "davinci-resolve-studio" ]; then
    		_product="DaVinci Resolve Studio"
    		_referid='0978e9d6e191491da9f4e6eeeb722351'
    		_siteurl="https://www.blackmagicdesign.com/api/support/latest-stable-version/davinci-resolve-studio/linux"
            local _useragent="User-Agent: Mozilla/5.0 (X11; Linux ${CARCH}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.75 Safari/537.36"
  	        local _releaseinfo
  	        _releaseinfo=$(curl -Ls "$_siteurl")
            _pkgver=$(printf "%s" "$_releaseinfo" | awk -F'[,:]' '{for(i=1;i<=NF;i++){if($i~/"major"/){print $(i+1)} if($i~/"minor"/){print $(i+1)} if($i~/"releaseNum"/){print $(i+1)}}}' | sed 'N;s/\n/./;N;s/\n/./')
            _releaseNum=$(printf "%s" "$_releaseinfo" | awk -F'[,:]' '{for(i=1;i<=NF;i++){if($i~/"releaseNum"/){print $(i+1)}}}')
            if [ "$_releaseNum" == "0" ]; then
                _filever=$(printf "%s" "$_releaseinfo" | awk -F'[,:]' '{for(i=1;i<=NF;i++){if($i~/"major"/){print $(i+1)} if($i~/"minor"/){print $(i+1)}}}' | sed 'N;s/\n/./')
            else
                _filever="${_pkgver}"
            fi
    		_archive_name="DaVinci_Resolve_Studio_${_filever}_Linux"
    		_archive_run_name="DaVinci_Resolve_Studio_${_filever}_Linux"
  	fi

  	local _downloadId
  	_downloadId=$(printf "%s" "$_releaseinfo" | sed -n 's/.*"downloadId":"\([^"]*\).*/\1/p')

  	# Optional version check - uncomment if needed
  	# if [[ $_expected_pkgver != "$_pkgver" ]]; then
    	# 	echo "Version mismatch"
    	# 	return 1
  	# fi

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
	"Free") _upkgname='davinci-resolve'
		check_disk_space "$_upkgname"
		if ! is_cachy; then
			askpass
			depcheck
			prep_tmp_noram
			git clone https://aur.archlinux.org/davinci-resolve.git && cd davinci-resolve
			getresolve
			echo "Starting package build. This may take a while..."
			makepkg -si || die "Failed to build package"
			_append_transmap "pkg davinci-resolve"
			info "$finishmsg"
		else
			askpass
			depcheck
			pkg_install davinci-resolve
			info "$finishmsg"
		fi
		exit 0 ;;
	"Studio") _upkgname='davinci-resolve-studio'
		check_disk_space "$_upkgname"
		askpass
		depcheck
		prep_tmp_noram
		git clone https://aur.archlinux.org/davinci-resolve-studio.git && cd davinci-resolve-studio
		getresolve
		echo "Starting package build. This may take a while..."
		makepkg -si || die "Failed to build package"
		_append_transmap "pkg davinci-resolve-studio"
		info "$finishmsg"
		exit 0 ;;
	"Cancel") break ;;
	*) echo "Invalid Option" ;;
	esac
done
