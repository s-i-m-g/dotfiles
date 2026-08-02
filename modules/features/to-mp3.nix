{ self, inputs, ... }: {
  flake.nixosModules.to-mp3 = { pkgs, lib, ... }:
  let
    toMp3 = pkgs.writeShellScriptBin "to-mp3" ''
      # to-mp3: take an audio file (or a video to extract audio from) from the
      # clipboard and produce an MP3 — the format Discord plays inline most
      # reliably. If the source audio is already MP3 it's remuxed (copied, no
      # re-encode); otherwise it's transcoded with libmp3lame at 192k. Any video
      # stream is dropped. The result is copied back as a uri-list so it attaches.
      set -euo pipefail

      OUTDIR="''${HOME}/Media/audio"
      mkdir -p "$OUTDIR"
      BITRATE="256k"

      notify() { ${pkgs.libnotify}/bin/notify-send "to-mp3" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "to-mp3: $1" >&2; exit 1; }

      # --- read a file path from the clipboard (same shapes as to-mp4) ---
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
        audio/*|video/*) : ;;
        *) die "not audio or video: $kind" ;;
      esac

      # --- must have an audio stream ---
      acodec="$(${pkgs.ffmpeg}/bin/ffprobe -v error -select_streams a:0 \
                 -show_entries stream=codec_name -of csv=p=0 "$src" 2>/dev/null | head -1)"
      [ -n "$acodec" ] || die "no audio stream in this file"

      base="$(basename "$src")"; base="''${base%.*}"
      stamp="$(date +%Y%m%d-%H%M%S)"
      out="$OUTDIR/''${base}-''${stamp}.mp3"

      if [ "$acodec" = "mp3" ]; then
        # already MP3 audio — copy it into an mp3 container, drop any video
        notify "remuxing (already MP3)..."
        ${pkgs.ffmpeg}/bin/ffmpeg -y -i "$src" -vn -c:a copy "$out" \
          >/dev/null 2>&1 || die "remux failed"
      else
        notify "transcoding $acodec → MP3..."
        ${pkgs.ffmpeg}/bin/ffmpeg -y -i "$src" -vn \
          -c:a libmp3lame -b:a "$BITRATE" -id3v2_version 3 "$out" \
          >/dev/null 2>&1 || die "transcode failed"
      fi

      [ -f "$out" ] || die "output not produced"

      # --- copy result back as a percent-encoded uri-list ---
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

      urifile="$(mktemp)"
      printf 'file://%s\r\n' "$(urlencode_path "$out")" > "$urifile"
      ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c \
        "${pkgs.wl-clipboard}/bin/wl-copy -t text/uri-list < '$urifile'; rm -f '$urifile'" \
        </dev/null >/dev/null 2>&1 || true

      notify "done: $(basename "$out") — copied to clipboard"
      printf '%s\n' "$out"
    '';
  in {
    environment.systemPackages = [
      toMp3 pkgs.ffmpeg pkgs.file pkgs.wl-clipboard pkgs.libnotify
      pkgs.util-linux pkgs.bash pkgs.coreutils pkgs.gnused
    ];
  };
}
