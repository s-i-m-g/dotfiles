{ self, inputs, ... }: {
  flake.nixosModules.yazi = { pkgs, lib, ... }: {
    # Optional deps for search, preview and fuzzy nav, per
    # https://yazi-rs.github.io/docs/installation
    environment.systemPackages = with pkgs; [
      fd # file searching
      ripgrep # file content searching
      fzf # quick file subtree navigation
      imagemagick # font/HEIC/JPEG XL preview
      ffmpeg # video thumbnails
      jq # JSON preview
      p7zip # archive extraction and preview
      poppler # PDF preview
      zoxide # historical directories navigation
      resvg # SVG preview
      imv # image opener
      mpv # video opener
    ];

    home-manager.users.sim = {
      programs.bash = {
        enable = true;
        # `y` launches yazi and, on exit, cd's the shell to wherever you
        # navigated to inside it. Recommended wrapper from the yazi docs:
        # https://yazi-rs.github.io/docs/quick-start#shell-wrapper
        initExtra = ''
          function y() {
            local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
            yazi "$@" --cwd-file="$tmp"
            if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
              builtin cd -- "$cwd"
            fi
            rm -f -- "$tmp"
          }
        '';
      };

      programs.yazi = {
        enable = true;
        settings = {
          opener = {
            edit = [
              { run = ''nvim "$@"''; block = true; }
            ];
            open = [
              { run = ''xdg-open "$@"''; desc = "Open"; }
            ];
            image = [
              { run = ''imv "$@"''; desc = "Image viewer (imv)"; orphan = true; }
            ];
            video = [
              { run = ''mpv "$@"''; desc = "Video player (mpv)"; orphan = true; }
            ];
          };
          open = {
            rules = [
              { url = "*/"; use = [ "edit" "open" ]; }
              { mime = "text/*"; use = [ "edit" ]; }
              { mime = "application/json"; use = [ "edit" ]; }
              { mime = "image/*"; use = [ "image" ]; }
              { mime = "video/*"; use = [ "video" ]; }
              { mime = "*"; use = [ "open" "edit" ]; }
            ];
          };
        };
      };
    };
  };
}
