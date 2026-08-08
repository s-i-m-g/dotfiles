{ self, inputs, ... }: {
  flake.nixosModules.vinegar = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      home.packages = [
        # Wrap vinegar so it always launches offloaded onto the Nvidia dGPU.
        # nvidia-offload (from hardware.nvidia.prime.offload.enableOffloadCmd)
        # sets the PRIME env vars; this makes `vinegar` use the RTX 3050 by default.
        (pkgs.symlinkJoin {
          name = "vinegar-offload";
          paths = [ pkgs.vinegar ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/vinegar \
              --run 'export __NV_PRIME_RENDER_OFFLOAD=1' \
              --run 'export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0' \
              --run 'export __GLX_VENDOR_LIBRARY_NAME=nvidia' \
              --run 'export __VK_LAYER_NV_optimus=NVIDIA_only'
          '';
        })
      ];

      # Declaratively manage Vinegar's config.toml so renderer/GPU settings
      # survive a wipe. Lands at ~/.config/vinegar/config.toml.
      xdg.configFile."vinegar/config.toml".text = ''
        [studio]
        renderer = "Vulkan"
      '';
    };
  };
}
