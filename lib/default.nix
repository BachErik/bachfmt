# bachfmt library: the house style as treefmt settings.
#
#   bachfmt.lib.mkFormatter pkgs { langs = [ "nix" "lua" ]; }
#
# returns a treefmt wrapper (pkgs.treefmt.withConfig) that carries every
# tool and every config file it needs, so a repo only has to commit
# `.editorconfig` and its flake.nix.
{ lib, house }:
let
  # qmlformat has no "path to settings file" flag, so the settings live here
  # and become both `.qmlformat.ini` (portable) and CLI flags (Nix variant).
  qmlSettings = {
    IndentWidth = 4;
    UseTabs = false;
    # No forced line wrapping: it would split template strings mid-expression
    MaxColumnWidth = -1;
    NewlineType = "unix";
    # Keep the semicolon-free JS style; only add them where required
    SemicolonRule = "essential";
    # Blank line between sibling objects and between functions
    ObjectsSpacing = true;
    FunctionsSpacing = true;
    NormalizeOrder = false;
    GroupAttributesTogether = false;
    SortImports = false;
    SingleLineEmptyObjects = false;
  };

  qmlFlags = [
    "--ignore-settings"
    "--indent-width=${toString qmlSettings.IndentWidth}"
    "--column-width=${toString qmlSettings.MaxColumnWidth}"
    "--newline=${qmlSettings.NewlineType}"
    "--semicolon-rule=${qmlSettings.SemicolonRule}"
  ]
  ++ lib.optional qmlSettings.UseTabs "--tabs"
  ++ lib.optional qmlSettings.ObjectsSpacing "--objects-spacing"
  ++ lib.optional qmlSettings.FunctionsSpacing "--functions-spacing"
  ++ lib.optional qmlSettings.NormalizeOrder "--normalize"
  ++ lib.optional qmlSettings.GroupAttributesTogether "--group-attributes-together"
  ++ lib.optional qmlSettings.SortImports "--sort-imports"
  ++ lib.optional qmlSettings.SingleLineEmptyObjects "--single-line-empty-objects";

  # Each formatter: the packages it needs and its treefmt settings
  # (without `includes`; those come from the languages below).
  formatters = pkgs: {
    nixfmt = {
      packages = [ pkgs.nixfmt ];
      settings.command = "nixfmt";
    };

    stylua = {
      packages = [ pkgs.stylua ];
      settings = {
        command = "stylua";
        options = [
          "--config-path"
          "${house}/.stylua.toml"
        ];
      };
    };

    qmlformat = {
      packages = [ pkgs.kdePackages.qtdeclarative ];
      settings = {
        command = "qmlformat";
        options = [ "-i" ] ++ qmlFlags;
      };
    };

    prettier = {
      packages = [ pkgs.prettier ];
      settings = {
        command = "prettier";
        # Width and indentation are set explicitly in .prettierrc.json: with
        # `treefmt --stdin` the buffer is formatted as a temp file in /tmp,
        # where Prettier can't see the repo's .editorconfig.
        options = [
          "--write"
          "--config"
          "${house}/.prettierrc.json"
        ];
      };
    };

    taplo = {
      packages = [ pkgs.taplo ];
      settings = {
        command = "taplo";
        options = [
          "format"
          "--config"
          "${house}/.taplo.toml"
        ];
      };
    };

    shfmt = {
      packages = [ pkgs.shfmt ];
      settings = {
        command = "shfmt";
        # Explicit, so extensionless scripts (bin/*) get 4 spaces too.
        # (Explicit flags make shfmt ignore .editorconfig.)
        options = [
          "-w"
          "--indent=4"
        ];
      };
    };

    ruff-format = {
      packages = [ pkgs.ruff ];
      settings = {
        command = "ruff";
        options = [
          "format"
          "--config"
          "${house}/ruff.toml"
        ];
      };
    };

    gofmt = {
      packages = [ pkgs.go ];
      settings = {
        command = "gofmt";
        options = [ "-w" ];
      };
    };

    rustfmt = {
      packages = [ pkgs.rustfmt ];
      settings = {
        command = "rustfmt";
        # Called per file, so rustfmt can't read the edition from Cargo.toml
        options = [
          "--edition"
          "2024"
          "--config"
          "newline_style=Unix"
        ];
      };
    };

    ktfmt = {
      packages = [ pkgs.ktfmt ];
      settings = {
        command = "ktfmt";
        options = [ "--kotlinlang-style" ];
      };
    };

    clang-format = {
      packages = [ pkgs.clang-tools ];
      settings = {
        command = "clang-format";
        options = [
          "-i"
          "--style=file:${house}/.clang-format"
        ];
      };
    };

    sql-formatter = {
      packages = [ ];
      settings = {
        # sql-formatter only takes one file per call
        command = pkgs.writeShellScript "sql-formatter-fix" ''
          for file in "$@"; do
            ${lib.getExe pkgs.sql-formatter} --fix --language postgresql "$file"
          done
        '';
      };
    };

    dockerfmt = {
      packages = [ pkgs.dockerfmt ];
      settings = {
        command = "dockerfmt";
        options = [
          "-w"
          "-n"
        ];
      };
    };

    typstyle = {
      packages = [ pkgs.typstyle ];
      settings = {
        command = "typstyle";
        options = [
          "-i"
          "--line-width"
          "100"
          "--line-ending"
          "lf"
        ];
      };
    };
  };

  # Language -> formatter + file globs. Several languages can share one
  # formatter (everything Prettier handles), their globs are merged.
  languages = {
    nix = {
      formatter = "nixfmt";
      includes = [ "*.nix" ];
    };
    lua = {
      formatter = "stylua";
      includes = [ "*.lua" ];
    };
    qml = {
      formatter = "qmlformat";
      includes = [ "*.qml" ];
    };
    js = {
      formatter = "prettier";
      includes = [
        "*.js"
        "*.mjs"
        "*.cjs"
        "*.jsx"
        "*.ts"
        "*.mts"
        "*.cts"
        "*.tsx"
        "*.vue"
      ];
    };
    css = {
      formatter = "prettier";
      includes = [
        "*.css"
        "*.scss"
        "*.less"
      ];
    };
    html = {
      formatter = "prettier";
      includes = [ "*.html" ];
    };
    json = {
      formatter = "prettier";
      includes = [
        "*.json"
        "*.jsonc"
        "*.json5"
      ];
    };
    yaml = {
      formatter = "prettier";
      includes = [
        "*.yaml"
        "*.yml"
      ];
    };
    markdown = {
      formatter = "prettier";
      includes = [
        "*.md"
        "*.mdx"
      ];
    };
    toml = {
      formatter = "taplo";
      includes = [ "*.toml" ];
    };
    shell = {
      formatter = "shfmt";
      includes = [
        "*.sh"
        "*.bash"
      ];
    };
    python = {
      formatter = "ruff-format";
      includes = [
        "*.py"
        "*.pyi"
      ];
    };
    go = {
      formatter = "gofmt";
      includes = [ "*.go" ];
    };
    rust = {
      formatter = "rustfmt";
      includes = [ "*.rs" ];
    };
    kotlin = {
      formatter = "ktfmt";
      includes = [
        "*.kt"
        "*.kts"
      ];
    };
    c = {
      formatter = "clang-format";
      includes = [
        "*.c"
        "*.h"
        "*.cc"
        "*.cpp"
        "*.cxx"
        "*.hh"
        "*.hpp"
        "*.ino"
      ];
    };
    sql = {
      formatter = "sql-formatter";
      includes = [ "*.sql" ];
    };
    docker = {
      formatter = "dockerfmt";
      includes = [
        "Dockerfile"
        "*/Dockerfile"
        "Dockerfile.*"
        "*/Dockerfile.*"
        "*.Dockerfile"
        "*.dockerfile"
        "Containerfile"
        "*/Containerfile"
      ];
    };
    typst = {
      formatter = "typstyle";
      includes = [
        "*.typ"
        "*.typst"
      ];
    };
  };
in
{
  inherit qmlSettings;

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
      allFormatters = formatters pkgs;
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
      runtimeInputs = lib.concatMap (f: allFormatters.${f}.packages) usedFormatters;
      settings = lib.mkMerge [
        {
          # The repo root is where flake.nix lives (the Nix variant always has one)
          tree-root-file = lib.mkDefault "flake.nix";
          on-unmatched = lib.mkDefault "info";
          excludes = [
            "*.lock"
            "*.min.*"
            "node_modules/*"
          ];
          formatter = lib.genAttrs usedFormatters (
            f: allFormatters.${f}.settings // { includes = includesFor f; }
          );
        }
        settings
      ];
    };
}
