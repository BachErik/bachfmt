{
  description = "bachfmt: BachErik's house formatting style on top of treefmt";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      bachfmtLib = import ./lib {
        inherit lib;
        house = ./house;
      };
    in
    {
      lib = {
        inherit (bachfmtLib) languages qmlSettings;
        # bachfmt.lib.mkFormatter pkgs { langs = [ ... ]; }
        inherit (bachfmtLib) mkFormatter;
      };

      packages = forAllSystems (pkgs: {
        # Interim CLI (stage 1 only), replaced by the Go version later
        bachfmt = pkgs.writeShellApplication {
          name = "bachfmt";
          runtimeInputs = [ pkgs.coreutils ];
          text = builtins.readFile ./pkgs/bachfmt.sh;
        };

        # The portable house style as plain files (what `bachfmt init` will copy)
        house = pkgs.runCommand "bachfmt-house" { } ''
          cp -r ${./house} $out
          chmod -R u+w $out
          cp ${
            pkgs.writeText "qmlformat.ini" (lib.generators.toINI { } { General = bachfmtLib.qmlSettings; })
          } $out/.qmlformat.ini
        '';

        default = self.packages.${pkgs.stdenv.hostPlatform.system}.bachfmt;
      });

      # Dogfooding: this repo formats itself with its own house style
      formatter = forAllSystems (
        pkgs:
        bachfmtLib.mkFormatter pkgs {
          langs = [
            "nix"
            "lua"
            "shell"
            "markdown"
            "json"
            "toml"
          ];
        }
      );

      checks = forAllSystems (pkgs: {
        formatting = self.formatter.${pkgs.stdenv.hostPlatform.system}.check self;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = [ self.formatter.${pkgs.stdenv.hostPlatform.system} ];
        };
      });

      homeManagerModules.default = import ./hm-module.nix self;

      templates.nix = {
        path = ./templates/nix;
        description = "bachfmt house style, Nix variant (flake + .editorconfig only)";
      };
    };
}
