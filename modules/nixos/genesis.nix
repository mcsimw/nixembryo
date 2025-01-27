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
        }
        sub.src
        flake.self.nixosModules.default
        flake.nixos-facter-modules.nixosModules.facter
        flake.self.nixosModules.fakeFileSystems
        flake.nixpkgs.nixosModules.readOnlyPkgs
      ];
      isoModules = [
        {
          imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-base.nix" ];
          boot.initrd.systemd.enable = lib.mkForce false;
          isoImage.squashfsCompression = "lz4";
          networking.wireless.enable = lib.mkForce false;
        }
      ];
      nonIsoModules = [ { nixpkgs.pkgs = withSystem sub.system ({ pkgs, ... }: pkgs); } ];
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
        modules = baseModules ++ lib.optionals iso isoModules ++ lib.optionals (!iso) nonIsoModules;
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
