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

install_version() {
	local install_type="$1"
	local version="${2#v}"
	local install_path="$3"

	if [ "$install_type" != "version" ]; then
		fail "only versions are supported, got install type '$install_type'"
	fi

	local go_bin build_dir
	go_bin=$(active_go)
	build_dir=$(mktemp -d "${TMPDIR:-/tmp}/asdf-$TOOL_NAME.XXXXXX")
	# shellcheck disable=SC2064
	trap "rm -rf '$build_dir'" EXIT

	echo "* Building $GO_PACKAGE@v$version with $("$go_bin" version)"

	# Built outside the caller's module, with its go.mod, go.work, vendor and GOFLAGS out of
	# reach, and never with a toolchain other than the active one.
	if ! (
		cd "$build_dir" &&
			GOBIN="$build_dir/bin" GOTOOLCHAIN=local GOFLAGS=-mod=mod GOWORK=off GO111MODULE=on \
				"$go_bin" install "$GO_PACKAGE@v$version"
	); then
		fail "could not build $TOOL_NAME $version (see the go output above)"
	fi

	# Only a finished build reaches the install path.
	mkdir -p "$install_path/bin"
	mv "$build_dir/bin/$TOOL_NAME" "$install_path/bin/$TOOL_NAME"

	echo "$TOOL_NAME $version installation was successful!"
}
