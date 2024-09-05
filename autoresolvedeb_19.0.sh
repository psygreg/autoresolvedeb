#!/bin/bash
#
#
#
#create temp folder and set cleanup
tmp="$(mktemp -d -t autoresolvedebXXXXX)"
cd "$tmp" || exit 2
#cleanup
cleanup() {
	rm -rf "$tmp" 
	}
trap cleanup EXIT
#get language from OS
get_lang() {
	local lang="${LANG:0:2}"
        local available=("pt" "en")

        if [[ " ${available[*]} " == *"$lang"* ]]; then
        	ulang="$lang"
        else
                ulang="en"
        fi
        }
#languages - add new translations under here
if ulang="pt"; then
	startup () {
		echo "Este é o AutoResolveDeb por Psygreg."
		echo "Este programa irá baixar DaVinci Resolve dos servidores da Blackmagic Design, converter em um pacote .deb e instalá-lo."
		echo "Qual versão deseja instalar?"
		}
	usrcancel="Cancelado pelo usuário."
else
	startup () {
		echo "This is AutoResolveDeb by Psygreg."
		echo "This program will download DaVinci Resolve from Blackmagic Design's source, convert it into a .deb package and install it."
		echo "Which version do you wish to install?"
		}
	usrcancel="Cancelled by user."
fi
#create JSON, user agent and download Resolve
getresolve() {
  	local pkgname="$_upkgname"
  	local major_version="18.6"
  	local minor_version="6"
  	local pkgver="${major_version}.${minor_version}"
  	local _product=""
  	local _referid=""
  	local _siteurl=""
  	local sha256sum=""
  	local _archive_name=""
  	local _archive_run_name=""

  	if [ "$pkgname" == "davinci-resolve" ]; then
    		_product="DaVinci Resolve"
    		_referid='dfd43085ef224766b06b579ce8a6d097'
    		_siteurl="https://www.blackmagicdesign.com/api/support/latest-stable-version/davinci-resolve/linux"
    		sha256sum='06ba9d3e2f4e6ca813a394e0fe622992fdb6b29b9cd5f9a351103ad1040b6dac'
    		_archive_name="DaVinci_Resolve_${pkgver}_Linux"
    		_archive_run_name="DaVinci_Resolve_${pkgver}_Linux"
  	elif [ "$pkgname" == "davinci-resolve-studio" ]; then
    		_product="DaVinci Resolve Studio"
    		_referid='0978e9d6e191491da9f4e6eeeb722351'
    		_siteurl="https://www.blackmagicdesign.com/api/support/latest-stable-version/davinci-resolve-studio/linux"
    		sha256sum='27c33c942fec19533cf81fd5ebd19706e8c0fd92c6ad4da47402171b885d38e4'
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
#get makeresolvedeb
makeresolvedeb () {
	wget https://www.danieltufvesson.com/download/?file=makeresolvedeb/makeresolvedeb_1.7.1_multi.sh.tar.gz;
	tar zxvf index.html?file=makeresolvedeb%2Fmakeresolvedeb_1.7.1_multi.sh.tar.gz;
	}
#check dependencies	
deps () {
	sudo apt install -y fakeroot xorriso;
	}
#installer
installer () {
	deps;
	unzip "${_archive_name}.zip";
	makeresolvedeb;
	./makeresolvedeb_1.7.1_multi.sh "${_archive_name}.run";
	sudo dpkg -i davinci-resolve-studio_18.6.6-mrd1.7.1_amd64.deb
	exit 0
	}
#RUNTIME START
get_lang
startup
select resolve_opt in "Free" "Studio" "Cancel"; do
	case $resolve_opt in
		Free )
			_upkgname=davinci-resolve
			getresolve;
			installer;;
		Studio )
			_upkgname=davinci-resolve-studio
			getresolve;
			installer;;
		Cancel )
			echo "$usrcancel";
			exit 0;;
	esac
done
