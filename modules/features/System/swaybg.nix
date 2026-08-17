{ self, inputs, ... }: {
  flake.nixosModules.swaybg = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      home.packages = [ pkgs.swaybg ];
    };
  };
}
