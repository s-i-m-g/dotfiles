{ self, inputs, ... }: {
  flake.nixosModules.to-mp4 = { pkgs, lib, ... }:
  let
    toMp4 = pkgs.writeShellScriptBin "to-mp4" ''
      # to-mp4: convert the video on the clipboard (mkv/webm/mov/avi/...) into an
      # mp4. Remuxes losslessly when the codecs are already mp4-native
      # (h264/hevc/av1 video, aac/mp3/ac3 audio); re-encodes to h264/aac only
      # when they aren't (e.g. vp9/opus from a webm). Copies the result back to
      # the clipboard as a percent-encoded uri-list.
      set -euo pipefail

      OUTDIR="''${HOME}/Media/mp4"
      mkdir -p "$OUTDIR"

      notify() { ${pkgs.libnotify}/bin/notify-send "to-mp4" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "to-mp4: $1" >&2; exit 1; }

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

      # --- read a file path from the clipboard (same shapes as the other scripts) ---
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

      # already an mp4? still normalize codecs if needed, but usually a no-op copy
      base="$(basename "$src")"; base="''${base%.*}"
      out="$OUTDIR/$base.mp4"
      [ "$(${pkgs.coreutils}/bin/realpath "$src")" = "$(${pkgs.coreutils}/bin/realpath "$out" 2>/dev/null || echo)" ] \
        && out="$OUTDIR/$base-$(date +%Y%m%d-%H%M%S).mp4"

      vc="$(${pkgs.ffmpeg}/bin/ffprobe -v error -select_streams v:0 \
             -show_entries stream=codec_name -of csv=p=0 "$src" 2>/dev/null || true)"
      ac="$(${pkgs.ffmpeg}/bin/ffprobe -v error -select_streams a:0 \
             -show_entries stream=codec_name -of csv=p=0 "$src" 2>/dev/null || true)"

      case "$vc" in h264|hevc|av1|mpeg4) vcopy=1 ;; *) vcopy=0 ;; esac
      case "$ac" in aac|mp3|ac3|"") acopy=1 ;; *) acopy=0 ;; esac

      va=(); aa=()
      if [ "$vcopy" = 1 ]; then va=(-c:v copy); else va=(-c:v libx264 -crf 20 -preset veryfast -pix_fmt yuv420p); fi
      if [ "$acopy" = 1 ]; then aa=(-c:a copy); else aa=(-c:a aac -b:a 192k); fi

      if [ "$vcopy" = 1 ] && [ "$acopy" = 1 ]; then
        notify "remuxing (lossless)..."
      else
        notify "re-encoding to h264/aac..."
      fi

      ${pkgs.ffmpeg}/bin/ffmpeg -y -i "$src" "''${va[@]}" "''${aa[@]}" \
        -movflags +faststart "$out" >/dev/null 2>&1 || die "conversion failed"

      # copy result back as a percent-encoded uri-list
      urifile="$(mktemp)"
      printf 'file://%s\n' "$(urlencode_path "$out")" > "$urifile"
      ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c \
        "${pkgs.wl-clipboard}/bin/wl-copy -t text/uri-list < '$urifile'; rm -f '$urifile'" \
        </dev/null >/dev/null 2>&1 || true

      notify "saved $(basename "$out")"
      echo "$out"
    '';
  in {
    environment.systemPackages = [
      toMp4 pkgs.ffmpeg pkgs.file pkgs.wl-clipboard pkgs.libnotify pkgs.util-linux pkgs.bash pkgs.coreutils
    ];
  };
}
