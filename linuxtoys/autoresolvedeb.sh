#!/bin/bash
source "$SCRIPT_DIR/libs/linuxtoys.lib"
_lang_
# dependency checker
depcheck () {
    pkg_install fakeroot xorriso libqt5gui5 libxcb-dri2-0 libcrypt1 libglu1-mesa libglib2.0-0t64 libapr1 libaprutil1
	if is_rocm_capable; then
		call_script rocm
	elif is_rusticl_capable; then
		call_script rusticl || die "Failed to install Rusticl"
		export RUSTICL_ENABLE=radeonsi
	elif is_intel; then
		call_script icr
	elif is_nvidia && ! nvidia-smi; then
		die "Install Nvidia drivers before proceeeding."
	fi
}

# get makeresolvedeb
makeresolvedeb () {
	local page="https://www.danieltufvesson.com/makeresolvedeb"
    local download_base="https://www.danieltufvesson.com/download/?file=makeresolvedeb"
    local archive
    archive=$(
        curl -fsSL "$page" |
        grep -oE 'makeresolvedeb_[0-9]+(\.[0-9]+)+_multi\.sh\.tar\.gz' |
        head -n1
    )
    if [[ -z "$archive" ]]; then
        die "Could not find the latest MakeResolveDeb archive."
    fi
	mrdver="${archive#makeresolvedeb_}"
    mrdver="${mrdver%_multi.sh.tar.gz}"
    echo "Downloading ${archive}..."
    curl -fL \
        --output "$archive" \
        "${download_base}/${archive}" ||
        {
            die "Failed to download $archive."
        }
    tar zxvf "$archive" || {
        die "Failed to extract $archive."
    }
}
# menu
while true; do
	CHOICE=$(radioselect --no-default --title "AutoResolveDeb" --text "Which version do you want to install?" "Free" "Studio" "$msg070") || exit 100

	case $CHOICE in
	"Free") _upkgname='davinci-resolve'
		check_disk_space "$_upkgname"
		askpass
	  	depcheck
		prep_tmp_noram
		getresolve
		makeresolvedeb
		unzip ${_archive_name}.zip || die "Failed to extract the DaVinci Resolve archive."
		./makeresolvedeb_${mrdver}_multi.sh ${_archive_run_name}.run || die "Failed to build DaVinci Resolve packages with MakeResolveDeb."
		pkg_fromfile davinci-resolve_${_filever}-mrd${mrdver}_amd64.deb
		pkg_fromfile davinci-resolve-data_${_filever}-mrd${mrdver}_amd64.deb
		info "$finishmsg"
		exit 0 ;;
	"Studio") _upkgname='davinci-resolve-studio'
		check_disk_space "$_upkgname"
		askpass
	  	depcheck
		prep_tmp_noram
		getresolve
		makeresolvedeb
		unzip ${_archive_name}.zip || die "Failed to extract the DaVinci Resolve archive."
		./makeresolvedeb_${mrdver}_multi.sh ${_archive_run_name}.run || die "Failed to build DaVinci Resolve packages with MakeResolveDeb."
		pkg_fromfile davinci-resolve-studio_${_filever}-mrd${mrdver}_amd64.deb
		pkg_fromfile davinci-resolve-studio-data_${_filever}-mrd${mrdver}_amd64.deb
        export AUTO_DVNAT=1
        # call_script resolveaac
        call_script resolvehw
		info "$finishmsg"
		exit 0 ;;
	"$msg070") exit 100 ;;
	*) echo "Invalid Option" ;;
	esac
done
