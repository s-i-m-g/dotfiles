{ self, inputs, ... }: {
  flake.nixosModules.mako = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      services.mako = {
        enable = true;
        settings = {
          # geometry / placement
          anchor = "top-right";
          layer = "overlay";        # show above fullscreen windows (default 'top' is covered by them)
          width = 300;
          height = 100;             # max height; mako shrinks to fit the text within this
          margin = "12";
          padding = "8";
          border-size = 0;
          border-radius = 8;

          # timing
          default-timeout = 5000;   # ms; 0 = never expire
          max-visible = 5;

          # appearance — translucent bg so mango's blur shows through.
          # colors are #RRGGBBAA; last two hex digits are alpha.
          font = "monospace 11";
          background-color = "#1a1b2666";   # ~0.4 alpha, matches rofi
          text-color = "#c0caf5ff";

          # urgent notifications stick around and stand out
          "urgency=high" = {
            default-timeout = 0;
          };
        };
      };

      home.packages = [ pkgs.libnotify ];  # provides notify-send for the scripts
    };
  };
}
