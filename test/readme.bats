#!/usr/bin/env bats

setup() {
	load test_helper
	README="$PLUGIN_DIR/README.md"
}

@test "README shows how to add the plugin" {
	grep -qF 'asdf plugin add stringer https://github.com/douglasgomes98/asdf-stringer.git' "$README"
}

@test "README example lists golang before stringer" {
	local golang_line stringer_line
	golang_line=$(grep -nx 'golang 1.25.5' "$README" | head -1 | cut -d: -f1)
	stringer_line=$(grep -nx 'stringer 0.49.0' "$README" | head -1 | cut -d: -f1)
	[ -n "$golang_line" ]
	[ -n "$stringer_line" ]
	[ "$golang_line" -lt "$stringer_line" ]
}

@test "README states the go requirement from 0.50.0" {
	grep -qxF '| 0.50.0 and later | Go 1.26 or newer |' "$README"
}
