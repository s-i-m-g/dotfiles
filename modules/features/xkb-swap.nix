{ self, inputs, ... }: {
  flake.nixosModules.xkb-swap = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      home.file.".config/xkb/symbols/dvp-swap".text = ''
        default partial alphanumeric_keys
        xkb_symbols "dvp-swap" {
            include "us(dvp)"
            name[Group1] = "Programmer Dvorak, semicolon-colon swapped";
            key <AD01> { [ colon, semicolon ] };
        };
      '';
    };
  };
}
