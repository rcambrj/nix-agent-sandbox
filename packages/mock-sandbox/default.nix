{ flake, pkgs, system, extraModules ? [ ], showBootLogs ? false, ... }:

flake.lib.mkAgentSandbox {
  inherit pkgs system extraModules showBootLogs;

  name = "mock-sandbox";

  guestModules = [
    ./guest-test.nix
  ];

  launcherScript = flake.lib.mkHarnessLauncherScript {
    sessionCommand = "mock-sandbox-session";
  };
}
