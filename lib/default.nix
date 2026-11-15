# bachfmt library: the house style as treefmt settings.
#
#   bachfmt.lib.mkFormatter pkgs { langs = [ "nix" "lua" ]; }
#
# returns a treefmt wrapper (pkgs.treefmt.withConfig) that carries every
# tool and every config file it needs, so a repo only has to commit
# `.editorconfig` and its flake.nix.
#
# The formatter table itself lives in house/formatters.json, shared with
# the Go CLI. This file only turns it into treefmt settings.
{ lib, house, ... }:
let
  table = builtins.fromJSON (builtins.readFile "${house}/formatters.json");

  expand = builtins.replaceStrings [ "{house}" ] [ "${house}" ];

  inherit (table) formatters languages excludes;

  # "kdePackages.qtdeclarative" -> pkgs.kdePackages.qtdeclarative
  packageOf = pkgs: f: lib.getAttrFromPath (lib.splitString "." f.nixPackage) pkgs;

  # treefmt options for file mode: base + write + house (files come last,
  # treefmt appends them). `stdin` is only used by the Go CLI.
  optionsOf = f: (f.base or [ ]) ++ (f.write or [ ]) ++ map expand (f.house or [ ]);

  # treefmt settings for one formatter
  settingsOf =
    pkgs: f:
    if f.perFile or false then
      {
        # The tool takes one file per call: wrap it in a loop
        command = pkgs.writeShellScript "${f.command}-per-file" ''
          for file in "$@"; do
            ${lib.getExe' (packageOf pkgs f) f.command} ${lib.escapeShellArgs (optionsOf f)} "$file"
          done
        '';
      }
    else
      {
        inherit (f) command;
      }
      // lib.optionalAttrs (optionsOf f != [ ]) { options = optionsOf f; };
in
{
  # All language names mkFormatter understands
  languages = builtins.attrNames languages;

  /**
    Build the house-style treefmt wrapper.

    mkFormatter pkgs {
      langs = [ "nix" "lua" ];        # default: every language
      extraIncludes = { shell = [ "bin/*" ]; };  # repo-specific globs
      settings = { };                 # merged into the treefmt settings
    }
  */
  mkFormatter =
    pkgs:
    {
      langs ? builtins.attrNames languages,
      extraIncludes ? { },
      settings ? { },
    }:
    let
      unknown = lib.subtractLists (builtins.attrNames languages) (
        langs ++ builtins.attrNames extraIncludes
      );
      selected = lib.genAttrs langs (l: languages.${l});
      usedFormatters = lib.unique (lib.mapAttrsToList (_: l: l.formatter) selected);

      includesFor =
        name:
        lib.concatLists (
          lib.mapAttrsToList (
            lang: l: lib.optionals (l.formatter == name) (l.includes ++ (extraIncludes.${lang} or [ ]))
          ) selected
        );
    in
    assert lib.assertMsg (unknown == [ ])
      "bachfmt: unknown language(s): ${toString unknown}. Known: ${toString (builtins.attrNames languages)}";
    pkgs.treefmt.withConfig {
      name = "bachfmt-treefmt";
      runtimeInputs = map (f: packageOf pkgs formatters.${f}) usedFormatters;
      settings = lib.mkMerge [
        {
          # The repo root is where flake.nix lives (the Nix variant always has one)
          tree-root-file = lib.mkDefault "flake.nix";
          on-unmatched = lib.mkDefault "info";
          inherit excludes;
          formatter = lib.genAttrs usedFormatters (
            f: settingsOf pkgs formatters.${f} // { includes = includesFor f; }
          );
        }
        settings
      ];
    };
}
