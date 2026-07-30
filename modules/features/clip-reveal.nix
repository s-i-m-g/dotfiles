{ self, inputs, ... }: {
  flake.nixosModules.clip-reveal = { pkgs, lib, ... }:
  let
    clipReveal = pkgs.writeShellScriptBin "clip-reveal" ''
      # clip-reveal: reveal the clipboard's contents in yazi.
      #  - raw image bytes  -> save to ~/Media/clipboard, replace the clipboard
      #                        with that file's path (uri-list), then reveal it
      #  - a file path/URI   -> open yazi hovering that file
      # Opens in a floating kitty window (class clipreveal), like clip-picker.
      set -euo pipefail

      SAVEDIR="''${HOME}/Media/clipboard"
      mkdir -p "$SAVEDIR"

      notify() { ${pkgs.libnotify}/bin/notify-send "clip-reveal" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "clip-reveal: $1" >&2; exit 1; }

      target=""
      types="$(${pkgs.wl-clipboard}/bin/wl-paste --list-types 2>/dev/null || true)"

      if printf '%s\n' "$types" | grep -q '^text/uri-list$'; then
        # yazi yank / file-manager copy: take the first file:// URI
        first="$(${pkgs.wl-clipboard}/bin/wl-paste -t text/uri-list 2>/dev/null \
                  | tr -d '\r' | sed 's|^file://||' | head -1)"
        [ -n "$first" ] || die "empty uri-list on clipboard"
        target="$(printf '%b' "''${first//%/\\x}")"
        [ -e "$target" ] || die "uri-list points to a missing file: $target"
      elif printf '%s\n' "$types" | grep -q '^image/'; then
        # raw image bytes -> save first, then replace clipboard with the file path
        img_mime="$(printf '%s\n' "$types" | grep -m1 '^image/')"
        ext="''${img_mime#image/}"
        target="$SAVEDIR/clip-$(date +%Y%m%d-%H%M%S).$ext"
        ${pkgs.wl-clipboard}/bin/wl-paste -t "$img_mime" > "$target" \
          || die "couldn't read image from clipboard"
        # replace the image bytes on the clipboard with the saved file's uri-list.
        # detached so it persists after this process exits (matches clip-picker).
        ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c \
          "printf 'file://%s\n' '$target' | ${pkgs.wl-clipboard}/bin/wl-copy -t text/uri-list" \
          </dev/null >/dev/null 2>&1 || true
      else
        # plain-text path / file:// URI
        raw="$(${pkgs.wl-clipboard}/bin/wl-paste 2>/dev/null || true)"
        raw="''${raw%$'\n'}"
        [ -n "$raw" ] || die "clipboard is empty"
        raw="''${raw#file://}"
        target="$(printf '%b' "''${raw//%/\\x}")"
        [ -e "$target" ] || die "clipboard isn't an image or valid file path"
      fi

      # open a floating kitty running yazi, pointed at the file so it's hovered
      exec ${pkgs.kitty}/bin/kitty --class clipreveal \
        -e ${pkgs.yazi}/bin/yazi "$target"
    '';
  in {
    environment.systemPackages = [ clipReveal pkgs.wl-clipboard pkgs.file pkgs.libnotify pkgs.kitty pkgs.yazi pkgs.util-linux pkgs.bash ];
  };
}
