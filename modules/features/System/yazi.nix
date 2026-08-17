{ self, inputs, ... }: {
  flake.nixosModules.yazi = { pkgs, lib, ... }:
  let
    yaziPaste = pkgs.writeShellScriptBin "yazi-paste" ''
      set -e
      if ${pkgs.wl-clipboard}/bin/wl-paste --list-types | grep -q text/uri-list; then
        ${pkgs.wl-clipboard}/bin/wl-paste -t text/uri-list | tr -d '\r' | sed 's|^file://||' | while read -r f; do
          [ -z "$f" ] && continue
          decoded=$(printf '%b' "''${f//%/\\x}")
          cp -r -- "$decoded" .
        done
      else
        ext=$(${pkgs.wl-clipboard}/bin/wl-paste --list-types | head -1 | sed 's|.*/||')
        ${pkgs.wl-clipboard}/bin/wl-paste > "clip-$(date +%s).$ext"
      fi
    '';
  in {
    environment.systemPackages = with pkgs; [
      fd
      ripgrep
      fzf
      imagemagick
      ffmpeg
      jq
      p7zip
      poppler
      zoxide
      resvg
      imv
      mpv
      wl-clipboard
      yaziPaste
    ];
    home-manager.users.sim = {
      programs.bash = {
        enable = true;
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
        keymap = {
          mgr.prepend_keymap = [
            {
              on = [ "y" ];
              run = [
                ''shell -- for path in %s; do echo "file://$path"; done | wl-copy -t text/uri-list''
                "yank"
              ];
              desc = "Yank and copy file paths to the system clipboard";
            }
            {
              on = [ "P" ];
              run = "shell -- yazi-paste";
              desc = "Paste clipboard as file";
            }
          ];
        };
        settings = {
          opener = {
            edit = [ { run = ''nvim "$@"''; block = true; } ];
            open = [ { run = ''xdg-open "$@"''; desc = "Open"; } ];
            image = [ { run = ''imv "$@"''; desc = "Image viewer (imv)"; orphan = true; } ];
            video = [ { run = ''mpv "$@"''; desc = "Video player (mpv)"; orphan = true; } ];
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
