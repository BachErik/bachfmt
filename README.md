# bachfmt

One formatting command for all my projects, built on [treefmt](https://treefmt.com).

bachfmt has two jobs:

1. **Respect the project.** If a repo brings its own formatter setup (treefmt config, Prettier in
   `package.json`, Spotless in Gradle, a `stylua.toml`, …), that setup wins. Always.
2. **Fill the gap with a house style.** Only where a project has no opinion (and only where I opted
   in) does bachfmt fall back to the style defined in this repo.

The house style lives in plain, tool-native config files (`house/`). Nix is a convenient way to run
it, never a requirement: anyone can format a repo that uses the house style with the tools'
own CLIs or editor plugins.

## Status

| Piece                                          | State      |
| ---------------------------------------------- | ---------- |
| House style config files (`house/`)            | ✅ done    |
| `lib.mkFormatter` (Nix variant)                | ✅ done    |
| Home Manager module (Zed format-on-save)       | ✅ done    |
| `templates.nix`                                | ✅ done    |
| `bachfmt` CLI, stage 1 only (shell script)     | ✅ interim |
| Go CLI: full detection chain, fallback, `init` | 🚧 next    |
| VSCode integration                             | 📋 planned |

## How a file gets formatted

For every file, bachfmt walks this chain and stops at the first match:

```
1. The project has its own orchestrator          → use it, touch nothing else
   (treefmt.toml, a flake `formatter`, Spotless in build.gradle)

2. The project has an opinion about this tool    → that tool, with the project's config
   (dependency OR config file: prettier in package.json / .prettierrc,
    biome.json, stylua.toml, rustfmt.toml, [tool.ruff], Cargo.toml, …)
   — and the project's own binary where possible (node_modules/.bin/prettier)

3. Nothing of the above                          → house style
   (only in opted-in repos, see below)
```

A formatter detected in stage 2 claims every file type it can handle, not just "its" language: a
project using Prettier also gets its Markdown, JSON and YAML formatted by its Prettier.

### Opt-in for the fallback

Stage 3 never runs in a repo I didn't opt into, so contributing to someone else's project never
produces a diff full of my style. Opt-in is:

- a central allowlist (e.g. my own GitHub orgs), plus
- a git-local override: `git config --local bachfmt.enable true|false` (lives in `.git/config`,
  never committed)

> The interim shell CLI only implements stage 1. Stages 2 and 3 and the opt-in arrive with the Go
> CLI.

## House style

Community defaults wherever possible, own opinions only where there is no standard. Line width is
**100** everywhere. Indentation comes from `.editorconfig` where the tool supports it.

| Language                                   | Formatter         | Style                                                  |
| ------------------------------------------ | ----------------- | ------------------------------------------------------ |
| Nix                                        | nixfmt            | official style                                         |
| Lua                                        | StyLua            | 4 spaces, double quotes, always call parentheses       |
| QML                                        | qmlformat         | 4 spaces, no wrapping, semicolons only if required     |
| JS/TS/Vue, CSS, HTML, JSON, YAML, Markdown | Prettier          | Prettier defaults, width 100                           |
| TOML                                       | taplo             | defaults, width 100                                    |
| Shell                                      | shfmt             | 4 spaces                                               |
| Python                                     | ruff format       | Black-compatible, width 100                            |
| Go                                         | gofmt             | —                                                      |
| Rust                                       | rustfmt           | edition 2024                                           |
| Kotlin                                     | ktfmt             | kotlinlang style                                       |
| Java                                       | Spotless (Gradle) | google-java-format AOSP — see `house/spotless.gradle*` |
| C/C++                                      | clang-format      | LLVM base, 2 spaces, width 100                         |
| SQL                                        | sql-formatter     | PostgreSQL dialect                                     |
| Dockerfile                                 | dockerfmt         | defaults                                               |
| Typst                                      | typstyle          | width 100                                              |

All formatters write LF line endings, and `.gitattributes` enforces LF in every checkout.

Java and Kotlin inside Gradle projects are formatted by Spotless (`./gradlew spotlessApply`), not
on save.

## Usage

### Nix variant: a flake repo

For repos where everyone uses Nix anyway (e.g. a NixOS config). The repo only commits
`.editorconfig`, `.gitattributes` and its `flake.nix`; all formatter settings come from this flake,
pinned via `flake.lock`.

```nix
{
  inputs.bachfmt = {
    url = "github:BachErik/bachfmt";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, bachfmt, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      fmt = bachfmt.lib.mkFormatter pkgs {
        langs = [ "nix" "lua" "markdown" ];
        # extraIncludes.shell = [ "bin/*" ];  # repo-specific globs
        # settings = { };                     # merged into the treefmt settings
      };
    in {
      formatter.x86_64-linux = fmt;                          # nix fmt
      devShells.x86_64-linux.default = pkgs.mkShellNoCC {   # treefmt on PATH via direnv
        packages = [ fmt ];
      };
      checks.x86_64-linux.formatting = fmt.check ./.;       # nix flake check
    };
}
```

Or start from the template:

```sh
nix flake init -t github:BachErik/bachfmt#nix
direnv allow
```

Update the style deliberately with `nix flake update bachfmt`.

Available languages: `nix lua qml js css html json yaml markdown toml shell python go rust kotlin
c sql docker typst` (`bachfmt.lib.languages`).

### Home Manager

```nix
{
  imports = [ inputs.bachfmt.homeManagerModules.default ];

  programs.bachfmt.enable = true;
  # programs.bachfmt.zed.languages = [ "Nix" "Lua" "QML" "Shell Script" ];
}
```

Installs `bachfmt` and, if Zed is enabled, sets `bachfmt --stdin {buffer_path}` as the
format-on-save formatter for the listed languages.

### CLI

```sh
bachfmt                  # format the current repo
bachfmt --stdin <path>   # read a buffer on stdin, print it formatted (for editors)
```

`--stdin` never fails an editor save: if no formatter applies or one errors, the buffer comes back
unchanged.

### Portable variant

The plain config files are available as a package:

```sh
nix build github:BachErik/bachfmt#house   # → result/ with all house config files
```

`bachfmt init` (Go CLI) will copy the files a repo needs into it, so contributors without Nix get
the same result.

## Layout

```
house/           tool-native config files = the house style
lib/default.nix  formatters, languages, mkFormatter
pkgs/            interim CLI (shell)
hm-module.nix    Home Manager module
templates/nix/   flake template (Nix variant)
```

## License

[MIT](LICENSE)
