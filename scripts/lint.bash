#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

shellcheck --shell=bash --external-sources --source-path=lib/ \
	bin/* \
	lib/* \
	scripts/* \
	test/test_helper.bash

shfmt --language-dialect bash --diff \
	bin/* \
	lib/* \
	scripts/* \
	test/test_helper.bash

shfmt --language-dialect bats --diff test/*.bats
