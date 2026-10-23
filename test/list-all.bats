#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
	load test_helper
	common_setup
}

teardown() {
	common_teardown
}

# A fake curl that logs its arguments and answers with an unsorted proxy listing.
stub_curl_ok() {
	cat >"$STUB_DIR/curl" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"$TEST_TMP/curl.log"
printf 'v0.10.0\nv0.9.0\nv0.52.0\nv0.1.0\nv0.49.0\nv0.4.1\nv0.4.0\n'
EOF
	chmod +x "$STUB_DIR/curl"
}

stub_curl_exit() {
	cat >"$STUB_DIR/curl" <<EOF
#!/usr/bin/env bash
exit $1
EOF
	chmod +x "$STUB_DIR/curl"
}

@test "lists proxy versions sorted without v" {
	stub_curl_ok
	run --separate-stderr env PATH="$STUB_DIR:$PATH" "$PLUGIN_DIR/bin/list-all"
	[ "$status" -eq 0 ]
	[ "$output" = "0.1.0 0.4.0 0.4.1 0.9.0 0.10.0 0.49.0 0.52.0" ]
	grep -q 'https://proxy.golang.org/golang.org/x/tools/@v/list' "$TEST_TMP/curl.log"
}

@test "proxy failure: unreachable makes list-all fail with the url on stderr" {
	stub_curl_exit 6
	run --separate-stderr env PATH="$STUB_DIR:$PATH" "$PLUGIN_DIR/bin/list-all"
	[ "$status" -ne 0 ]
	[ -z "$output" ]
	[[ "$stderr" == *"https://proxy.golang.org/golang.org/x/tools/@v/list"* ]]
}

@test "proxy failure: http error makes list-all fail with the url on stderr" {
	stub_curl_exit 22
	run --separate-stderr env PATH="$STUB_DIR:$PATH" "$PLUGIN_DIR/bin/list-all"
	[ "$status" -ne 0 ]
	[ -z "$output" ]
	[[ "$stderr" == *"https://proxy.golang.org/golang.org/x/tools/@v/list"* ]]
}

@test "proxy failure: unreachable makes latest-stable fail with the url on stderr" {
	stub_curl_exit 6
	run --separate-stderr env PATH="$STUB_DIR:$PATH" "$PLUGIN_DIR/bin/latest-stable"
	[ "$status" -ne 0 ]
	[ -z "$output" ]
	[[ "$stderr" == *"https://proxy.golang.org/golang.org/x/tools/@v/list"* ]]
}

@test "proxy failure: http error makes latest-stable fail with the url on stderr" {
	stub_curl_exit 22
	run --separate-stderr env PATH="$STUB_DIR:$PATH" "$PLUGIN_DIR/bin/latest-stable"
	[ "$status" -ne 0 ]
	[ -z "$output" ]
	[[ "$stderr" == *"https://proxy.golang.org/golang.org/x/tools/@v/list"* ]]
}

@test "proxy failure: an empty 200 makes list-all fail with the url on stderr" {
	stub_curl_exit 0
	run --separate-stderr env PATH="$STUB_DIR:$PATH" "$PLUGIN_DIR/bin/list-all"
	[ "$status" -ne 0 ]
	[ -z "$output" ]
	[[ "$stderr" == *"https://proxy.golang.org/golang.org/x/tools/@v/list"* ]]
}

@test "latest-stable prints the highest version" {
	stub_curl_ok
	run --separate-stderr env PATH="$STUB_DIR:$PATH" "$PLUGIN_DIR/bin/latest-stable"
	[ "$status" -eq 0 ]
	[ "$output" = "0.52.0" ]
}

@test "latest-stable filters by the query asdf passes" {
	stub_curl_ok
	run --separate-stderr env PATH="$STUB_DIR:$PATH" "$PLUGIN_DIR/bin/latest-stable" 0.4
	[ "$status" -eq 0 ]
	[ "$output" = "0.49.0" ]
	run --separate-stderr env PATH="$STUB_DIR:$PATH" "$PLUGIN_DIR/bin/latest-stable" 0.4.
	[ "$status" -eq 0 ]
	[ "$output" = "0.4.1" ]
}
