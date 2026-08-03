{ self, inputs, ... }: {
  flake.nixosModules.gimp = { pkgs, lib, ... }: {
    environment.systemPackages = [
      (pkgs.gimp3-with-plugins.override {
        plugins = with pkgs.gimpPlugins; [ gmic resynthesizer ];
      })
    ];
  };
}
