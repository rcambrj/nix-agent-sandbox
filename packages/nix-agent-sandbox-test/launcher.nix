{ flake, pkgs, ... }:

let
  hostPkgs = pkgs;
  hostSystem = hostPkgs.stdenv.hostPlatform.system;

  genericLauncher = hostPkgs.lib.getExe flake.packages.${hostSystem}.mock-sandbox;
  opencodeLauncher = hostPkgs.lib.getExe flake.packages.${hostSystem}.opencode-sandbox;
in
hostPkgs.testers.runNixOSTest {
  name = "nix-agent-sandbox-launcher";

  nodes = {};

  testScript = ''
    import os
    import json
    import glob
    import shutil
    import subprocess
    import tempfile

    generic_launcher = ${builtins.toJSON genericLauncher}
    opencode_launcher = ${builtins.toJSON opencodeLauncher}

    # --- Generic mock-sandbox tests ---

    def run_generic(*args, env_file_arg=None):
        cmd = [generic_launcher]
        if env_file_arg is not None:
            cmd += [f"--env-file={env_file_arg}"]
        cmd += list(args)
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=300,
        )
        if result.returncode != 0:
            raise Exception(f"exit {result.returncode}: {result.stdout}")
        return result.stdout

    def run_generic_fail(*args, env_file_arg=None):
        cmd = [generic_launcher]
        if env_file_arg is not None:
            cmd += [f"--env-file={env_file_arg}"]
        cmd += list(args)
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=300,
        )
        if result.returncode == 0:
            raise Exception(f"expected failure, got success: {result.stdout}")
        return result.stdout

    env_dir = tempfile.mkdtemp(prefix="mock-sandbox-test-env-")
    env_file = os.path.join(env_dir, "env")
    with open(env_file, "w") as f:
        f.write("TEST_AGENT_ENV_VAR=hello-from-env\n")

    out = run_generic("--", "hello", "world")
    assert "TEST_AGENT_ARGS_START" in out, f"expected args start marker, got: {out!r}"
    assert "ARG: hello" in out, f"expected 'ARG: hello' in output, got: {out!r}"
    assert "ARG: world" in out, f"expected 'ARG: world' in output, got: {out!r}"
    assert "TEST_AGENT_ARGS_END" in out, f"expected args end marker, got: {out!r}"

    out = run_generic("--", "hello", "world", env_file_arg=env_file)
    assert "TEST_AGENT_ENV_VAR=hello-from-env" in out, f"expected env var in output, got: {out!r}"

    out = run_generic_fail("hello", "extra")
    assert "unexpected launcher argument before --" in out, f"expected strict launcher failure, got: {out!r}"

    out = run_generic_fail("--bogus", "--", "hello")
    assert "unknown launcher flag before --" in out, f"expected unknown launcher flag failure, got: {out!r}"

    os.remove(env_file)
    os.rmdir(env_dir)

    # --- OpenCode sandbox tests ---

    env_dir = tempfile.mkdtemp(prefix="opencode-sandbox-test-env-")
    env_file = os.path.join(env_dir, "env")
    with open(env_file, "w") as f:
        f.write("OPENCODE_DISABLE_MODELS_FETCH=1\n")

    config_dir = tempfile.mkdtemp(prefix="opencode-sandbox-test-config-")

    def run_opencode(*args, env_file_arg=env_file, config_dir_arg=config_dir, data_dir_arg=None, cache_dir_arg=None):
        cmd = [opencode_launcher]
        if env_file_arg is not None:
            cmd += [f"--env-file={env_file_arg}"]
        if config_dir_arg is not None:
            cmd += [f"--config-dir={config_dir_arg}"]
        if data_dir_arg is not None:
            cmd += [f"--data-dir={data_dir_arg}"]
        if cache_dir_arg is not None:
            cmd += [f"--cache-dir={cache_dir_arg}"]
        cmd += list(args)
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=300,
        )
        if result.returncode != 0:
            raise Exception(f"exit {result.returncode}: {result.stdout}")
        return result.stdout

    def run_opencode_fail(*args, env_file_arg=env_file, config_dir_arg=config_dir, data_dir_arg=None, cache_dir_arg=None):
        cmd = [opencode_launcher]
        if env_file_arg is not None:
            cmd += [f"--env-file={env_file_arg}"]
        if config_dir_arg is not None:
            cmd += [f"--config-dir={config_dir_arg}"]
        if data_dir_arg is not None:
            cmd += [f"--data-dir={data_dir_arg}"]
        if cache_dir_arg is not None:
            cmd += [f"--cache-dir={cache_dir_arg}"]
        cmd += list(args)
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=300,
        )
        if result.returncode == 0:
            raise Exception(f"expected failure, got success: {result.stdout}")
        return result.stdout

    out = run_opencode_fail("models", "extra")
    assert "unexpected launcher argument before --" in out, f"expected strict launcher failure, got: {out!r}"

    out = run_opencode_fail("--bogus", "--", "models")
    assert "unknown launcher flag before --" in out, f"expected unknown launcher flag failure, got: {out!r}"

    mock_provider_config = {
        "$schema": "https://opencode.ai/config.json",
        "provider": {
            "mock": {
                "models": {
                    "mock-model": {}
                }
            }
        }
    }
    with open(os.path.join(config_dir, "opencode.json"), "w") as f:
        json.dump(mock_provider_config, f)

    data_dir = tempfile.mkdtemp(prefix="opencode-sandbox-test-data-")
    cache_dir = tempfile.mkdtemp(prefix="opencode-sandbox-test-cache-")

    out = run_opencode(
        "--",
        "models",
        config_dir_arg=config_dir,
        data_dir_arg=data_dir,
        cache_dir_arg=cache_dir,
    )
    assert "Database migration complete." in out, f"expected 'Database migration complete.' in output, got: {out!r}"
    assert "mock/mock-model" in out, f"expected custom config model in output, got: {out!r}"

    assert os.path.isdir(os.path.join(data_dir, "log")), "expected XDG data log directory to be created"
    assert not glob.glob(os.path.join(data_dir, "opencode-*.db")), "expected no persistent DB files matching opencode-*.db when OPENCODE_DB=:memory:"
    assert os.path.isfile(os.path.join(cache_dir, "version")), "expected XDG cache version file to be created"

    os.remove(env_file)
    os.rmdir(env_dir)
    shutil.rmtree(data_dir)
    shutil.rmtree(cache_dir)
    shutil.rmtree(config_dir)
  '';
}
