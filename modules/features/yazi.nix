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
