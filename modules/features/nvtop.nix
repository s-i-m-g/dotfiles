{ self, inputs, ... }: {
  flake.nixosModules.nvtop = { pkgs, lib, ... }: {
    environment.systemPackages = [ pkgs.nvtopPackages.full ];
  };
}
