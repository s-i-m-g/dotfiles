{ self, inputs, ... }: {
  flake.nixosModules.upload-video = { pkgs, lib, ... }:
  let
    uploadVideo = pkgs.writeShellScriptBin "upload-video" ''
      # upload-video: upload the clipboard video to pixeldrain and copy the
      # direct file URL back (plain text) so Discord embeds it inline.
      # Reads the API key from ~/.config/pixeldrain-key (kept OUT of the
      # world-readable nix store). Verifies the uploaded size matches the local
      # file before copying, so a partial upload never becomes a dead link.
      set -euo pipefail

      KEYFILE="''${HOME}/.config/pixeldrain-key"
      TRIES=3
      UA="Mozilla/5.0 (X11; Linux x86_64) upload-video/1.0"

      notify() { ${pkgs.libnotify}/bin/notify-send "upload-video" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "upload-video: $1" >&2; exit 1; }

      C="${pkgs.curl}/bin/curl"
      JQ="${pkgs.jq}/bin/jq"

      [ -r "$KEYFILE" ] || die "no API key at $KEYFILE"
      apikey="$(${pkgs.coreutils}/bin/tr -d '[:space:]' < "$KEYFILE")"
      [ -n "$apikey" ] || die "API key file is empty"

      # --- read a file path from the clipboard ---
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
      case "$kind" in video/*) : ;; *) die "not a video: $kind" ;; esac

      localbytes="$(${pkgs.coreutils}/bin/stat -c%s "$src")"
      [ "$localbytes" -gt 0 ] || die "local file is empty"

      fname="$(basename "$src")"
      encname="$(printf '%s' "$fname" | "$JQ" -sRr @uri)"

      verify() {
        local u="$1" rb
        rb="$($C -fsSL -A "$UA" -I "$u" 2>/dev/null \
              | ${pkgs.gnugrep}/bin/grep -i '^content-length:' \
              | ${pkgs.gnused}/bin/sed 's/[^0-9]//g' | tail -1)"
        [ -n "$rb" ] && [ "$rb" = "$localbytes" ]
      }

      url=""
      attempt=1
      while [ "$attempt" -le "$TRIES" ]; do
        notify "uploading $fname"
        resp="$($C -fsS -A "$UA" -u ":$apikey" -T "$src" \
          "https://pixeldrain.com/api/file/$encname" 2>/dev/null || true)"
        id="$(printf '%s' "$resp" | "$JQ" -r '.id // empty' 2>/dev/null || true)"
        if [ -n "$id" ]; then
          cand="https://pixeldrain.com/api/file/$id"
          if verify "$cand"; then url="$cand"; break; fi
          notify "upload incomplete, retrying..."
        else
          notify "upload attempt failed, retrying..."
        fi
        attempt=$((attempt+1))
        sleep 2
      done

      [ -n "$url" ] || die "upload failed or incomplete after $TRIES tries"

      urlfile="$(mktemp)"
      printf '%s' "$url" > "$urlfile"
      ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c \
        "${pkgs.wl-clipboard}/bin/wl-copy < '$urlfile'; rm -f '$urlfile'" \
        </dev/null >/dev/null 2>&1 || true

      notify "done"
      echo "$url"
    '';
  in {
    environment.systemPackages = [
      uploadVideo pkgs.curl pkgs.jq pkgs.file pkgs.wl-clipboard pkgs.libnotify
      pkgs.util-linux pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.gnused
    ];
  };
}
