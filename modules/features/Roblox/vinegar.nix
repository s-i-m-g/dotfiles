{ self, inputs, ... }: {
  flake.nixosModules.vinegar = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      home.packages = [
        # Wrap vinegar so it always launches offloaded onto the Nvidia dGPU.
        # nvidia-offload (from hardware.nvidia.prime.offload.enableOffloadCmd)
        # sets the PRIME env vars; this makes `vinegar` use the RTX 3050 by default.
        # VK_ICD_FILENAMES restricts Vulkan to the NVIDIA ICD only, so Studio
        # (Vulkan renderer) can't enumerate/pick the integrated Radeon and is
        # forced onto the dGPU.
        (pkgs.symlinkJoin {
          name = "vinegar-offload";
          paths = [ pkgs.vinegar ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/vinegar \
              --run 'export __NV_PRIME_RENDER_OFFLOAD=1' \
              --run 'export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0' \
              --run 'export __GLX_VENDOR_LIBRARY_NAME=nvidia' \
              --run 'export __VK_LAYER_NV_optimus=NVIDIA_only' \
              --run 'export VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json'
          '';
        })
      ];

      # Declaratively manage Vinegar's config.toml so renderer/DPI/webview
      # settings survive a wipe. Lands at ~/.config/vinegar/config.toml.
      # webview = "" disables Studio's in-app WebView (the "Web Pages" setting):
      # the broken WebView is what blanks the Toolbox text/buttons and the
      # login page. With it off, Studio pushes web login to the real browser.
      xdg.configFile."vinegar/config.toml".text = ''
        [studio]
        renderer = "Vulkan"
        dpi = 144
        webview = ""
      '';
    };
  };
}
