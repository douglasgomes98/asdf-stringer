#!/usr/bin/env bash

set -euo pipefail

TOOL_NAME="stringer"
GO_PACKAGE="golang.org/x/tools/cmd/stringer"
VERSIONS_URL="https://proxy.golang.org/golang.org/x/tools/@v/list"

fail() {
	echo -e "asdf-$TOOL_NAME: $*" >&2
	exit 1
}

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

# Every golang.org/x/tools tag known to the Go module proxy, without the leading v, unsorted.
list_all_versions() {
	local listing
	listing=$(curl -fsSL "$VERSIONS_URL") || fail "could not list versions from $VERSIONS_URL"
	[ -n "$listing" ] || fail "no versions found at $VERSIONS_URL"
	printf '%s\n' "$listing" | sed -n 's/^v//p'
}

# Path of the go binary that is active in the current directory. Resolved here, before the
# build leaves the project directory, because an asdf go shim picks its version from there.
active_go() {
	local goroot
	if goroot=$(GO111MODULE=off GOTOOLCHAIN=local go env GOROOT 2>/dev/null) &&
		[ -n "$goroot" ] && [ -x "$goroot/bin/go" ]; then
		echo "$goroot/bin/go"
		return
	fi
	fail "stringer is built from source and needs Go, and no working go was found.
Install it first, for example: asdf plugin add golang && asdf install golang <version>
and list golang before stringer in .tool-versions."
}

check_install_type() {
	if [ "$1" != "version" ]; then
		fail "only versions are supported, got install type '$1'"
	fi
}

# Runs the given go with the build isolated from the caller: no go.mod, go.work, vendor or
# GOFLAGS of the project apply, no other toolchain is ever downloaded, and the module cache
# is the given one, kept writable so asdf can delete it.
isolated_go() {
	local modcache="$1"
	shift
	GOMODCACHE="$modcache" GOTOOLCHAIN=local GOFLAGS="-mod=mod -modcacherw" GOWORK=off GO111MODULE=on "$@"
}

# Downloads golang.org/x/tools at the version, with every module stringer needs, into
# <download_path>/modcache.
download_version() {
	local install_type="$1"
	local version="${2#v}"
	local download_path="$3"
	check_install_type "$install_type"

	local go_bin work
	go_bin=$(active_go)
	work=$(mktemp -d "${TMPDIR:-/tmp}/asdf-$TOOL_NAME-download.XXXXXX")
	mkdir -p "$download_path"

	echo "* Downloading $GO_PACKAGE@v$version and its dependencies"
	if ! (
		cd "$work" &&
			isolated_go "$download_path/modcache" "$go_bin" mod init asdf-stringer.local/download 2>/dev/null &&
			isolated_go "$download_path/modcache" "$go_bin" get "$GO_PACKAGE@v$version"
	); then
		rm -rf "$work"
		fail "could not download $TOOL_NAME $version (see the go output above)"
	fi
	rm -rf "$work"
}

install_version() {
	local install_type="$1"
	local version="${2#v}"
	local install_path="$3"
	check_install_type "$install_type"

	local go_bin build_dir download_path="${ASDF_DOWNLOAD_PATH:-}"
	go_bin=$(active_go)
	build_dir=$(mktemp -d "${TMPDIR:-/tmp}/asdf-$TOOL_NAME.XXXXXX")
	# shellcheck disable=SC2064
	trap "rm -rf '$build_dir'" EXIT

	# asdf runs bin/download first; when install runs on its own, it downloads here.
	if [ -z "$download_path" ] || [ ! -d "$download_path/modcache" ]; then
		download_path="$build_dir/download"
		download_version "$install_type" "$version" "$download_path"
	fi

	# The download's module cache is also a GOPROXY tree, so the build needs no network.
	echo "* Building $GO_PACKAGE@v$version with $("$go_bin" version)"
	if ! (
		cd "$build_dir" &&
			GOBIN="$build_dir/bin" GOPROXY="file://$download_path/modcache/cache/download" \
				isolated_go "$download_path/modcache" "$go_bin" install "$GO_PACKAGE@v$version"
	); then
		fail "could not build $TOOL_NAME $version (see the go output above)"
	fi

	# Only a finished build reaches the install path.
	mkdir -p "$install_path/bin"
	mv "$build_dir/bin/$TOOL_NAME" "$install_path/bin/$TOOL_NAME"

	echo "$TOOL_NAME $version installation was successful!"
}
