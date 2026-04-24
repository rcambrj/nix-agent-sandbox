{ lib, agentSandboxShowMarkers ? false, pkgs, ... }:

let
  testAgent = pkgs.writeShellScriptBin "test-agent" ''
    echo "TEST_AGENT_ARGS_START"
    for arg in "$@"; do
      echo "ARG: $arg"
    done
    echo "TEST_AGENT_ARGS_END"
    echo "CWD=$(pwd)"
    echo "HOME=$HOME"
    if [ -n "''${TEST_AGENT_ENV_VAR:-}" ]; then
      echo "TEST_AGENT_ENV_VAR=$TEST_AGENT_ENV_VAR"
    fi
  '';

  session = pkgs.writeShellScriptBin "mock-sandbox-session" ''
    set -euo pipefail

    export HOME=/root
    export SHELL=${pkgs.bashInteractive}/bin/bash

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

    ${lib.getExe testAgent} "''${args[@]}"
    rc=$?

    (
      sleep 1
      ${pkgs.systemd}/bin/poweroff || true
    ) >/dev/null 2>&1 &
    exit "$rc"
  '';
in
{
  environment.systemPackages = [ testAgent session ];
}
