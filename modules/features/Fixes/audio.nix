{ self, inputs, ... }: {
  flake.nixosModules.audio = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      xdg.configFile."wireplumber/wireplumber.conf.d/51-disable-hfp.conf".text = ''
        monitor.bluez.properties = {
          bluez5.roles = [ a2dp_sink a2dp_source ]
        }
      '';
    };
  };
}
