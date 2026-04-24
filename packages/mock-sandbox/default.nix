{ flake, inputs, pkgs, system, extraModules ? [ ], showBootLogs ? false, ... }:

flake.lib.mkAgentSandbox {
  inherit pkgs system extraModules showBootLogs;

  name = "mock-sandbox";

  guestModules = [ ];

  launcherScript = flake.lib.mkHarnessLauncherScript {
    sessionCommand = guestSystem: import ./session-wrapper.nix {
      pkgs = import inputs.nixpkgs { system = guestSystem; };
      lib = inputs.nixpkgs.lib;
    };
  };
}
