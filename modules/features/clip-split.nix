{ self, inputs, ... }: {
  flake.nixosModules.clip-split = { pkgs, lib, ... }:
  let
    clipSplit = pkgs.writeShellScriptBin "clip-split" ''
      # clip-split: take a video from the clipboard (yazi yank / uri-list / path)
      # and split it into the fewest parts that each fit under Discord's 10MB
      # limit, keeping full quality (re-encodes at the source bitrate, never
      # above). Cuts are frame-accurate. All parts' paths are copied back as a
      # uri-list so they can be attached together in one drag.
      set -euo pipefail

      OUTDIR="''${HOME}/Media/splits"
      mkdir -p "$OUTDIR"

      CAP=9961472          # ~9.5MB usable target under Discord's 10MB cap
      AUDIO_BR=128000      # audio bitrate (bits/s) reserved per part
      MARGIN=0.92          # headroom on the size target
      ASSUMED_FPS=30       # for the quality-floor estimate

      notify() { ${pkgs.libnotify}/bin/notify-send "clip-split" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "clip-split: $1" >&2; exit 1; }

      # --- read a file path from the clipboard (same shapes as clip-to-gif) ---
      types="$(${pkgs.wl-clipboard}/bin/wl-paste --list-types 2>/dev/null || true)"
      if printf '%s\n' "$types" | grep -q '^text/uri-list$'; then
        first="$(${pkgs.wl-clipboard}/bin/wl-paste -t text/uri-list 2>/dev/null \
                  | tr -d '\r' | sed 's|^file://||' | head -1)"
        [ -n "$first" ] || die "empty uri-list on clipboard"
        src="$(printf '%b' "''${first//%/\\x}")"
      else
        raw="$(${pkgs.wl-clipboard}/bin/wl-paste 2>/dev/null || true)"
        raw="''${raw%$'\n'}"
        raw="''${raw#file://}"
        src="$(printf '%b' "''${raw//%/\\x}")"
      fi
      [ -f "$src" ] || die "clipboard doesn't point to a file: $src"

      kind="$(${pkgs.file}/bin/file --mime-type -b "$src")"
      case "$kind" in
        video/*) : ;;
        *) die "not a video: $kind" ;;
      esac

      # --- probe source ---
      dur="$(${pkgs.ffmpeg}/bin/ffprobe -v error -show_entries format=duration -of csv=p=0 "$src")"
      sw="$(${pkgs.ffmpeg}/bin/ffprobe -v error -select_streams v:0 -show_entries stream=width  -of csv=p=0 "$src")"
      sh="$(${pkgs.ffmpeg}/bin/ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$src")"
      bytes="$(${pkgs.coreutils}/bin/stat -c%s "$src")"
      [ -n "$dur" ] && [ -n "$sw" ] && [ -n "$sh" ] || die "couldn't probe video"
      src_br="$(${pkgs.gawk}/bin/awk "BEGIN{printf \"%d\", $bytes*8/$dur}")"

      # quality floor: ~0.1 bits per pixel-second; don't compress below this
      minbr="$(${pkgs.gawk}/bin/awk "BEGIN{printf \"%d\", $sw*$sh*$ASSUMED_FPS*0.1}")"

      # if the whole file already fits, nothing to split
      if [ "$bytes" -le "$CAP" ]; then
        die "already under 10MB — no split needed"
      fi

      # pick fewest parts whose per-part budget meets the floor (capped at source br)
      parts=0
      for p in $(seq 1 20); do
        chunk="$(${pkgs.gawk}/bin/awk "BEGIN{print $dur/$p}")"
        vbr="$(${pkgs.gawk}/bin/awk "BEGIN{printf \"%d\", ($CAP*$MARGIN*8 - $AUDIO_BR*$chunk)/$chunk}")"
        eff="$(${pkgs.gawk}/bin/awk "BEGIN{print ($vbr>$src_br)?$src_br:$vbr}")"
        if [ "$(${pkgs.gawk}/bin/awk "BEGIN{print ($eff>=$minbr)?1:0}")" = 1 ]; then
          parts=$p; break
        fi
      done
      [ "$parts" -gt 0 ] || parts=20   # extreme fallback

      chunk="$(${pkgs.gawk}/bin/awk "BEGIN{printf \"%.3f\", $dur/$parts}")"
      vbr="$(${pkgs.gawk}/bin/awk "BEGIN{v=($CAP*$MARGIN*8 - $AUDIO_BR*$chunk)/$chunk; if (v>$src_br) v=$src_br; printf \"%d\", v}")"

      notify "splitting into $parts part(s)..."
      base="$(basename "$src")"; base="''${base%.*}"
      stamp="$(date +%Y%m%d-%H%M%S)"

      uris=""
      i=0
      while [ "$i" -lt "$parts" ]; do
        ss="$(${pkgs.gawk}/bin/awk "BEGIN{printf \"%.3f\", $i*$chunk}")"
        out="$OUTDIR/''${base}-''${stamp}-part$((i+1)).mp4"
        ${pkgs.ffmpeg}/bin/ffmpeg -y -ss "$ss" -i "$src" -t "$chunk" \
          -c:v libx264 -b:v "$vbr" -maxrate "$vbr" -bufsize "$((vbr*2))" \
          -preset veryfast -pix_fmt yuv420p \
          -c:a aac -b:a 128k -movflags +faststart \
          "$out" >/dev/null 2>&1 || die "encode of part $((i+1)) failed"
        uris="''${uris}file://''${out}"$'\n'
        i=$((i+1))
      done

      # copy all parts as one uri-list so they attach together
      ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c \
        "printf '%s' \"$uris\" | ${pkgs.wl-clipboard}/bin/wl-copy -t text/uri-list" \
        </dev/null >/dev/null 2>&1 || true

      notify "done: $parts part(s) in $OUTDIR, copied to clipboard"
      printf '%s' "$uris"
    '';
  in {
    environment.systemPackages = [ clipSplit pkgs.ffmpeg pkgs.file pkgs.wl-clipboard pkgs.libnotify pkgs.util-linux pkgs.bash pkgs.coreutils pkgs.gawk ];
  };
}
