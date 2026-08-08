{ self, inputs, ... }: {
  flake.nixosModules.flatpak = { pkgs, lib, ... }: {
    imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

    services.flatpak = {
      enable = true;
      packages = [
        "org.vinegarhq.Sober"
      ];

      # Sober has no GPU-selection UI of its own; force it onto the
      # Nvidia RTX 3050 via PRIME render offload (same env vars the
      # generated `nvidia-offload` wrapper sets for native apps).
      # Flatpak sandboxes env vars, so this must be set as an override
      # rather than just exported on the host.
      overrides."org.vinegarhq.Sober".Environment = {
        __NV_PRIME_RENDER_OFFLOAD = "1";
        __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        __VK_LAYER_NV_optimus = "NVIDIA_only";
      };

    };

  };
}
