{ self, inputs, ... }: {
  flake.nixosModules.mullvad-browser = { pkgs, lib, ... }: {
    environment.systemPackages = [ pkgs.mullvad-browser ];
  };
}
