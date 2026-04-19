{ flake, pkgs }:
pkgs.mkShell {
  # Add build dependencies
  packages = [
    (let
      optionalFlag = name: value: pkgs.lib.optionalString (value != null) "--${name} ${pkgs.lib.escapeShellArg (toString value)}";
      pkg = flake.packages.${pkgs.stdenv.hostPlatform.system}.opencode-sandbox;
      envFile = pkgs.writeText "opencode-sandbox-env" ''
        OPENCODE_ENABLE_EXA=1
      '';
      configDir = let
        opencode-json = pkgs.writeText "opencode.json" (builtins.toJSON {
          "$schema" = "https://opencode.ai/config.json";
          autoupdate = false;
          permission = {
            # sandboxed as root, go wild
            "*" = "allow";
          };
          default_agent = "plan";
        });
      in pkgs.runCommand "opencode-sandbox-config" {} ''
        mkdir -p "$out"
        cp ${opencode-json} "$out/opencode.json"
      '';
      dataDir = null;
      cacheDir = null;
    in pkgs.writeShellScriptBin "opencode-sandbox" ''
      exec ${pkgs.lib.getExe (pkg.override {
        extraModules = [];
        showBootLogs = false;
      })} \
        ${optionalFlag "env-file" envFile} \
        ${optionalFlag "config-dir" configDir} \
        ${optionalFlag "data-dir" dataDir} \
        ${optionalFlag "cache-dir" cacheDir} \
        "$@"
    '')
  ];

  # Add environment variables
  env = { };

  # Load custom bash code
  shellHook = ''

  '';
}
