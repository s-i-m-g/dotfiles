{ self, inputs, ... }: {
  flake.nixosModules.caption-gif = { pkgs, lib, ... }:
  let
    # caption.ttf lives next to this module; Nix copies it into the store and
    # this evaluates to its /nix/store/...-caption.ttf path, so the font travels
    # with the config instead of depending on a file in ~/.local/share/fonts.
    captionFont = ./caption.ttf;

    captionRun = pkgs.writeShellScriptBin "caption-gif-run" ''
      set -uo pipefail
      OUTDIR="''${HOME}/Media/captioned"
      mkdir -p "$OUTDIR"
      # caption font: shipped in the Nix config next to this module.
      FONT="${captionFont}"
      notify() { ${pkgs.libnotify}/bin/notify-send "caption-gif" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "caption-gif: $1" >&2; sleep 2; exit 1; }
      urlencode_path() {
        local p="$1" out="" c i h
        for (( i=0; i<''${#p}; i++ )); do
          c="''${p:i:1}"
          case "$c" in
            [a-zA-Z0-9._~/-]) out+="$c" ;;
            *) printf -v h '%%%02X' "'$c"; out+="$h" ;;
          esac
        done
        printf '%s' "$out"
      }
      # --- read gif/image path from clipboard ---
      types="$(${pkgs.wl-clipboard}/bin/wl-paste --list-types 2>/dev/null || true)"
      if printf '%s\n' "$types" | grep -q '^text/uri-list$'; then
        first="$(${pkgs.wl-clipboard}/bin/wl-paste -t text/uri-list 2>/dev/null \
                  | tr -d '\r' | sed 's|^file://||' | head -1)"
        [ -n "$first" ] || die "empty uri-list on clipboard"
        src="$(printf '%b' "''${first//%/\\x}")"
      elif printf '%s\n' "$types" | grep -q '^image/'; then
        ext="$(printf '%s\n' "$types" | grep -m1 '^image/')"; ext="''${ext#image/}"
        src="$(mktemp --suffix=".$ext")"
        ${pkgs.wl-clipboard}/bin/wl-paste -t "image/$ext" > "$src" || die "couldn't read image"
      else
        raw="$(${pkgs.wl-clipboard}/bin/wl-paste 2>/dev/null || true)"
        raw="''${raw%$'\n'}"; raw="''${raw#file://}"
        src="$(printf '%b' "''${raw//%/\\x}")"
      fi
      [ -f "$src" ] || die "clipboard doesn't point to an image/gif: $src"
      # --- caption input (empty box, no prompt text) ---
      IFS= read -r caption || true
      [ -n "$caption" ] || die "empty caption"
      # --- render white caption bar atop every frame ---
      w="$(${pkgs.imagemagick}/bin/magick identify -format '%w\n' "$src" 2>/dev/null | head -1)"
      [ -n "$w" ] || die "couldn't read image width"
      cap="$(mktemp --suffix=.png)"
      spl="$(mktemp --suffix=.gif)"
      out="$OUTDIR/cap-$(date +%Y%m%d-%H%M%S).gif"
      ${pkgs.imagemagick}/bin/magick -background white -fill black \
        -font "$FONT" -weight Bold -kerning -2\
        -size $((w - 20))x -gravity center -pointsize 60 \
        caption:"$caption" -bordercolor white -border 20x20 "$cap" \
        || die "caption render failed"
      caph="$(${pkgs.imagemagick}/bin/magick identify -format '%h\n' "$cap" | head -1)"
      ${pkgs.imagemagick}/bin/magick "$src" -coalesce -gravity North \
        -background white -splice 0x''${caph} "$spl" || die "splice failed"
      ${pkgs.imagemagick}/bin/magick "$spl" -coalesce null: "$cap" \
        -gravity North -geometry +0+0 -layers composite -layers optimize "$out" \
        || die "composite failed"
      rm -f "$cap" "$spl"
      [ -f "$out" ] || die "no output produced"
      # --- copy result back as a uri-list ---
      urifile="$(mktemp)"
      printf 'file://%s\n' "$(urlencode_path "$out")" > "$urifile"
      ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c \
        "${pkgs.wl-clipboard}/bin/wl-copy -t text/uri-list < '$urifile'; rm -f '$urifile'" \
        </dev/null >/dev/null 2>&1 || true
      notify "done"
    '';
    captionGif = pkgs.writeShellScriptBin "caption-gif" ''
      exec ${pkgs.kitty}/bin/kitty --class captionbox \
        -o initial_window_width=60c -o initial_window_height=6c \
        -o font_size=14 \
        -e ${captionRun}/bin/caption-gif-run
    '';
  in {
    environment.systemPackages = [
      captionGif captionRun
      pkgs.imagemagick pkgs.wl-clipboard pkgs.libnotify pkgs.util-linux pkgs.bash
      pkgs.dejavu_fonts pkgs.kitty
    ];
  };
}
