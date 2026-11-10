{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    bachfmt = {
      url = "github:BachErik/bachfmt";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, bachfmt, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
      formatterFor = pkgs: bachfmt.lib.mkFormatter pkgs { langs = [ "nix" ]; };
    in
    {
      formatter = forAllSystems formatterFor;
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC { packages = [ (formatterFor pkgs) ]; };
      });
    };
}
