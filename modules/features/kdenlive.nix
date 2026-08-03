{ self, inputs, ... }: {
  flake.nixosModules.kdenlive = { pkgs, lib, ... }: {
    environment.systemPackages = [ pkgs.kdePackages.kdenlive ];
  };
}
