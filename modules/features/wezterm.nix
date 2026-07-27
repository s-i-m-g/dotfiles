{ self, inputs, ... }: {
  flake.nixosModules.wezterm = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      programs.wezterm = {
        enable = true;
        extraConfig = ''
          -- Pull in the wezterm API
          local wezterm = require 'wezterm'
          -- This will hold the configuration.
          local config = wezterm.config_builder()

          config.enable_wayland = true
          config.window_background_opacity = 0.7
          config.hide_tab_bar_if_only_one_tab = true
          config.use_fancy_tab_bar = false
          config.tab_bar_at_bottom = true
          config.window_decorations = "NONE"
          config.use_dead_keys = false
          config.front_end = "WebGpu"
          config.color_scheme = 'Tokyo Night'
          config.colors = {
            background = "black",
          }

          wezterm.on('format-tab-title', function(tab)
            return ' ' .. (tab.tab_index + 1) .. ' '
          end)

          local act = wezterm.action

          config.keys = {
            -- Font size
            { key = '=', mods = 'CTRL', action = act.IncreaseFontSize },
            { key = '-', mods = 'CTRL', action = act.DecreaseFontSize },
            { key = '0', mods = 'CTRL', action = act.ResetFontSize },

            -- New window
            { key = 'T', mods = 'CTRL|SHIFT', action = act.SpawnWindow },
            { key = 'N', mods = 'CTRL|SHIFT', action = act.DisableDefaultAssignment },

            -- Tabs
            { key = 't', mods = 'CTRL', action = act.SpawnTab 'CurrentPaneDomain' },
            { key = 'Tab', mods = 'CTRL', action = act.ActivateTabRelative(-1) },

            -- Activate tab by number
            { key = '1', mods = 'CTRL', action = act.ActivateTab(0) },
            { key = '2', mods = 'CTRL', action = act.ActivateTab(1) },
            { key = '3', mods = 'CTRL', action = act.ActivateTab(2) },
            { key = '4', mods = 'CTRL', action = act.ActivateTab(3) },
            { key = '5', mods = 'CTRL', action = act.ActivateTab(4) },
            { key = '6', mods = 'CTRL', action = act.ActivateTab(5) },
            { key = '7', mods = 'CTRL', action = act.ActivateTab(6) },
            { key = '8', mods = 'CTRL', action = act.ActivateTab(7) },
            { key = '9', mods = 'CTRL', action = act.ActivateTab(8) },
          }
          return config
        '';
      };
    };
  };
}
