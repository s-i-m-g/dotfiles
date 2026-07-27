{ self, inputs, ... }: {
  flake.nixosModules.btop = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      programs.btop = {
        enable = true;
        settings = {
          color_theme = "tokyo-night";
          theme_background = false;
          vim_keys = true;
          update_ms = 1000;
          proc_sorting = "cpu lazy";
          show_battery = true;
          show_coretemp = true;
        };
      };
    };
  };
}
