{ flake, inputs, pkgs, ... } @ args:

let
  launcherTest = pkgs.callPackage ./launcher.nix args;
  moduleTest = pkgs.callPackage ./module.nix args;
in
pkgs.linkFarm "opencode-sandbox-test" [
  {
    name = "launcher";
    path = launcherTest;
  }
  {
    name = "module";
    path = moduleTest;
  }
]
