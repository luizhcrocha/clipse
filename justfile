# Tasks. `just` runs inside the direnv shell, so the pinned toolchain and env
# from flake.nix are already in scope.
#
# These mirror the upstream Makefile, which is left untouched — `make wayland`
# and `just wayland` do the same thing. The build tag picks the clipboard
# backend, so there is no tag-free build: without one, robotgo needs cgo and
# X11/tesseract headers this shell does not carry. x11/darwin therefore only
# build on a host that has those; wayland is what this machine runs.

binary := "clipse"

default:
    @just --list

# Wayland build — uinput + wl-clipboard, no cgo.
wayland:
    CGO_ENABLED=0 go build -tags wayland -o {{ binary }}

alias build := wayland

# X11 build — needs cgo and the X11 headers.
x11:
    go build -tags linux -o {{ binary }}

# macOS build — needs cgo.
darwin:
    go build -tags darwin -o {{ binary }}

# Build the wayland binary and run it.
run: wayland
    ./{{ binary }}

# Drop the binary in $INSTALL_DIR (default ~/.local/bin), same as `make install`.
install: wayland
    install -m 755 {{ binary }} "${INSTALL_DIR:-$HOME/.local/bin}"

clean:
    go clean
    rm -f {{ binary }}

# The `ci` tag stubs out the cgo handlers, as the GitHub workflow does.
test:
    go test -tags ci -v ./...

lint:
    go vet -tags ci ./...
    golangci-lint run --build-tags ci
