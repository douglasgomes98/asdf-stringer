#!/usr/bin/env bash
# Shared setup for the bats suites. Tests need a real Go 1.25.x: set GO125_BIN to its bin
# directory, or have one on PATH, or have `golang 1.25.5` installed with asdf.

PLUGIN_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
export PLUGIN_DIR

go125_bin() {
	if [ -n "${GO125_BIN:-}" ]; then
		echo "$GO125_BIN"
		return
	fi
	local goroot
	if goroot=$(GO111MODULE=off GOTOOLCHAIN=local go env GOROOT 2>/dev/null) &&
		"$goroot/bin/go" version 2>/dev/null | grep -q 'go1\.25'; then
		echo "$goroot/bin"
		return
	fi
	if goroot=$(asdf where golang 1.25.5 2>/dev/null); then
		echo "$goroot/go/bin"
		return
	fi
	echo "test setup: no Go 1.25 found (set GO125_BIN)" >&2
	return 1
}

common_setup() {
	TEST_TMP="$(mktemp -d "${BATS_TMPDIR:-/tmp}/asdf-stringer-test.XXXXXX")"
	STUB_DIR="$TEST_TMP/stubs"
	mkdir -p "$STUB_DIR"
	GO_BIN_DIR="$(go125_bin)"
	export TEST_TMP STUB_DIR GO_BIN_DIR
}

common_teardown() {
	# Go writes the module cache read-only; make it removable first.
	chmod -R u+w "$TEST_TMP" 2>/dev/null || true
	rm -rf "$TEST_TMP"
}

# run bin/install the way asdf does, with the given type, version and install path.
run_install() {
	local install_type="$1" version="$2"
	ASDF_INSTALL_TYPE="$install_type" \
		ASDF_INSTALL_VERSION="$version" \
		ASDF_INSTALL_PATH="$TEST_TMP/install/$version" \
		"$PLUGIN_DIR/bin/install"
}

installed_binary() {
	echo "$TEST_TMP/install/$1/bin/stringer"
}
