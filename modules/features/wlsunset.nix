{ self, inputs, ... }: {
  flake.nixosModules.wlsunset = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      services.wlsunset = {
        enable = true;
	latitude = "48.8";
	longitude = "2.3";
        temperature = {
          day = 4000;
          night = 4000;
        };
      };
    };
  };
}
