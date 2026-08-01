{ self, inputs, ... }: {
  flake.nixosModules.btop = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      programs.btop = {
        enable = true;
        # use the ROCm-enabled btop build so it can talk to the AMD GPU;
        # NVML (nvidia) support is included in the default GPU build.
        package = pkgs.btop.override { rocmSupport = true; };
        settings = {
          color_theme = "tokyo-night";
          theme_background = false;
          vim_keys = true;
          update_ms = 1000;
          proc_sorting = "cpu lazy";
          show_battery = true;
          show_coretemp = true;
          # show gpu boxes (btop auto-detects; these keys control display)
          show_gpu_info = "Auto";
          gpu_mirror_graph = true;
        };
      };
    };
  };
}
