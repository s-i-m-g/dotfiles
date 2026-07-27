{ self, inputs, ... }: {
  flake.nixosModules.vesktop = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      programs.vesktop = {
        enable = true;

        settings = {
          minimizeToTray = true;
          discordBranch = "stable";
          arRPC = true;
        };

        vencord.settings = {
          autoUpdate = false;
          useQuickCss = true;
          plugins = {
            MessageLogger.enabled = true;
            SilentTyping.enabled = true;
          };
        };
      };
    };
  };
}