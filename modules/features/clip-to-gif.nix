{ self, inputs, ... }: {
  flake.nixosModules.clip-to-gif = { pkgs, lib, ... }:
  let
    clipToGif = pkgs.writeShellScriptBin "clip-to-gif" ''
      # clip-to-gif: convert whatever is on the clipboard into a gif and copy it
      # back as a file:// uri-list (like yazi Y) so Discord uploads it as an
      # attachment. Images -> imagemagick (clean full palette, native size).
      # Videos -> ffmpeg. Probes the source (duration + resolution) to PREDICT
      # output size and start at the highest quality tier likely to fit under
      # Discord's 10MB cap, then verifies and steps down once more if needed.
      set -euo pipefail

      OUTDIR="''${HOME}/Media/gifs"
      mkdir -p "$OUTDIR"

      # Discord non-Nitro upload cap is 10MB; target ~9.5MB for margin.
      MAXBYTES=9961472
      # calibrated bytes per (pixel * frame) for a bayer-dithered gif; tuned
      # toward the quality side since a post-encode check catches overshoots.
      K=85

      notify() { ${pkgs.libnotify}/bin/notify-send "clip-to-gif" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "clip-to-gif: $1" >&2; exit 1; }

      workdir="$(mktemp -d)"
      trap 'rm -rf "$workdir"' EXIT
      src=""

      types="$(${pkgs.wl-clipboard}/bin/wl-paste --list-types 2>/dev/null || true)"

      if printf '%s\n' "$types" | grep -q '^text/uri-list$'; then
        first="$(${pkgs.wl-clipboard}/bin/wl-paste -t text/uri-list 2>/dev/null \
                  | tr -d '\r' | sed 's|^file://||' | head -1)"
        [ -n "$first" ] || die "empty uri-list on clipboard"
        src="$(printf '%b' "''${first//%/\\x}")"
        [ -f "$src" ] || die "uri-list points to a missing file: $src"
      elif printf '%s\n' "$types" | grep -q '^image/'; then
        img_mime="$(printf '%s\n' "$types" | grep -m1 '^image/')"
        ext="''${img_mime#image/}"
        src="$workdir/clip.$ext"
        ${pkgs.wl-clipboard}/bin/wl-paste -t "$img_mime" > "$src" \
          || die "couldn't read image from clipboard"
      else
        raw="$(${pkgs.wl-clipboard}/bin/wl-paste 2>/dev/null || true)"
        raw="''${raw%$'\n'}"
        [ -n "$raw" ] || die "clipboard is empty"
        raw="''${raw#file://}"
        p="$(printf '%b' "''${raw//%/\\x}")"
        [ -f "$p" ] || die "clipboard isn't an image, video, or valid file path"
        src="$p"
      fi

      kind="$(${pkgs.file}/bin/file --mime-type -b "$src")"
      stamp="$(date +%Y%m%d-%H%M%S)"
      out="$OUTDIR/gif-$stamp.gif"

      fits() { [ "$(${pkgs.coreutils}/bin/stat -c%s "$out")" -le "$MAXBYTES" ]; }

      case "$kind" in
        image/*)
          ${pkgs.imagemagick}/bin/magick "$src" "$out" || die "image->gif failed"
          ;;
        video/*)
          # probe source geometry + duration
          sw="$(${pkgs.ffmpeg}/bin/ffprobe -v error -select_streams v:0 \
                 -show_entries stream=width  -of csv=p=0 "$src")"
          sh="$(${pkgs.ffmpeg}/bin/ffprobe -v error -select_streams v:0 \
                 -show_entries stream=height -of csv=p=0 "$src")"
          dur="$(${pkgs.ffmpeg}/bin/ffprobe -v error \
                 -show_entries format=duration -of csv=p=0 "$src")"
          # sane fallbacks if probing fails
          [ -n "$sw" ] || sw=1280; [ -n "$sh" ] || sh=720; [ -n "$dur" ] || dur=10

          # tier ladder: "fps width" (width 0 = native). native fps assumed 30 for prediction.
          tiers="0:0 20:1280 20:720 15:640 12:540 10:480"

          # pick the first tier whose predicted bytes <= cap
          chosen=""
          for t in $tiers; do
            f="''${t%%:*}"; tw="''${t##*:}"
            ef=$f; [ "$f" = 0 ] && ef=30
            etw=$tw; [ "$tw" = 0 ] && etw=$sw
            [ "$etw" -gt "$sw" ] && etw=$sw
            eth="$(${pkgs.gawk}/bin/awk "BEGIN{printf \"%d\", $sh*$etw/$sw}")"
            pred="$(${pkgs.gawk}/bin/awk "BEGIN{printf \"%d\", $K/1000*$ef*$etw*$eth*$dur}")"
            if [ "$pred" -le "$MAXBYTES" ]; then chosen="$t"; break; fi
          done
          # if nothing predicted to fit, use the smallest tier
          [ -n "$chosen" ] || chosen="10:480"

          encode() {
            local f="''${1%%:*}" tw="''${1##*:}"
            if [ "$f" = 0 ] && [ "$tw" = 0 ]; then
              ${pkgs.ffmpeg}/bin/ffmpeg -y -i "$src" \
                -vf "split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
                "$out" >/dev/null 2>&1
            else
              ${pkgs.ffmpeg}/bin/ffmpeg -y -i "$src" \
                -vf "fps=$f,scale=$tw:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
                "$out" >/dev/null 2>&1
            fi
          }

          notify "converting"
          encode "$chosen" || die "video->gif failed"

          # verify; if the estimate was optimistic, step down through remaining tiers
          if ! fits; then
            past=1
            for t in $tiers; do
              [ "$t" = "$chosen" ] && { past=0; continue; }
              [ "$past" = 1 ] && continue
              notify "too big, re-encoding (''${t})..."
              encode "$t" || die "video->gif re-encode failed"
              fits && break
            done
          fi
          fits || notify "warning: still over 10MB even at lowest tier"
          ;;
        *)
          die "unsupported type: $kind"
          ;;
      esac

      ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c \
        "printf 'file://%s\n' '$out' | ${pkgs.wl-clipboard}/bin/wl-copy -t text/uri-list" \
        </dev/null >/dev/null 2>&1 || true

      sz="$(${pkgs.coreutils}/bin/du -h "$out" | cut -f1)"
      notify "done"
      echo "$out"
    '';
  in {
    environment.systemPackages = [ clipToGif pkgs.imagemagick pkgs.ffmpeg pkgs.file pkgs.wl-clipboard pkgs.libnotify pkgs.util-linux pkgs.bash pkgs.coreutils pkgs.gawk ];
  };
}
