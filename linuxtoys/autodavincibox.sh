#!/bin/bash
source "$SCRIPT_DIR/libs/linuxtoys.lib"

# install dependencies
davinciboxdeps () {
    if is_debian || is_ubuntu; then
		if is_ubuntu; then
        	sudo_ add-apt-repository ppa:michel-slm/distrobox -y
        	apt_transaction sudo_ apt-get update
    	fi
        if is_rocm_capable && ! is_nvidia; then
			if is_debian; then
            	pkg_install --no-recommends rocm-podman-support
			else
				prep_tmp
				wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | gpg --dearmor | sudo_ tee /etc/apt/keyrings/rocm.gpg > /dev/null
				_codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
				if [ "$_codename" != "noble" ]; then # change when rocm supports codename of resolute
					_codename="noble"
				fi
				echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/amd-container-toolkit/apt/ ${_codename} main" | sudo_ tee /etc/apt/sources.list.d/amd-container-toolkit.list
				apt_transaction sudo_ apt-get update
				if ! lsmod | grep amdgpu; then
					sudo_ modprobe amdgpu || fatal "Failed to load amdgpu kernel module."
				fi
				pkg_install amd-container-toolkit
			fi
		fi
    fi
	if is_nvidia; then
		if is_ubuntu || is_debian; then
			pkg_install ca-certificates curl gnupg
			curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo_ gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  				&& curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    			sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    			sudo_ tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
			apt_transaction sudo_ apt-get update
		elif is_fedora || is_ostree || is_rhel; then
			pkg_install curl
			curl -s -L -k https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
  				sudo_ tee /etc/yum.repos.d/nvidia-container-toolkit.repo
		elif is_suse; then
			sudo_ zypper ar https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo
		fi
        pkg_install nvidia-container-toolkit
		if ! is_arch && ! is_cachy; then
			pkg_install nvidia-container-toolkit-base libnvidia-container-tools libnvidia-container1
		else
			pkg_install libnvidia-container
		fi
		sleep 1
		summon_optimizers
		nvidia_ctkpatch
    fi
    local _container_deps=(podman lshw distrobox unzip)
    if [ -d /dev/vboxusb ]; then
        _container_deps+=(crun)
    fi
    pkg_install "${_container_deps[@]}"
}

# installation
inresolve () {
	check_disk_space "$_upkgname"
	askpass
    davinciboxdeps
    prep_tmp_noram
    git clone https://github.com/zelikos/davincibox.git || die "Failed to download DaVinciBox."
    cd davincibox || die "Failed to enter DaVinciBox directory."
    getresolve
    unzip ${_archive_name}.zip || die "Failed to extract the DaVinci Resolve archive."
    if is_nvidia; then
        # fix #1406 - upstream "unresolvable CDI devices" bug
        sed -i 's|--additional-flags "--device nvidia.com/gpu=all"|--additional-flags "--gpus all"|' setup.sh
    fi
    chmod +x setup.sh
    if ./setup.sh ${_archive_run_name}.run; then
		distrobox_created davincibox
	else
		fatal "Failed to create container DaVinciBox"
	fi
	distrobox enter davincibox -- add-davinci-launcher distrobox
	local desktop_file="$HOME/.local/share/applications/DaVinciResolve.desktop"
	prep_edit "$desktop_file"
	if [ -f "$desktop_file" ]; then
		sed -i 's|^Exec=.*|Exec=distrobox-enter -n davincibox -- /opt/resolve/bin/resolve|' "$desktop_file" || fatal "Failed to patch app menu entry"
	fi

    if is_rocm_capable && ! is_nvidia; then
        distrobox enter davincibox -- bash -c "sudo dnf install -y rocm-comgr rocm-runtime rccl rocalution rocblas rocfft rocm-smi rocsolver rocsparse rocm-device-libs rocminfo rocm-hip hiprand rocm-opencl clinfo && sudo usermod -aG render,video \$USER"
        # stop to ensure usermod takes effect before usage of the software
        distrobox stop davincibox
    elif is_rusticl_capable && ! is_rocm_capable; then
        RUSTICL_CONTAINER=davincibox call_script rusticl || fatal "Failed to install Rusticl in DaVinciBox"
        if [[ -f "$desktop_file" ]]; then
            sed -i 's|^Exec=.*|Exec=distrobox-enter -n davincibox -- env RUSTICL_ENABLE=radeonsi /opt/resolve/bin/resolve|' "$desktop_file" || fatal "Failed to configure Rusticl launcher"
        fi
    fi

    if [ "$_upkgname" = "davinci-resolve-studio" ]; then
        export AUTO_DVBOX=1
        # call_script resolveaac
        call_script resolvehw
    fi

    info "$finishmsg"
}
# menu
while true; do
	CHOICE=$(radioselect --no-default --title "AutoResolveBox" --text "Which version do you want to install?" "Free" "Studio" "$msg070") || exit 100

	case $CHOICE in
	"Free") _upkgname='davinci-resolve'
    	inresolve
		exit 0 ;;
	"Studio") _upkgname='davinci-resolve-studio'
	  	inresolve
    	exit 0 ;;
	"$msg070") exit 100 ;;
	*) echo "Invalid Option" ;;
	esac
done
