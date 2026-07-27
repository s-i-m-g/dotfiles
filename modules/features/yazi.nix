{ self, inputs, ... }: {
  flake.nixosModules.yazi = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      # Optional deps for search, preview and fuzzy nav, per
      # https://yazi-rs.github.io/docs/installation
      home.packages = with pkgs; [
        fd # file searching
        ripgrep # file content searching
        fzf # quick file subtree navigation
        imagemagick # font/HEIC/JPEG XL preview
        ffmpegthumbnailer # video thumbnails
        jq # JSON preview
      ];

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
          };
          open = {
            rules = [
              { url = "*/"; use = [ "edit" "open" ]; }
              { mime = "text/*"; use = [ "edit" ]; }
              { mime = "application/json"; use = [ "edit" ]; }
              { mime = "image/*"; use = [ "open" ]; }
              { mime = "video/*"; use = [ "open" ]; }
              { mime = "*"; use = [ "open" "edit" ]; }
            ];
          };
        };
      };
    };
  };
}
