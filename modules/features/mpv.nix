{ self, inputs, ... }: {
  flake.nixosModules.mpv = { pkgs, lib, ... }: {
    # `vulkan-device` in mpv.conf only picks among already-enumerated
    # devices - the Vulkan loader still enumerates every ICD in
    # /run/opengl-driver/share/vulkan/icd.d/ first, including
    # nvidia_icd.json, which resumes the runtime-suspended (PCI D3)
    # discrete Nvidia GPU just to query it. That resume, not GFXOFF, is
    # what still causes a ~1.5-2s stall on the first video open after an
    # idle gap. Scoping VK_ICD_FILENAMES to only the AMD ICD stops the
    # loader from touching the Nvidia device at all.
    environment.systemPackages = [
      (pkgs.symlinkJoin {
        name = "mpv";
        paths = [ pkgs.mpv ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/mpv \
            --set VK_ICD_FILENAMES /run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json
        '';
      })
    ];

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
