{ self, inputs, ... }: {
  flake.nixosModules.vesktop = { pkgs, lib, ... }: {
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) [ "discord" "vesktop" ];

    home-manager.users.sim = {
      imports = [ inputs.nixcord.homeModules.nixcord ];

      programs.nixcord = {
        enable = true;
        discord.enable = false;
        vesktop.enable = true;

        quickCss = (builtins.readFile ./midnight.theme.css) + ''
          :root {
          }
	  body {
	    --font: ''';
	  }
        '';

        config = {
          useQuickCss = true;
          frameless = true;
          transparent = true;
          autoUpdate = false;
          plugins = {
            messageLogger.enable = true;
            silentTyping.enable = true;
          };
        };
      };
    };
  };
}
