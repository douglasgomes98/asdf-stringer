#!/usr/bin/env bash
# Runs `asdf plugin test` against this checkout, the same command asdf-vm/actions/plugin-test
# runs in CI, in a throwaway asdf data dir. Go comes from GO125_BIN or asdf's golang 1.25.5,
# resolved before the data dir is swapped.

set -euo pipefail

plugin_dir="$(cd "$(dirname "$0")/.." && pwd)"
go_bin="${GO125_BIN:-$(asdf where golang 1.25.5)/go/bin}"
ref="${1:-$(git -C "$plugin_dir" rev-parse --abbrev-ref HEAD)}"

data_dir="$(mktemp -d "${TMPDIR:-/tmp}/asdf-stringer-plugin-test.XXXXXX")"
trap 'chmod -R u+w "$data_dir" 2>/dev/null; rm -rf "$data_dir"' EXIT

ASDF_DATA_DIR="$data_dir" PATH="$go_bin:$PATH" \
	asdf plugin test stringer "$plugin_dir" --asdf-tool-version 0.49.0 --asdf-plugin-gitref "$ref" "stringer -help"
