{ self, inputs, ... }: {
  flake.nixosModules.yazi = { pkgs, lib, ... }: {
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
