# Home Manager module: installs `bachfmt` and wires it into Zed.
# (Global fallback + opt-in allowlist arrive together with the Go CLI.)
self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.bachfmt;
  bachfmt = self.packages.${pkgs.stdenv.hostPlatform.system}.bachfmt;
in
{
  options.programs.bachfmt = {
    enable = lib.mkEnableOption "bachfmt";

    zed = {
      enable = lib.mkEnableOption "bachfmt as Zed's on-save formatter" // {
        default = config.programs.zed-editor.enable or false;
        defaultText = lib.literalExpression "config.programs.zed-editor.enable";
      };

      languages = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "Nix"
          "Lua"
          "QML"
          "Shell Script"
        ];
        description = ''
          Zed language names that get `bachfmt --stdin` as formatter.
          Only list languages where Zed has no good formatter of its own:
          for anything else bachfmt hands the buffer back unchanged outside
          projects with their own treefmt.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { home.packages = [ bachfmt ]; }

      (lib.mkIf cfg.zed.enable {
        programs.zed-editor = {
          extraPackages = [ bachfmt ];
          userSettings.languages = lib.genAttrs cfg.zed.languages (_: {
            format_on_save = "on";
            formatter.external = {
              command = "bachfmt";
              arguments = [
                "--stdin"
                "{buffer_path}"
              ];
            };
          });
        };
      })
    ]
  );
}
