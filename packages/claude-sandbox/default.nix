{ flake, inputs, pkgs, system, extraModules ? [ ], showBootLogs ? false, enableSshServer ? true, sshMaxAttempts ? 15, ... }:

flake.lib.mkAgentSandbox {
  inherit pkgs system extraModules showBootLogs enableSshServer sshMaxAttempts;

  name = "claude-sandbox";

  extraShares = [
    {
      tag = "claude-config";
      sourceEnvVar = "AGENT_SANDBOX_CONFIG_DIR";
      mountPoint = "/mnt/agent-sandbox/config/claude";
    }
  ];

  guestModules = [
    {
      systemd.tmpfiles.rules = [
        "d /mnt/agent-sandbox/config 0755 root root -"
      ];

      systemd.services."agent-sandbox-mount-claude-share" = {
        unitConfig.DefaultDependencies = false;
        wantedBy = [ "multi-user.target" ];
        after = [ "mnt-agent-sandbox-control.mount" ];
        serviceConfig.Type = "oneshot";
        script = ''
          mount_virtiofs() {
            tag="$1"
            target="$2"

            for _ in 1 2 3 4 5 6 7 8 9 10; do
              if grep -qs " $target " /proc/mounts; then
                return 0
              fi

              if mount -t virtiofs "$tag" "$target" >/dev/null 2>&1; then
                return 0
              fi

              sleep 1
            done

            echo "failed to mount virtiofs tag '$tag' on '$target'" >&2
            return 1
          }

          mkdir -p /mnt/agent-sandbox/config/claude
          mount_virtiofs claude-config /mnt/agent-sandbox/config/claude
        '';
      };
    }
  ];

  launcherScript = flake.lib.mkHarnessLauncherScript {
    sessionCommand = { guestSystem, ... }: pkgs.writeShellScriptBin "claude-wrapper" ''
      mkdir -p /mnt/agent-sandbox/config/claude

      for _ in 1 2 3 4 5 6 7 8 9 10; do
        if grep -qs " /mnt/agent-sandbox/config/claude " /proc/mounts; then
          break
        fi
        mount -t virtiofs claude-config /mnt/agent-sandbox/config/claude >/dev/null 2>&1 || true
        sleep 1
      done

      if ! grep -qs " /mnt/agent-sandbox/config/claude " /proc/mounts; then
        echo "required mount not ready: /mnt/agent-sandbox/config/claude (claude-config)" >&2
        exit 1
      fi

      export CLAUDE_CONFIG_DIR=/mnt/agent-sandbox/config/claude

      exec ${pkgs.lib.getExe inputs.numtide-llm-agents.packages.${guestSystem}.claude-code} "$@"
    '';
    extraFlags = {
      config-dir = "config_dir";
    };
    extraFinalize = { coreutils, name, emptyDir, ... }: ''
      if [ -z "''${config_dir:-}" ] || [ "''${config_dir}" = "${emptyDir}" ]; then
        printf '${name}: --config-dir is required and must be a writable host directory\n' >&2
        exit 1
      fi

      config_dir="$(${coreutils}/bin/realpath "$config_dir")"

      if [ ! -d "$config_dir" ]; then
        printf '${name}: config directory not found: %s\n' "$config_dir" >&2
        exit 1
      fi

      if [ ! -w "$config_dir" ]; then
        printf '${name}: config directory is not writable: %s\n' "$config_dir" >&2
        exit 1
      fi

      export AGENT_SANDBOX_CONFIG_DIR="$config_dir"
    '';
  };
}
