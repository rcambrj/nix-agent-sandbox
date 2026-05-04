{ flake, inputs, pkgs, system, extraModules ? [ ], showBootLogs ? false, enableSshServer ? true, sshMaxAttempts ? 15, ... }:

flake.lib.mkSandboxPackage {
  inherit pkgs system extraModules showBootLogs enableSshServer sshMaxAttempts;

  name = "mock-sandbox";

  guestModules = [ ];

  launcherScript = flake.lib.mkLauncherScript {
    sessionCommand = { guestSystem, guestPkgs, ... }: guestPkgs.writeShellScriptBin "mock-wrapper" ''
      if [ "''${1:-}" = "fail-stderr" ]; then
        printf 'TEST_AGENT_STDERR_START\n' >&2
        sleep 1
        printf 'TEST_AGENT_STDERR_END\n' >&2
        exit 42
      fi

      if [ "''${1:-}" = "probe-host-port" ]; then
        if [ -z "''${2:-}" ]; then
          echo "TEST_HOST_PORT_PROBE_FAIL"
          exit 1
        fi
        ${guestPkgs.curl}/bin/curl -fsS "http://127.0.0.1:$2/"
        exit 0
      fi

      if [ "''${1:-}" = "nix-store-write-smoke" ]; then
        nix_store_mount_count="$(${guestPkgs.util-linux}/bin/findmnt -Rno TARGET /nix/store | ${guestPkgs.coreutils}/bin/wc -l)"
        nix_store_mount_count="$(${guestPkgs.coreutils}/bin/tr -d '[:space:]' <<< "$nix_store_mount_count")"
        printf 'TEST_NIX_STORE_MOUNT_COUNT=%s\n' "$nix_store_mount_count"

        ${guestPkgs.nix}/bin/nix build --no-link --offline --impure --expr 'derivation {
          name = "sandbox-store-write-smoke";
          system = builtins.currentSystem;
          builder = "/bin/sh";
          args = [ "-c" "mkdir -p $out; echo ok > $out/result" ];
        }'
        echo "TEST_NIX_STORE_WRITE_OK"
        exit 0
      fi

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
  };
}
