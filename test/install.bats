#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
	load test_helper
	common_setup
	export PATH="$GO_BIN_DIR:$PATH"
}

teardown() {
	common_teardown
}

assert_nothing_installed() {
	[ ! -e "$(installed_binary "$1")" ]
}

@test "no go: missing go on PATH fails with the go dependency message" {
	PATH="/usr/bin:/bin" command -v go && skip "a go binary lives in /usr/bin or /bin"
	run --separate-stderr env PATH="/usr/bin:/bin" \
		ASDF_INSTALL_TYPE=version ASDF_INSTALL_VERSION=0.49.0 \
		ASDF_INSTALL_PATH="$TEST_TMP/install/0.49.0" "$PLUGIN_DIR/bin/install"
	[ "$status" -ne 0 ]
	[[ "$stderr" == *"stringer is built from source and needs Go"* ]]
	[[ "$stderr" == *"asdf install golang"* ]]
	assert_nothing_installed 0.49.0
}

@test "no go: a go shim without a version fails with the go dependency message" {
	cat >"$STUB_DIR/go" <<'EOF'
#!/usr/bin/env bash
echo "No version is set for command go" >&2
exit 126
EOF
	chmod +x "$STUB_DIR/go"
	run --separate-stderr env PATH="$STUB_DIR:/usr/bin:/bin" \
		ASDF_INSTALL_TYPE=version ASDF_INSTALL_VERSION=0.49.0 \
		ASDF_INSTALL_PATH="$TEST_TMP/install/0.49.0" "$PLUGIN_DIR/bin/install"
	[ "$status" -ne 0 ]
	[[ "$stderr" == *"stringer is built from source and needs Go"* ]]
	assert_nothing_installed 0.49.0
}

@test "newer go: 0.50.0 on go 1.25 fails without downloading a toolchain" {
	export GOMODCACHE="$TEST_TMP/modcache" GOTOOLCHAIN=auto
	run --separate-stderr run_install version 0.50.0
	[ "$status" -ne 0 ]
	[[ "$stderr" == *"requires go >= 1.26.0 (running go 1.25"* ]]
	[ -z "$(find "$GOMODCACHE" -path '*golang.org/toolchain*' -print -quit)" ]
	assert_nothing_installed 0.50.0
}

@test "unknown version: 0.99.0 fails with invalid version" {
	run --separate-stderr run_install version 0.99.0
	[ "$status" -ne 0 ]
	[[ "$stderr" == *"invalid version"* ]]
	assert_nothing_installed 0.99.0
}

@test "interrupted build leaves no binary and a retry completes" {
	# A go that writes half a binary into GOBIN and dies, as an interrupted build would.
	cat >"$STUB_DIR/go" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "install" ]; then
	mkdir -p "\$GOBIN" && printf 'partial' >"\$GOBIN/stringer" && chmod +x "\$GOBIN/stringer"
	exit 1
fi
exec "$GO_BIN_DIR/go" "\$@"
EOF
	chmod +x "$STUB_DIR/go"
	# The plugin resolves go through GOROOT, so the stub must be the GOROOT's go.
	mkdir -p "$TEST_TMP/fakeroot/bin"
	mv "$STUB_DIR/go" "$TEST_TMP/fakeroot/bin/go"
	cat >"$STUB_DIR/go" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "env" ] && [ "\$2" = "GOROOT" ]; then echo "$TEST_TMP/fakeroot"; exit 0; fi
exec "$GO_BIN_DIR/go" "\$@"
EOF
	chmod +x "$STUB_DIR/go"

	run --separate-stderr env PATH="$STUB_DIR:$PATH" \
		ASDF_INSTALL_TYPE=version ASDF_INSTALL_VERSION=0.49.0 \
		ASDF_INSTALL_PATH="$TEST_TMP/install/0.49.0" "$PLUGIN_DIR/bin/install"
	[ "$status" -ne 0 ]
	assert_nothing_installed 0.49.0

	run --separate-stderr run_install version 0.49.0
	[ "$status" -eq 0 ]
	[ -x "$(installed_binary 0.49.0)" ]
	run "$(installed_binary 0.49.0)" -help
	[ "$status" -eq 0 ]
}

@test "consumer module with GOFLAGS=-mod=vendor still installs" {
	mkdir -p "$TEST_TMP/consumer/vendor"
	printf 'module example.com/consumer\n\ngo 1.25\n' >"$TEST_TMP/consumer/go.mod"
	printf '# vendored\n' >"$TEST_TMP/consumer/vendor/modules.txt"
	cd "$TEST_TMP/consumer"
	GOFLAGS=-mod=vendor run --separate-stderr run_install version 0.49.0
	[ "$status" -eq 0 ]
	go version -m "$(installed_binary 0.49.0)" | grep -Eq 'mod[[:space:]]+golang.org/x/tools[[:space:]]+v0\.49\.0'
}

@test "leading v: v0.49.0 installs golang.org/x/tools v0.49.0" {
	run --separate-stderr run_install version v0.49.0
	[ "$status" -eq 0 ]
	go version -m "$(installed_binary v0.49.0)" | grep -Eq 'mod[[:space:]]+golang.org/x/tools[[:space:]]+v0\.49\.0'
}

@test "ref install is refused" {
	run --separate-stderr run_install ref 3c1a2b4
	[ "$status" -ne 0 ]
	[[ "$stderr" == *"only versions are supported"* ]]
	assert_nothing_installed 3c1a2b4
}
