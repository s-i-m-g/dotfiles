{ self, inputs, ... }: {
  flake.nixosModules.kitty = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      programs.kitty = {
        enable = true;

        settings = {
          background_opacity = "0.7";
          background = "#000000";

          hide_window_decorations = "yes";
          tab_bar_edge = "bottom";
          tab_bar_style = "powerline";
          tab_title_template = "{index}";

          remember_window_size = "no";
          initial_window_width = "170c";
          initial_window_height = "50c";

          confirm_os_window_close = 0;
        };

        themeFile = "tokyo_night_night";

        keybindings = {
          # Font size
          "ctrl+equal" = "change_font_size all +1.0";
          "ctrl+minus" = "change_font_size all -1.0";
          "ctrl+0" = "change_font_size all 0";

          # New window
          "ctrl+shift+t" = "new_os_window";

          # Tabs
          "ctrl+t" = "new_tab";
          "ctrl+tab" = "previous_tab";

          # Activate tab by number
          "ctrl+1" = "goto_tab 1";
          "ctrl+2" = "goto_tab 2";
          "ctrl+3" = "goto_tab 3";
          "ctrl+4" = "goto_tab 4";
          "ctrl+5" = "goto_tab 5";
          "ctrl+6" = "goto_tab 6";
          "ctrl+7" = "goto_tab 7";
          "ctrl+8" = "goto_tab 8";
          "ctrl+9" = "goto_tab 9";
        };
      };
    };
  };
}