<div align="center">

# asdf-stringer [![Build](https://github.com/douglasgomes98/asdf-stringer/actions/workflows/build.yml/badge.svg)](https://github.com/douglasgomes98/asdf-stringer/actions/workflows/build.yml) [![Lint](https://github.com/douglasgomes98/asdf-stringer/actions/workflows/lint.yml/badge.svg)](https://github.com/douglasgomes98/asdf-stringer/actions/workflows/lint.yml)

[stringer](https://pkg.go.dev/golang.org/x/tools/cmd/stringer) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Versions](#versions)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

stringer publishes no binaries, so this plugin builds it from source with `go install`.

- `bash`, `curl`.
- Go, active in the directory where you run `asdf install`. With asdf:

```shell
asdf plugin add golang
asdf install golang 1.25.5
```

# Install

Plugin:

```shell
asdf plugin add stringer https://github.com/douglasgomes98/asdf-stringer.git
```

stringer, pinned per project in `.tool-versions` (list `golang` before `stringer`, so Go is
installed first):

```
golang 1.25.5
stringer 0.49.0
```

```shell
asdf install

# go generate now runs the pinned stringer
stringer -help
```

Or a single version:

```shell
asdf list all stringer
asdf install stringer 0.49.0
asdf set stringer 0.49.0
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Versions

A version is a [`golang.org/x/tools`](https://pkg.go.dev/golang.org/x/tools?tab=versions) tag
without the leading `v` (`v0.49.0` is accepted too). The list comes from the Go module proxy,
so no GitHub token is needed.

stringer is compiled with the Go that is active when you install it, and the plugin never
downloads another Go toolchain. Each `golang.org/x/tools` release has a minimum Go:

| stringer | Go |
| --- | --- |
| 0.49.0 | Go 1.25 or newer |
| 0.50.0 and later | Go 1.26 or newer |

On an older Go the install fails with `requires go >= ...` and nothing is installed. Pick a
version your Go can build, or update Go first. `asdf latest stringer` is the newest tag, which may
need a newer Go than yours.

Changing Go later does not rebuild stringer; run `asdf uninstall stringer <version>` and
`asdf install` again if you want it rebuilt.

# Contributing

Tests need [bats](https://github.com/bats-core/bats-core), asdf and Go 1.25 (on `PATH`, in
`GO125_BIN`, or as `golang 1.25.5` in asdf). Linting needs shellcheck and shfmt.

```shell
bats test
scripts/lint.bash
```

# License

See [LICENSE](LICENSE) © [Douglas Gomes](https://github.com/douglasgomes98/)
