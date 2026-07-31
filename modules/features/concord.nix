{ self, inputs, ... }: {
  flake.nixosModules.concord = { pkgs, lib, ... }: {
    environment.systemPackages = [
      inputs.concord.packages.${pkgs.system}.default
    ];
  };
}
