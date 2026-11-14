#!/bin/bash
# runtime start
source "$SCRIPT_DIR/libs/linuxtoys.lib"
# menu
depcheck () {
	pkg_install fakeroot debugedit
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
patch_aur_pkgbuild () {
	local pkgbuild="${1:-PKGBUILD}"
	local target_ver="${_filever:-$_pkgver}"
	local archive="${_archive_name}.zip"

	[[ -f "$pkgbuild" ]] || die "PKGBUILD not found: $pkgbuild"
	[[ -n "$target_ver" ]] || die "Could not determine DaVinci Resolve package version."
	[[ -s "$archive" ]] || die "DaVinci Resolve archive not found: $archive"

	local current_ver
	current_ver=$(sed -n 's/^pkgver=//p' "$pkgbuild" | head -n1)
	if [[ "$current_ver" != "$target_ver" ]]; then
		sed -i -E "s/^pkgver=.*/pkgver=${target_ver}/" "$pkgbuild"
		sed -i -E 's/^pkgrel=.*/pkgrel=1/' "$pkgbuild"
	fi

	# Resolve bundles versioned GLib/libc++ files. Older PKGBUILDs hardcode
	# those versions, which breaks whenever Blackmagic updates the bundle.
	sed -i -E \
		-e 's|libglib-2\.0\.so\.0\{,\.[0-9.]+\}|libglib-2.0.so.0*|g' \
		-e 's|libgio-2\.0\.so\.0\{,\.[0-9.]+\}|libgio-2.0.so.0*|g' \
		-e 's|libgmodule-2\.0\.so\.0\{,\.[0-9.]+\}|libgmodule-2.0.so.0*|g' \
		-e 's|libgobject-2\.0\.so\.0\{,\.[0-9.]+\}|libgobject-2.0.so.0*|g' \
		-e 's|libc\+\+\.so\.1\{,\.[0-9.]+\}|libc++.so.1*|g' \
		-e 's|libc\+\+abi\.so\.1\{,\.[0-9.]+\}|libc++abi.so.1*|g' \
		-e 's|rm squashfs-root/libs/libglib-2\.0\.so\.0\*|rm -f squashfs-root/libs/libglib-2.0.so.0*|' \
		"$pkgbuild"

	# Resolve 21.1 expects /opt/resolve/Immersive to exist at startup.
	# Do nothing once the AUR PKGBUILD creates it itself.
	if ! grep -Eq '/Immersive"?([[:space:]]|$)' "$pkgbuild"; then
		if grep -q 'Apple Immersive/Calibration' "$pkgbuild"; then
			sed -i '/Apple Immersive\/Calibration/a\    install -d -m 0755 "${pkgdir}/opt/${_pkgname}/Immersive"' "$pkgbuild"
		else
			die "Could not patch the Resolve Immersive directory into PKGBUILD."
		fi
	fi

	# The AUR prepare() runs patchelf on every ELF under the extracted bundle.
	# Blackmagic ships bin/Plugins/ChromiumEmbeddedFramework/chrome-sandbox
	# with its .note.ABI-tag already moved by an old patchelf while the
	# PT_NOTE segment was left pointing at the old spot, so every patchelf
	# currently in the repos aborts on it with "cannot normalize PT_NOTE
	# segment: non-contiguous SHT_NOTE sections" and kills the whole build.
	# It only links libc and keeps the vendor's working $ORIGIN rpath, so it
	# does not need the loop's rpath at all; exclude it from patchelf by name.
	sed -i -E 's|find "squashfs-root" -type f -size -32M -print0|find "squashfs-root" -type f -size -32M ! -name "chrome-sandbox" -print0|' "$pkgbuild"
	if ! grep -q '! -name "chrome-sandbox"' "$pkgbuild"; then
		die "Could not patch the chrome-sandbox patchelf exclusion into PKGBUILD."
	fi

	# The downloaded archive is authoritative; keep makepkg verification enabled
	# while replacing the stale AUR checksum after a Blackmagic version bump.
	local archive_sha
	archive_sha=$(sha256sum "$archive" | awk '{print $1}')
	sed -i -E "0,/^[[:space:]]*sha256sums=\('[^']*'/s||sha256sums=('${archive_sha}'|" "$pkgbuild"
}

# makepkg installs missing build dependencies with a targeted pacman call,
# which fails on a partially upgraded system: the gstreamer family pins its
# exact full versions across itself (qt5-multimedia pulls gst-plugins-base,
# which pins gst-plugins-base-libs=1.28.9-1.1, while an already installed
# gst-libav/gst-plugin-va/gst-plugins-bad/gst-plugins-ugly still pin the
# previous version and are not part of the transaction). Arch does not
# support partial upgrades; the only fix is a full system upgrade before
# the build. Detected through pacman's violation lines (":: ... =<ver>"),
# which keep package names and versions through any translation.
aur_makepkg () {
	local build_log build_status
	build_log=$(mktemp) || build_log=/dev/null
	makepkg -si 2>&1 | tee -- "$build_log"
	build_status=${PIPESTATUS[0]}
	if (( build_status == 0 )); then
		[[ "$build_log" == /dev/null ]] || rm -f -- "$build_log"
		return 0
	fi
	# Only heal when the system actually lags the (freshly rated) mirrors;
	# a system ahead of the repos is left alone instead of being
	# downgrade-attempted.
	if grep -Eq '^:: .+[A-Za-z0-9._+-]+=[0-9][0-9.]*-[0-9]+' -- "$build_log" &&
		[[ -n $(pacman -Quq 2>/dev/null) ]]; then
		echo "Dependency resolution failed: installed packages pin exact versions the current repositories no longer provide."
		echo "Arch does not support partial upgrades; upgrading the whole system first, then retrying the build once..."
		# A system upgrade must never be recorded in the transaction map.
		runner_lock "package-transaction" "Upgrading the system..."
		pacman_lock_guard
		if ! pacman_transaction sudo_ pacman -Syu --noconfirm; then
			runner_unlock
			[[ "$build_log" == /dev/null ]] || rm -f -- "$build_log"
			die "Failed to upgrade the system before retrying the build."
		fi
		runner_unlock
		if makepkg -si; then
			[[ "$build_log" == /dev/null ]] || rm -f -- "$build_log"
			return 0
		fi
	fi
	[[ "$build_log" == /dev/null ]] || rm -f -- "$build_log"
	die "Failed to build package"
}

while true; do
	CHOICE=$(radioselect --no-default --title "AutoResolvePkg" --text "Which version do you want to install?" "Free" "Studio" "$msg070") || exit 100

	case $CHOICE in
	"Free") _upkgname='davinci-resolve'
		check_disk_space "$_upkgname"
		if ! is_cachy; then
			askpass
			depcheck
			prep_tmp_noram
			rm -rf -- davinci-resolve
			git clone https://aur.archlinux.org/davinci-resolve.git || die "Failed to fetch davinci-resolve from the AUR."
			cd davinci-resolve || die "Failed to enter the davinci-resolve build directory."
			getresolve
			patch_aur_pkgbuild
			echo "Starting package build. This may take a while..."
			aur_makepkg
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
		rm -rf -- davinci-resolve-studio
		git clone https://aur.archlinux.org/davinci-resolve-studio.git || die "Failed to fetch davinci-resolve-studio from the AUR."
		cd davinci-resolve-studio || die "Failed to enter the davinci-resolve-studio build directory."
		getresolve
		patch_aur_pkgbuild
		echo "Starting package build. This may take a while..."
		aur_makepkg
		_append_transmap "pkg davinci-resolve-studio"
        export AUTO_DVNAT=1
        # call_script resolveaac
        call_script resolvehw
		info "$finishmsg"
		exit 0 ;;
	"$msg070") exit 100 ;;
	*) echo "Invalid Option" ;;
	esac
done
