{
  # Per-repo toolchain + env, loaded automatically by direnv (`use flake` in
  # .envrc). Tasks live in the justfile; the Makefile is upstream's and is left
  # alone so the two stay interchangeable.
  #
  # The Go version is whatever the pinned nixpkgs rev ships, so flake.lock IS
  # the pin — `nix flake update` is the only thing that moves it.
  description = "clipse — clipboard manager TUI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAll = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAll (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              go
              gopls # language server
              gotools # goimports, godoc, ...
              golangci-lint # `just lint`; the repo pins it in .golangci.yml
              delve # dlv debugger
              just
            ];
            env = {
              # The wayland path (uinput + wl-clipboard) is cgo-free, and it is
              # the one this machine runs — `make install` builds it and CI sets
              # the same value. The x11/darwin targets need cgo plus X11,
              # xfixes and robotgo's tesseract/leptonica headers, none of which
              # are in this shell; build those with make on a host that has them.
              CGO_ENABLED = "0";
            };
            shellHook = ''
              # Keep `go install` inside the checkout instead of writing to the
              # ambient GOBIN (~/.local/bin), which every repo on the machine
              # shares. The repo ROOT, not $PWD, so a `nix develop` from a
              # subdirectory does not scatter .bin trees.
              _root=$(git rev-parse --show-toplevel 2>/dev/null || printf %s "$PWD")
              export GOBIN="$_root/.bin"
              export PATH="$GOBIN:$PATH"
              unset _root
            '';
          };
        }
      );

      packages = forAll (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          # Same build the release workflow ships for linux: wayland tag, no
          # cgo. Exists so the dotfiles flake can install clipse declaratively.
          default = pkgs.buildGoModule {
            pname = "clipse";
            # Hardcoded in cmd/root.go; there is no ldflags injection to hook.
            version = "1.2.1";

            src = nixpkgs.lib.fileset.toSource {
              root = ./.;
              fileset = nixpkgs.lib.fileset.unions [
                ./go.mod
                ./go.sum
                ./main.go
                ./app
                ./cmd
                ./config
                ./display
                ./handlers
                ./search
                ./shell
                ./tests
                ./utils
              ];
            };

            vendorHash = "sha256-D3j5/WmQqwZDG8+WPyi4VR1sSHj7dLi2JEGvBjHjYzQ=";

            tags = [ "wayland" ];
            env.CGO_ENABLED = "0";

            # The x11 handler's cgo file is compiled under `!cgo` too, and the
            # test tree drives a real clipboard; neither survives the sandbox.
            doCheck = false;

            meta = {
              description = "Clipboard manager TUI";
              homepage = "https://github.com/savedra1/clipse";
              license = nixpkgs.lib.licenses.mit;
              mainProgram = "clipse";
            };
          };
        }
      );
    };
}
