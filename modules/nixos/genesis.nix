{ flake, withSystem, ... }:
{
  config,
  lib,
  inputs,
  ...
}:
let
  modulesPath = "${inputs.nixpkgs.outPath}/nixos/modules";
  configForSub =
    {
      sub,
      iso ? false,
    }:
    let
      baseModules = [
        { 
          networking.hostName = sub.hostname; 
          nixpkgs.pkgs = withSystem sub.system ({pkgs, ...}: pkgs);
        }
        sub.src
        flake.self.nixosModules.default
        flake.nixos-facter-modules.nixosModules.facter
        flake.self.nixosModules.fakeFileSystems
      ];
      isoModules = [
        {
          imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-base.nix" ];
          boot.initrd.systemd.enable = lib.mkForce false;
          isoImage.squashfsCompression = "lz4";
          networking.wireless.enable = lib.mkForce false;
        }
      ];
    in
    withSystem sub.system (
      _:
      flake.nixpkgs.lib.nixosSystem {
        inherit (sub) system;
        specialArgs = withSystem sub.system (
          { inputs', self', ... }:
          {
            inherit (config) packages;
            inherit self' inputs' inputs;
          }
        );
        modules = baseModules ++ lib.optionals iso isoModules;
      }
    );
in
{
  imports = [
    flake.treefmt-nix.flakeModule
  ];
  options.genesis = {
    compootuers = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            hostname = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            src = lib.mkOption {
              type = lib.types.path;
            };
            system = lib.mkOption {
              type = lib.types.str;
              default = "x86_64-linux";
            };
          };
        }
      );
      default = [ ];
    };
  };
  config.flake.nixosConfigurations = builtins.listToAttrs (
    lib.concatMap (
      sub:
      if sub.hostname == null then
        [ ]
      else
        [
          {
            name = sub.hostname;
            value = configForSub {
              inherit sub;
              iso = false;
            };
          }
          {
            name = "${sub.hostname}-iso";
            value = configForSub {
              inherit sub;
              iso = true;
            };
          }
        ]
    ) config.genesis.compootuers
  );
}
