{ self, inputs, ... }: {
  flake.nixosModules.to-kdenlive = { pkgs, lib, ... }:
  let
    toKdenlive = pkgs.writeShellScriptBin "to-kdenlive" ''
      # to-kdenlive: add the clipboard's file(s) to the RUNNING kdenlive project's
      # bin, via kdenlive's D-Bus method addProjectClip. Reads a text/uri-list from
      # the clipboard (your file-link convention), decodes each path, and calls the
      # method on whichever kdenlive instance is currently running.
      set -euo pipefail

      notify() { ${pkgs.libnotify}/bin/notify-send "to-kdenlive" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "to-kdenlive: $1" >&2; exit 1; }

      # --- find the running kdenlive D-Bus service (name is org.kde.kdenlive-<pid>) ---
      svc="$(${pkgs.busctl or pkgs.systemd}/bin/busctl --user list 2>/dev/null \
             | ${pkgs.gawk}/bin/awk '/org\.kde\.kdenlive-/ {print $1; exit}')"
      [ -n "$svc" ] || die "kdenlive isn't running (no D-Bus service found)"

      OBJ="/kdenlive/MainWindow_1"
      IFACE="org.kde.kdenlive.MainWindow"

      # --- gather file paths from the clipboard uri-list ---
      types="$(${pkgs.wl-clipboard}/bin/wl-paste --list-types 2>/dev/null || true)"
      printf '%s\n' "$types" | grep -q '^text/uri-list$' \
        || die "clipboard has no file link (text/uri-list)"

      mapfile -t uris < <(${pkgs.wl-clipboard}/bin/wl-paste -t text/uri-list 2>/dev/null | tr -d '\r')

      added=0
      for u in "''${uris[@]}"; do
        [ -n "$u" ] || continue
        p="''${u#file://}"
        # percent-decode
        p="$(printf '%b' "''${p//%/\\x}")"
        [ -f "$p" ] || { notify "skip (not a file): $p"; continue; }

        ${pkgs.busctl or pkgs.systemd}/bin/busctl --user call \
          "$svc" "$OBJ" "$IFACE" addProjectClip s "$p" >/dev/null 2>&1 \
          || { notify "failed to add: $(basename "$p")"; continue; }
        added=$((added+1))
      done

      if [ "$added" -gt 0 ]; then
        notify "added $added clip(s) to kdenlive project"
      else
        die "nothing added"
      fi
    '';
  in {
    environment.systemPackages = [
      toKdenlive pkgs.wl-clipboard pkgs.libnotify pkgs.gawk pkgs.coreutils pkgs.systemd
    ];
  };
}
