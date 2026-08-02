{ self, inputs, ... }: {
  flake.nixosModules.trim-top = { pkgs, lib, ... }:
  let
    trimTop = pkgs.writeShellScriptBin "trim-top" ''
      # trim-top: remove the first N horizontal rows of pixels from the top of a
      # clipboard gif/image (default 1). Handy for shaving a leftover caption-edge
      # row. Every frame is cropped; result copied back as a uri-list.
      #   trim-top       # remove 1 top row
      #   trim-top 3     # remove 3 top rows
      set -euo pipefail

      OUTDIR="''${HOME}/Media/trim"; mkdir -p "$OUTDIR"
      N="''${1:-1}"
      printf '%s' "$N" | grep -qE '^[0-9]+$' || N=1

      notify() { ${pkgs.libnotify}/bin/notify-send "trim-top" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "trim-top: $1" >&2; exit 1; }

      TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

      # --- read gif/image from clipboard ---
      types="$(${pkgs.wl-clipboard}/bin/wl-paste --list-types 2>/dev/null || true)"
      in="$TMP/in"; src=""
      if printf '%s\n' "$types" | grep -qi 'image/gif'; then
        ${pkgs.wl-clipboard}/bin/wl-paste -t image/gif > "$in.gif"; src="$in.gif"
      elif printf '%s\n' "$types" | grep -q '^text/uri-list$'; then
        first="$(${pkgs.wl-clipboard}/bin/wl-paste -t text/uri-list 2>/dev/null \
                  | tr -d '\r' | sed 's|^file://||' | head -1)"
        [ -n "$first" ] || die "empty uri-list"
        src="$(printf '%b' "''${first//%/\\x}")"
      else
        for t in image/png image/jpeg image/webp; do
          if printf '%s\n' "$types" | grep -qi "$t"; then
            ext="''${t#image/}"; ${pkgs.wl-clipboard}/bin/wl-paste -t "$t" > "$in.$ext"; src="$in.$ext"; break
          fi
        done
        [ -n "$src" ] || die "clipboard has no image or gif"
      fi
      [ -f "$src" ] || die "source not found"

      W="$(${pkgs.imagemagick}/bin/identify -format '%W' "$src[0]")"
      H="$(${pkgs.imagemagick}/bin/identify -format '%H' "$src[0]")"
      printf '%s' "$W" | grep -qE '^[0-9]+$' || die "couldn't read dimensions"
      printf '%s' "$H" | grep -qE '^[0-9]+$' || die "couldn't read dimensions"

      [ "$N" -lt "$H" ] || die "can't remove $N rows from a $H-px-tall image"
      newH=$((H-N))

      mime="$(${pkgs.file}/bin/file --mime-type -b "$src")"
      stamp="$(date +%Y%m%d-%H%M%S)"

      case "$mime" in
        image/gif)
          out="$OUTDIR/trim-''${stamp}.gif"
          notify "removing $N top row(s) from gif..."
          ${pkgs.imagemagick}/bin/magick "$src" -coalesce \
            -crop "''${W}x''${newH}+0+''${N}" +repage \
            -layers optimize "$out" >/dev/null 2>&1 || die "trim failed"
          ;;
        image/*)
          out="$OUTDIR/trim-''${stamp}.png"
          notify "removing $N top row(s) from image..."
          ${pkgs.imagemagick}/bin/magick "$src" \
            -crop "''${W}x''${newH}+0+''${N}" +repage \
            "$out" >/dev/null 2>&1 || die "trim failed"
          ;;
        *) die "not an image or gif: $mime" ;;
      esac
      [ -f "$out" ] || die "output not produced"

      # --- write back as percent-encoded uri-list ---
      urlencode_path() {
        local p="$1" o="" c i h
        for (( i=0; i<''${#p}; i++ )); do
          c="''${p:i:1}"
          case "$c" in
            [a-zA-Z0-9._~/-]) o+="$c" ;;
            *) printf -v h '%%%02X' "'$c"; o+="$h" ;;
          esac
        done
        printf '%s' "$o"
      }
      urifile="$(mktemp)"
      printf 'file://%s\r\n' "$(urlencode_path "$out")" > "$urifile"
      ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c \
        "${pkgs.wl-clipboard}/bin/wl-copy -t text/uri-list < '$urifile'; rm -f '$urifile'" \
        </dev/null >/dev/null 2>&1 || true

      notify "done: $(basename "$out") — copied to clipboard"
    '';
  in {
    environment.systemPackages = [
      trimTop
      pkgs.imagemagick pkgs.file pkgs.wl-clipboard pkgs.libnotify
      pkgs.util-linux pkgs.bash pkgs.coreutils pkgs.gnused
    ];
  };
}
