{ self, inputs, ... }: {
  flake.nixosModules.mako = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      services.mako = {
        enable = true;
        settings = {
          # geometry / placement
          anchor = "top-right";
          layer = "overlay";        # show above fullscreen windows (default 'top' is covered by them)
          width = 350;
          height = 150;
          margin = "12";
          padding = "12";
          border-size = 2;
          border-radius = 8;

          # timing
          default-timeout = 5000;   # ms; 0 = never expire
          max-visible = 5;

          # appearance
          font = "monospace 11";
          background-color = "#1e1e2e";
          text-color = "#cdd6f4";
          border-color = "#89b4fa";

          # urgent notifications stick around and stand out
          "urgency=high" = {
            border-color = "#f38ba8";
            default-timeout = 0;
          };
        };
      };

      home.packages = [ pkgs.libnotify ];  # provides notify-send for the scripts
    };
  };
}
