{ self, inputs, ... }: {
  flake.nixosModules.blender = { pkgs, lib, ... }:
  let
    # The prebuilt CUDA/OptiX Blender from the flake input.
    blenderCuda = inputs.blender-cuda.packages.${pkgs.system}.blender-with-cuda;

    # Wrap it to launch on the RTX 3050 via PRIME render offload — the same env
    # vars your Sober flatpak override sets, but for a native package. This forces
    # Blender's OpenGL/Vulkan (viewport, EEVEE) onto the Nvidia GPU. (Cycles GPU
    # *rendering* via OptiX is a separate one-time toggle inside Blender's prefs.)
    blenderNvidia = pkgs.symlinkJoin {
      name = "blender-nvidia";
      paths = [ blenderCuda ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/blender \
          --set __NV_PRIME_RENDER_OFFLOAD 1 \
          --set __NV_PRIME_RENDER_OFFLOAD_PROVIDER NVIDIA-G0 \
          --set __GLX_VENDOR_LIBRARY_NAME nvidia \
          --set __VK_LAYER_NV_optimus NVIDIA_only
      '';
    };
  in {
    # Binary cache so the CUDA Blender is downloaded, not compiled from source.
    nix.settings = {
      substituters = [ "https://adithyagenie.cachix.org" ];
      trusted-public-keys = [ "adithyagenie.cachix.org-1:h6BSMboeVfxyrULWuRQqAyweo4AJRATekb88xotfQwc=" ];
    };

    environment.systemPackages = [ blenderNvidia ];
  };
}
