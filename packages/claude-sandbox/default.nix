{ flake, inputs, pkgs, system, extraModules ? [ ], showBootLogs ? false, ... }:

flake.lib.mkAgentSandbox {
  inherit pkgs system extraModules showBootLogs;

  name = "claude-sandbox";

  guestModules = [
    {
      virtualisation.sharedDirectories.claude-config = {
        source = ''"$AGENT_SANDBOX_CONFIG_DIR"'';
        target = "/mnt/agent-sandbox/config/claude";
        securityModel = "none";
      };

      systemd.tmpfiles.rules = [
        "d /mnt/agent-sandbox/config 0755 root root -"
      ];
    }
  ];

  launcherScript = flake.lib.mkHarnessLauncherScript {
    sessionCommand = guestSystem: import ./session-wrapper.nix {
      inherit inputs;
      pkgs = import inputs.nixpkgs { system = guestSystem; };
      lib = inputs.nixpkgs.lib;
      agentSandboxShowMarkers = false;
    };
    extraInit = { emptyDir, ... }: ''
      config_dir="${emptyDir}"
    '';
    extraCaseArms = _: ''
      --config-dir=*)
        config_dir="''${1#--config-dir=}"
        shift
        ;;
    '';
    extraValidation = { coreutils, name, ... }: ''
      config_dir="$(${coreutils}/bin/realpath "$config_dir")"

      if [ ! -d "$config_dir" ]; then
        printf '${name}: config directory not found: %s\n' "$config_dir" >&2
        exit 1
      fi
    '';
    extraExports = _: ''
      export AGENT_SANDBOX_CONFIG_DIR="$config_dir"
    '';
  };
}
