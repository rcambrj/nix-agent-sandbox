{ flake, ... }:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs."claude-sandbox";

  pkgsFor = flake.mkPackagesFor pkgs;
  pkg = pkgsFor.claude-sandbox;
in
{
  options.programs."claude-sandbox" = {
    enable = lib.mkEnableOption "the claude sandbox launcher";

    extraModules = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.attrs lib.types.unspecified);
      default = [ ];
      description = ''
        Additional guest NixOS modules to include in the claude sandbox VM.

        Each entry can be:
        - An attrset (a plain NixOS module): `{ ... }`
        - A function that receives the guest system's pkgs and returns an attrset: `pkgs: { ... }`
      '';
    };

    showBootLogs = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Show guest kernel and systemd boot logs on the sandbox console.";
    };

    envFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to an env file sourced inside the sandbox VM before claude starts.";
    };

    configDir = lib.mkOption {
      type = lib.types.path;
      default = pkg.emptyDir;
      defaultText = lib.literalExpression "claude-sandbox.emptyDir";
      description = ''
        Host directory mounted inside the VM and exposed to claude via CLAUDE_CONFIG_DIR.
        Defaults to an empty directory.
      '';
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        Custom claude-sandbox package to use. When null, uses the flake's built package
        with extraModules and showBootLogs applied. When set, this package is used as-is.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (flake.lib.mkWrappedAgentSandbox {
        inherit pkgs;
        name = "claude-sandbox";
        package = if cfg.package != null then cfg.package else pkg.override {
          extraModules = cfg.extraModules;
          showBootLogs = cfg.showBootLogs;
        };
        flags = {
          env-file = cfg.envFile;
          config-dir = cfg.configDir;
        };
      })
    ];
  };
}
