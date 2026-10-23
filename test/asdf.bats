#!/usr/bin/env bats
# End-to-end through asdf itself, in an isolated ASDF_DATA_DIR with this checkout as the plugin.

bats_require_minimum_version 1.5.0

setup() {
	load test_helper
	common_setup
	export ASDF_DATA_DIR="$TEST_TMP/asdf-data"
	# A copy, not a symlink: asdf does not list a symlinked plugin, so it would never reshim it.
	mkdir -p "$ASDF_DATA_DIR/plugins/stringer"
	cp -R "$PLUGIN_DIR/bin" "$PLUGIN_DIR/lib" "$ASDF_DATA_DIR/plugins/stringer/"
	export PATH="$GO_BIN_DIR:$ASDF_DATA_DIR/shims:$PATH"
}

teardown() {
	common_teardown
}

@test "asdf list all stringer lists the real proxy versions" {
	run --separate-stderr asdf list all stringer
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "0.1.0" ]
	printf '%s\n' "${lines[@]}" | grep -qx '0.49.0'
	printf '%s\n' "${lines[@]}" | grep -qx '0.52.0'
}

@test "asdf latest stringer is the last listed version" {
	run --separate-stderr asdf list all stringer
	[ "$status" -eq 0 ]
	local last="${lines[${#lines[@]} - 1]}"
	run --separate-stderr asdf latest stringer
	[ "$status" -eq 0 ]
	[ "$output" = "$last" ]
}

@test "asdf install stringer 0.49.0 exposes a working shim" {
	mkdir -p "$TEST_TMP/project"
	cd "$TEST_TMP/project"
	printf 'stringer 0.49.0\n' >.tool-versions
	run --separate-stderr asdf install stringer 0.49.0
	[ "$status" -eq 0 ]
	[ "$(command -v stringer)" = "$ASDF_DATA_DIR/shims/stringer" ]
	run stringer -help
	[ "$status" -eq 0 ]
	go version -m "$(asdf where stringer 0.49.0)/bin/stringer" |
		grep -Eq 'mod[[:space:]]+golang.org/x/tools[[:space:]]+v0\.49\.0'
}

@test "asdf help stringer shows overview, go dependency and links" {
	run asdf help stringer
	[ "$status" -eq 0 ]
	[[ "$output" == *"stringer generates String() methods for Go integer constants"* ]]
	[[ "$output" == *"builds it from source with the Go version"* ]]
	[[ "$output" == *"Dependencies: Go"* ]]
	[[ "$output" == *"asdf install golang"* ]]
	[[ "$output" == *"https://pkg.go.dev/golang.org/x/tools/cmd/stringer"* ]]
	[[ "$output" == *"https://github.com/douglasgomes98/asdf-stringer"* ]]
}

assert_not_listed() {
	local listed
	listed=$(asdf list stringer 2>&1 || true)
	[[ "$listed" != *"$1"* ]]
}

@test "asdf install without go fails and lists nothing" {
	PATH="/usr/bin:/bin" command -v go && skip "a go binary lives in /usr/bin or /bin"
	# asdf alone, without the directory it lives in (Homebrew also ships go there).
	mkdir -p "$TEST_TMP/asdf-only"
	ln -s "$(command -v asdf)" "$TEST_TMP/asdf-only/asdf"
	run --separate-stderr env PATH="$ASDF_DATA_DIR/shims:/usr/bin:/bin:$TEST_TMP/asdf-only" \
		asdf install stringer 0.49.0
	[ "$status" -ne 0 ]
	[[ "$stderr$output" == *"stringer is built from source and needs Go"* ]]
	assert_not_listed 0.49.0
}

@test "asdf install 0.50.0 on go 1.25 fails and lists nothing" {
	GOTOOLCHAIN=auto run --separate-stderr asdf install stringer 0.50.0
	[ "$status" -ne 0 ]
	[[ "$stderr$output" == *"requires go >= 1.26.0 (running go 1.25"* ]]
	assert_not_listed 0.50.0
}

@test "asdf install of an unknown version fails and lists nothing" {
	run --separate-stderr asdf install stringer 0.99.0
	[ "$status" -ne 0 ]
	[[ "$stderr$output" == *"invalid version"* ]]
	assert_not_listed 0.99.0
}

@test "asdf install ref is refused and lists nothing" {
	run --separate-stderr asdf install stringer ref:3c1a2b4
	[ "$status" -ne 0 ]
	[[ "$stderr$output" == *"only versions are supported"* ]]
	assert_not_listed 3c1a2b4
}

@test "asdf install from a consumer module with GOFLAGS=-mod=vendor works" {
	mkdir -p "$TEST_TMP/consumer/vendor"
	printf 'module example.com/consumer\n\ngo 1.25\n' >"$TEST_TMP/consumer/go.mod"
	printf '# vendored\n' >"$TEST_TMP/consumer/vendor/modules.txt"
	printf 'stringer 0.49.0\n' >"$TEST_TMP/consumer/.tool-versions"
	cd "$TEST_TMP/consumer"
	GOFLAGS=-mod=vendor run --separate-stderr asdf install stringer 0.49.0
	[ "$status" -eq 0 ]
	run stringer -help
	[ "$status" -eq 0 ]
}
