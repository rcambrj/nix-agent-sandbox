{ inputs, lib, agentSandboxShowMarkers ? false, pkgs, ... }:

let
  opencode = inputs.numtide-llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
in
let
  session = pkgs.writeShellScriptBin "opencode-sandbox-session" ''
  set -euo pipefail

  export HOME=/root
  export SHELL=${pkgs.bashInteractive}/bin/bash
  export OPENCODE_DB=:memory:
  export XDG_CONFIG_HOME=/mnt/agent-sandbox/config

  if [ -r /mnt/agent-sandbox/control/opencode-has-data-dir ]; then
    export XDG_DATA_HOME=/mnt/agent-sandbox/data
  fi

  if [ -r /mnt/agent-sandbox/control/opencode-has-cache-dir ]; then
    export XDG_CACHE_HOME=/mnt/agent-sandbox/cache
  fi

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

  command=( ${lib.getExe opencode} "''${args[@]}" )
  printf -v command_line '%q ' "''${command[@]}"
  command_line="''${command_line% }"

  printf 'opencode-sandbox: cwd=%s\n' "$PWD"
  printf 'opencode-sandbox: command=%s\n' "$command_line"

  {
    printf 'cwd=%s\n' "$PWD"
    printf 'command=%s\n' "$command_line"
    printf 'OPENCODE_DB=%s\n' "$OPENCODE_DB"
    printf 'XDG_CONFIG_HOME=%s\n' "$XDG_CONFIG_HOME"
    if [ -n "''${XDG_DATA_HOME:-}" ]; then
      printf 'XDG_DATA_HOME=%s\n' "$XDG_DATA_HOME"
    fi
    if [ -n "''${XDG_CACHE_HOME:-}" ]; then
      printf 'XDG_CACHE_HOME=%s\n' "$XDG_CACHE_HOME"
    fi
  } | ${pkgs.systemd}/bin/systemd-cat -t opencode-sandbox-session

  ${lib.optionalString agentSandboxShowMarkers ''
    printf '\n=== Starting opencode in /workspace ===\n'
    printf '=== opencode args: %s ===\n\n' "''${args[*]:-(interactive)}"
  ''}

  set +e
  ${pkgs.bashInteractive}/bin/bash -l -c ${lib.escapeShellArg "${lib.getExe opencode} \"\$@\""} bash "''${args[@]}"
  rc=$?
  set -e

  ${lib.optionalString agentSandboxShowMarkers ''
    printf '\n=== opencode exit code: %s ===\n' "$rc"
  ''}
  (
    sleep 1
    ${pkgs.systemd}/bin/poweroff || true
  ) >/dev/null 2>&1 &
  exit "$rc"
  '';
in
session
