{ flake, pkgs, system, extraModules ? [ ], showBootLogs ? false, ... }:

flake.lib.mkAgentSandbox {
  inherit pkgs system extraModules showBootLogs;

  name = "opencode-sandbox";

  guestModules = [
    ./guest-opencode.nix
  ];

  launcherScript = flake.lib.mkHarnessLauncherScript {
    sessionCommand = "opencode-sandbox-session";
    extraInit = { emptyDir, ... }: ''
      config_dir="${emptyDir}"
      data_dir="${emptyDir}"
      cache_dir="${emptyDir}"
      has_data_dir=0
      has_cache_dir=0
    '';
    extraCaseArms = _: ''
      --config-dir=*)
        config_dir="''${1#--config-dir=}"
        shift
        ;;
      --data-dir=*)
        data_dir="''${1#--data-dir=}"
        has_data_dir=1
        shift
        ;;
      --cache-dir=*)
        cache_dir="''${1#--cache-dir=}"
        has_cache_dir=1
        shift
        ;;
    '';
    extraValidation = { coreutils, name, ... }: ''
      config_dir="$(${coreutils}/bin/realpath "$config_dir")"

      if [ ! -d "$config_dir" ]; then
        printf '${name}: config directory not found: %s\n' "$config_dir" >&2
        exit 1
      fi

      if [ "$has_data_dir" -eq 1 ]; then
        data_dir="$(${coreutils}/bin/realpath "$data_dir")"
        if [ ! -d "$data_dir" ]; then
          printf '${name}: data directory not found: %s\n' "$data_dir" >&2
          exit 1
        fi
      fi

      if [ "$has_cache_dir" -eq 1 ]; then
        cache_dir="$(${coreutils}/bin/realpath "$cache_dir")"
        if [ ! -d "$cache_dir" ]; then
          printf '${name}: cache directory not found: %s\n' "$cache_dir" >&2
          exit 1
        fi
      fi
    '';
    extraControl = _: ''
      if [ "$has_data_dir" -eq 1 ]; then
        : > "$control_dir/opencode-has-data-dir"
      fi

      if [ "$has_cache_dir" -eq 1 ]; then
        : > "$control_dir/opencode-has-cache-dir"
      fi
    '';
    extraExports = _: ''
      export AGENT_SANDBOX_CONFIG_DIR="$config_dir"
      export AGENT_SANDBOX_DATA_DIR="$data_dir"
      export AGENT_SANDBOX_CACHE_DIR="$cache_dir"
    '';
  };
}
