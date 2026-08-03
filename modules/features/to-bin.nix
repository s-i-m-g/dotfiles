{ self, inputs, ... }: {
  flake.nixosModules.to-bin = { pkgs, lib, ... }:
  let
    toBin = pkgs.writeShellScriptBin "to-bin" ''
      # to-bin: convert a clipboard file-link (text/uri-list) into raw image
      # PIXELS on the clipboard (lossless PNG), so GIMP's normal Ctrl+V pastes it
      # as a floating selection / new layer into whatever image you're editing.
      #
      # - lossless: uses PNG, no recompression
      # - gifs: pastes the FIRST FRAME (Ctrl+V can't paste an animation)
      # - already-image clipboards (image/png etc.) are passed straight through
      set -euo pipefail

      notify() { ${pkgs.libnotify}/bin/notify-send "to-bin" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "to-bin: $1" >&2; exit 1; }

      TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

      types="$(${pkgs.wl-clipboard}/bin/wl-paste --list-types 2>/dev/null || true)"
      src=""

      # if the clipboard already holds image pixels, we still normalize to a
      # clean lossless PNG so GIMP always gets a paste-able format.
      if printf '%s\n' "$types" | grep -q '^text/uri-list$'; then
        first="$(${pkgs.wl-clipboard}/bin/wl-paste -t text/uri-list 2>/dev/null \
                  | tr -d '\r' | sed 's|^file://||' | head -1)"
        [ -n "$first" ] || die "empty uri-list on clipboard"
        src="$(printf '%b' "''${first//%/\\x}")"
        [ -f "$src" ] || die "clipboard link doesn't point to a file: $src"
      else
        got=""
        for t in image/png image/webp image/jpeg image/gif image/bmp image/tiff; do
          if printf '%s\n' "$types" | grep -qi "^$t$"; then
            ext="''${t#image/}"
            ${pkgs.wl-clipboard}/bin/wl-paste -t "$t" > "$TMP/clip.$ext" 2>/dev/null || true
            [ -s "$TMP/clip.$ext" ] && { src="$TMP/clip.$ext"; got=1; break; }
          fi
        done
        [ -n "$got" ] || die "clipboard has no file link or image"
      fi

      # load (first frame if animated), force clean sRGB truecolor+alpha, write PNG
      png="$TMP/out.png"
      ${pkgs.imagemagick}/bin/magick "$src[0]" \
        -colorspace sRGB -type TrueColorAlpha "$png" >/dev/null 2>&1 \
        || die "couldn't decode image: $src"
      [ -s "$png" ] || die "conversion produced nothing"

      # put the PNG on the clipboard as image pixels for GIMP's Ctrl+V.
      # foreground (not setsid -f) so it stays until replaced; wl-copy daemonizes
      # itself to hold the selection.
      ${pkgs.wl-clipboard}/bin/wl-copy -t image/png < "$png"

      notify "image on clipboard — Ctrl+V in GIMP"
    '';
  in {
    environment.systemPackages = [
      toBin pkgs.imagemagick pkgs.wl-clipboard pkgs.libnotify pkgs.coreutils pkgs.gnused
    ];
  };
}
