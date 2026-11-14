#!/bin/bash
source "$SCRIPT_DIR/libs/linuxtoys.lib"
_lang_
# dependency checker
depcheck () {
    if is_suse; then
        pkg_install xorriso curl libfuse2 wget newt libxcb-dri2-0 libxcb-dri2-0-32bit libgthread-2_0-0 libgthread-2_0-0-32bit libapr1-0 libapr-util1-0 libQt5Gui5 libglib-2_0-0 libglib-2_0-0-32bit libgio-2_0-0 libgmodule-2_0-0 libGLU1 libcrypt1
    else
        pkg_install xorriso fuse qt5-qtbase-gui curl wget newt libxcb libxcb.i686 glib2 glib2.i686 apr apr-util mesa-libGLU libxcrypt-compat
    fi
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

# menu
while true; do
	CHOICE=$(radioselect --no-default --title "AutoResolveRpm" --text "Which version do you want to install?" "Free" "Studio" "$msg070") || exit 100

	case $CHOICE in
	"Free") _upkgname='davinci-resolve'
		check_disk_space "$_upkgname"
		prep_tmp_noram
		getresolve
		unzip ${_archive_name}.zip || die "Failed to extract the DaVinci Resolve archive."
		askpass
		depcheck
		prep_dir /opt/resolve
		chmod +x ${_archive_run_name}.run
		export SKIP_PACKAGE_CHECK=1
		./${_archive_run_name}.run || die "Failed to install DaVinci Resolve."
    	cd /opt/resolve/libs || die "Failed to enter /opt/resolve/libs."
    	sudo_ mkdir -p disabled || die "Failed to create /opt/resolve/libs/disabled."
    	move_ libglib* disabled
    	move_ libgio* disabled
    	move_ libgmodule* disabled
		info "$finishmsg"
		exit 0 ;;
	"Studio") _upkgname='davinci-resolve-studio'
		check_disk_space "$_upkgname"
		prep_tmp_noram
		getresolve
		unzip ${_archive_name}.zip || die "Failed to extract the DaVinci Resolve archive."
		askpass
		depcheck
		prep_dir /opt/resolve
		chmod +x ./${_archive_run_name}.run
		export SKIP_PACKAGE_CHECK=1
		./${_archive_run_name}.run || die "Failed to install DaVinci Resolve."
    	cd /opt/resolve/libs || die "Failed to enter /opt/resolve/libs."
    	sudo_ mkdir -p disabled || die "Failed to create /opt/resolve/libs/disabled."
    	move_ libglib* disabled
    	move_ libgio* disabled
    	move_ libgmodule* disabled
        export AUTO_DVNAT=1
        # call_script resolveaac
        call_script resolvehw
		info "$finishmsg"
		exit 0 ;;
	"$msg070") exit 100 ;;
	*) echo "Invalid Option" ;;
	esac
done
