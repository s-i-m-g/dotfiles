{ self, inputs, ... }: {
  flake.nixosModules.rofi = { pkgs, lib, ... }: {
    home-manager.users.sim = { config, ... }: {
      programs.rofi = {
        enable = true;

        # translucent background so mango's blur_layer shows through.
        # colors use #RRGGBBAA — the last two hex digits are alpha.
        theme =
          let
            inherit (config.lib.formats.rasi) mkLiteral;
          in {
            "*" = {
              bg      = mkLiteral "#1a1b2666";  # ~0.4 alpha, matches your other panels
              bg-alt  = mkLiteral "#c9b89022";  # faint accent tint for selection
              fg      = mkLiteral "#c0caf5ff";
              accent  = mkLiteral "#c9b890ff";  # matches your mango focuscolor
              transparent = mkLiteral "#00000000";

              background-color = mkLiteral "transparent";
              text-color       = mkLiteral "@fg";
            };

            "window" = {
              transparency = "real";              # required for the alpha channel to work
              background-color = mkLiteral "@bg";
              border = mkLiteral "0px";
              border-radius = mkLiteral "12px";
              width = mkLiteral "600px";
              padding = mkLiteral "12px";
            };

            "mainbox" = {
              background-color = mkLiteral "transparent";
              children = map mkLiteral [ "inputbar" "listview" ];
              spacing = mkLiteral "12px";
            };

            "inputbar" = {
              background-color = mkLiteral "transparent";
              padding = mkLiteral "10px";
              border-radius = mkLiteral "8px";
              spacing = mkLiteral "8px";
              children = map mkLiteral [ "prompt" "entry" ];
            };

            "prompt".text-color = mkLiteral "@accent";
            "entry".placeholder = "Search...";

            "listview" = {
              background-color = mkLiteral "transparent";
              lines = mkLiteral "8";
              spacing = mkLiteral "4px";
              scrollbar = false;
            };

            "element" = {
              background-color = mkLiteral "transparent";
              padding = mkLiteral "8px";
              border-radius = mkLiteral "8px";
            };

            "element selected" = {
              background-color = mkLiteral "@bg-alt";
              text-color = mkLiteral "@accent";
            };

            "element-icon" = {
              background-color = mkLiteral "transparent";
              size = mkLiteral "1.2em";
            };

            "element-text" = {
              background-color = mkLiteral "transparent";
              vertical-align = mkLiteral "0.5";
            };
          };
      };
    };
  };
}
