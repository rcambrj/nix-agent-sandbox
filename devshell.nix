{ flake, pkgs }:
pkgs.mkShell {
  packages = [
    (flake.lib.mkWrappedOpencodeSandbox {
      inherit pkgs;
      name = "opencode-sandbox-dev";
      package = flake.packages.${pkgs.stdenv.hostPlatform.system}.opencode-sandbox.override {
        extraModules = [];
        showBootLogs = false;
      };
      envFile = pkgs.writeText "opencode-sandbox-env" ''
        OPENCODE_ENABLE_EXA=1
      '';
      configDir = let
        opencode-json = pkgs.writeText "opencode.json" (builtins.toJSON {
          "$schema" = "https://opencode.ai/config.json";
          autoupdate = false;
          permission = {
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
    })
  ];

  env = { };
  shellHook = "";
}
