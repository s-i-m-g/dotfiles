{ self, inputs, ... }: {
  flake.nixosModules.dl-media = { pkgs, lib, ... }:
  let
    dlMedia = pkgs.writeShellScriptBin "dl-media" ''
      # dl-media: download the media link on the clipboard as-is (image stays
      # an image, video stays a video), sorted by source site into
      # ~/Media/{youtube,instagram,discord,other}, then copy the downloaded
      # file back to the clipboard as a percent-encoded uri-list.
      # YouTube/Instagram/embeds go through yt-dlp (with zen browser cookies
      # to pass YouTube/Instagram's bot checks); Discord attachment links are
      # direct CDN files fetched with curl.
      set -euo pipefail

      BASE="''${HOME}/Media"
      # zen is firefox-based; point yt-dlp at its profile for cookies.
      # NOTE: zen must be CLOSED when downloading, or the cookies db is locked.
      ZEN_PROFILE="''${HOME}/.config/zen/p31tprts.Default Profile"

      notify() { ${pkgs.libnotify}/bin/notify-send "dl-media" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "dl-media: $1" >&2; exit 1; }

      # percent-encode a filesystem path for a file:// URI (keeps '/' as-is)
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

      copy_back() {
        local urifile
        urifile="$(mktemp)"
        printf 'file://%s\n' "$(urlencode_path "$1")" > "$urifile"
        ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c \
          "${pkgs.wl-clipboard}/bin/wl-copy -t text/uri-list < '$urifile'; rm -f '$urifile'" \
          </dev/null >/dev/null 2>&1 || true
      }

      # --- read the URL from the clipboard ---
      url="$(${pkgs.wl-clipboard}/bin/wl-paste 2>/dev/null || true)"
      url="$(printf '%s' "$url" | tr -d '[:space:]')"
      [ -n "$url" ] || die "clipboard is empty"

      case "$url" in
        *youtube.com/*|*youtu.be/*) site=youtube ;;
        *instagram.com/*)           site=instagram ;;
        *cdn.discordapp.com/*|*media.discordapp.net/*|*discord.com/*) site=discord ;;
        http://*|https://*)         site=other ;;
        *) die "clipboard isn't a URL: $url" ;;
      esac

      OUTDIR="$BASE/$site"
      mkdir -p "$OUTDIR"
      notify "downloading ($site)..."

      if [ "$site" = discord ]; then
        # direct CDN file: filename from the URL path, query params stripped,
        # percent-decoded (e.g. my%20clip.mp4 -> my clip.mp4)
        fname="''${url%%\?*}"; fname="''${fname##*/}"
        fname="$(printf '%b' "''${fname//%/\\x}")"
        out="$OUTDIR/$fname"
        if [ -e "$out" ]; then
          out="$OUTDIR/$(date +%Y%m%d-%H%M%S)-$fname"
        fi
        ${pkgs.curl}/bin/curl -fsSL "$url" -o "$out" || die "download failed (link may be expired)"
      else
        # cookies help pass YouTube/Instagram bot checks. If zen is open the db
        # is locked — fall back to a cookieless attempt so it still works for
        # sources that don't require auth.
        cookie_args=()
        if [ -d "$ZEN_PROFILE" ]; then
          cookie_args=(--cookies-from-browser "firefox:$ZEN_PROFILE")
        fi
        out="$(${pkgs.yt-dlp}/bin/yt-dlp \
          --no-playlist \
          "''${cookie_args[@]}" \
          -o "$OUTDIR/%(title).80B [%(id)s].%(ext)s" \
          --no-simulate --print after_move:filepath \
          "$url" 2>/dev/null | tail -1)" \
          || out="$(${pkgs.yt-dlp}/bin/yt-dlp \
               --no-playlist \
               -o "$OUTDIR/%(title).80B [%(id)s].%(ext)s" \
               --no-simulate --print after_move:filepath \
               "$url" 2>/dev/null | tail -1)" \
          || die "yt-dlp failed"
        [ -n "$out" ] && [ -f "$out" ] || die "download produced no file"
      fi

      copy_back "$out"
      notify "saved $(basename "$out")"
      echo "$out"
    '';
  in {
    environment.systemPackages = [
      dlMedia pkgs.yt-dlp pkgs.curl pkgs.wl-clipboard pkgs.libnotify pkgs.util-linux pkgs.bash
    ];
  };
}
