{ self, inputs, ... }: {
  flake.nixosModules.mpv = { pkgs, lib, ... }: {
    environment.systemPackages = [ pkgs.mpv ];

    home-manager.users.sim = {
      # libplacebo/Vulkan defaults to the discrete Nvidia GPU, which is
      # PRIME-offload-only and normally idle - waking it and spinning up
      # its proprietary Vulkan driver from cold costs ~2s on every launch
      # ("Spent 1543ms enumerating instance extensions (slow!)" / "Spent
      # 808ms creating vulkan device (slow!)" in `mpv -v`). Pinning to the
      # AMD iGPU, which already drives the display, avoids the wake/init
      # entirely.
      xdg.configFile."mpv/mpv.conf".text = ''
        vulkan-device=AMD Radeon Graphics (RADV RENOIR)
      '';
    };
  };
}
