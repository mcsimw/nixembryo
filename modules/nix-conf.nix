{
  lib,
  config,
  pkgs,
  inputs ? throw "Pass inputs to specialArgs or extraSpecialArgs",
  ...
}:
{
  options = with lib; {
    nix.inputsToPin = mkOption {
      type = with types; listOf str;
      default = ["nixpkgs"];
      example = ["nixpkgs" "nixpkgs-master"];
      description = ''
        Names of flake inputs to pin
      '';
    };
  };

  config = {
    environment.variables.NIXPKGS_CONFIG = lib.mkForce "";
    nix = {
      registry = lib.listToAttrs (map (name: lib.nameValuePair name {flake = inputs.${name};}) config.nix.inputsToPin);
      nixPath = ["nixpkgs=flake:nixpkgs"];
      channel.enable = false;
      settings = {
        substituters = [
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
        "flake-registry" = "/etc/nix/registry.json";
        allow-import-from-derivation = false;
        builders-use-substitutes = true;
        use-xdg-base-directories = true;
        use-cgroups = true;
        log-lines = 30;
        keep-going = true;
        connect-timeout = 5;
        sandbox = pkgs.stdenv.hostPlatform.isLinux;
        extra-experimental-features = [
          "nix-command"
          "flakes"
          "cgroups"
          "auto-allocate-uids"
          "fetch-closure"
          "dynamic-derivations"
          "pipe-operators"
        ];
        warn-dirty = false;
        keep-derivations = true;
        keep-outputs = true;
        accept-flake-config = false;
      };
    };
  };
}
