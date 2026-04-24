{ inputs, lib, agentSandboxShowMarkers ? false, pkgs, ... }:

let
  claudeCode = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;

  session = pkgs.writeShellScriptBin "claude-sandbox-session" ''
    set -euo pipefail

    export HOME=/root
    export SHELL=${pkgs.bashInteractive}/bin/bash
    export CLAUDE_CONFIG_DIR=/mnt/agent-sandbox/config/claude

    cd /workspace

    if [ -r /mnt/agent-sandbox/control/agent-env ]; then
      set -a
      source /mnt/agent-sandbox/control/agent-env
      set +a
    fi

    declare -a args=()
    if [ -r /mnt/agent-sandbox/control/agent-args ]; then
      mapfile -t args < /mnt/agent-sandbox/control/agent-args
    fi

    command=( ${lib.getExe claudeCode} "''${args[@]}" )
    printf -v command_line '%q ' "''${command[@]}"
    command_line="''${command_line% }"

    printf 'claude-sandbox: cwd=%s\n' "$PWD"
    printf 'claude-sandbox: command=%s\n' "$command_line"

    {
      printf 'cwd=%s\n' "$PWD"
      printf 'command=%s\n' "$command_line"
      printf 'CLAUDE_CONFIG_DIR=%s\n' "$CLAUDE_CONFIG_DIR"
    } | ${pkgs.systemd}/bin/systemd-cat -t claude-sandbox-session

    ${lib.optionalString agentSandboxShowMarkers ''
      printf '\n=== Starting claude in /workspace ===\n'
      printf '=== claude args: %s ===\n\n' "''${args[*]:-(interactive)}"
    ''}

    set +e
    ${pkgs.bashInteractive}/bin/bash -l -c ${lib.escapeShellArg "${lib.getExe claudeCode} \"\$@\""} bash "''${args[@]}"
    rc=$?
    set -e

    ${lib.optionalString agentSandboxShowMarkers ''
      printf '\n=== claude exit code: %s ===\n' "$rc"
    ''}
    (
      sleep 1
      ${pkgs.systemd}/bin/poweroff || true
    ) >/dev/null 2>&1 &
    exit "$rc"
  '';
in
{
  virtualisation.sharedDirectories.claude-config = {
    source = ''"$AGENT_SANDBOX_CONFIG_DIR"'';
    target = "/mnt/agent-sandbox/config/claude";
    securityModel = "none";
  };

  systemd.tmpfiles.rules = [
    "d /mnt/agent-sandbox/config 0755 root root -"
  ];

  environment.systemPackages = [ claudeCode session ];
}
