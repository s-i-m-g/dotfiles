{ self, inputs, ... }: {
  flake.nixosModules.obs = { pkgs, lib, ... }: {
    environment.systemPackages = with pkgs; [
      obs-studio
    ];
    environment.sessionVariables.OBS_USE_EGL = "1";
  };
}
