{ flake, pkgs, ... }:

let
  hostPkgs = pkgs;
  hostSystem = hostPkgs.stdenv.hostPlatform.system;
  launcher = hostPkgs.lib.getExe flake.packages.${hostSystem}.opencode-sandbox;
in
hostPkgs.testers.runNixOSTest {
  name = "opencode-sandbox";

  nodes = {};

  testScript = ''
    import os
    import subprocess
    import tempfile

    launcher = ${builtins.toJSON launcher}

    env_dir = tempfile.mkdtemp(prefix="opencode-sandbox-test-env-")
    env_file = os.path.join(env_dir, "env")
    with open(env_file, "w") as f:
        f.write("OPENCODE_DISABLE_MODELS_FETCH=1\n")

    def run(*args):
        result = subprocess.run(
            [launcher, "--env-file", env_file, *args],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=300,
        )
        if result.returncode != 0:
            raise Exception(f"exit {result.returncode}: {result.stdout}")
        return result.stdout

    out = run("models")
    assert "Database migration complete." in out and "opencode-go/" in out

    out = run("--help")
    assert "Options:" in out and "show help" in out

    tmpdir = tempfile.mkdtemp(prefix="opencode-sandbox-share-")
    try:
        out = run(tmpdir, "--help")
        assert "Options:" in out and "show help" in out
    finally:
        os.rmdir(tmpdir)

    os.remove(env_file)
    os.rmdir(env_dir)
  '';
}