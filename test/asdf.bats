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
	[[ "$output" == *"golang.org/x/tools/cmd/stringer"* ]]
	[[ "$output" == *"Go"* ]]
	[[ "$output" == *"asdf install golang"* ]]
	[[ "$output" == *"https://pkg.go.dev/golang.org/x/tools/cmd/stringer"* ]]
	[[ "$output" == *"https://github.com/douglasgomes98/asdf-stringer"* ]]
}
