{ self, inputs, ... }: {
  flake.nixosModules.clip-split = { pkgs, lib, ... }:
  let
    amdRenderNode = "/dev/dri/renderD129";  # AMD iGPU node (same as screen-record)

    clipSplit = pkgs.writeShellScriptBin "clip-split" ''
      # clip-split: split a clipboard video into the FEWEST parts each under
      # Discord's 10MB cap, with NO overlap and NO gaps. Forces keyframes at the
      # cut points and segments on those points for clean partitioning, and
      # encodes on the AMD GPU (VAAPI) so it's fast and near-zero CPU.
      #
      # Parts are then copied to the clipboard in BATCHES of <=10 (Discord's
      # per-message file limit). Clipboard history is last-in-first-out, so we
      # copy the LAST batch first and the FIRST batch last: batch 1 ends up as the
      # current clipboard, and the later batches sit below it in history (batch 1
      # on top, then 2, ...). Each batch is one uri-list so it attaches in one drag.
      set -euo pipefail

      OUTDIR="''${HOME}/Media/splits"
      mkdir -p "$OUTDIR"

      CAP=10485760         # Discord's hard 10MB cap
      TARGET_FRAC=0.90     # aim parts at ~90% of the cap for headroom
      BATCH=10             # Discord's per-message file cap

      notify() { ${pkgs.libnotify}/bin/notify-send "clip-split" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "clip-split: $1" >&2; exit 1; }

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
      case "$kind" in
        video/*) : ;;
        *) die "not a video: $kind" ;;
      esac

      # --- probe ---
      dur="$(${pkgs.ffmpeg}/bin/ffprobe -v error -show_entries format=duration -of csv=p=0 "$src")"
      bytes="$(${pkgs.coreutils}/bin/stat -c%s "$src")"
      [ -n "$dur" ] && [ -n "$bytes" ] || die "couldn't probe video"

      if [ "$bytes" -le "$CAP" ]; then
        die "already under 10MB — no split needed"
      fi

      srcbr="$(${pkgs.gawk}/bin/awk "BEGIN{printf \"%d\", $bytes*8/$dur}")"
      base="$(basename "$src")"; base="''${base%.*}"
      stamp="$(date +%Y%m%d-%H%M%S)"

      target="$(${pkgs.gawk}/bin/awk "BEGIN{printf \"%d\", $CAP*$TARGET_FRAC}")"
      parts="$(${pkgs.gawk}/bin/awk "BEGIN{p=int(($bytes + $target - 1)/$target); print (p<1)?1:p}")"

      notify "splitting (GPU encode)..."

      # --- encode + segment; verify each part fits, add a part and retry if not ---
      final_parts=0
      while :; do
        chunk="$(${pkgs.gawk}/bin/awk "BEGIN{printf \"%.3f\", $dur/$parts}")"

        cuts=""
        i=1
        while [ "$i" -lt "$parts" ]; do
          t="$(${pkgs.gawk}/bin/awk "BEGIN{printf \"%.3f\", $i*$chunk}")"
          cuts="''${cuts}''${cuts:+,}$t"
          i=$((i+1))
        done

        rm -f "$OUTDIR/''${base}-''${stamp}-part"*.mp4

        # VAAPI hardware encode on the AMD node. Upload frames to the GPU
        # (format=nv12,hwupload) and encode h264_vaapi at ~source bitrate.
        # Forced keyframes at the cut points + segment on the same points =
        # clean, non-overlapping parts.
        ${pkgs.ffmpeg}/bin/ffmpeg -y \
          -vaapi_device ${amdRenderNode} \
          -i "$src" \
          -force_key_frames "$cuts" \
          -vf 'format=nv12,hwupload' \
          -c:v h264_vaapi -b:v "$srcbr" -maxrate "$srcbr" \
          -c:a aac -b:a 128k -movflags +faststart \
          -f segment -segment_times "$cuts" -reset_timestamps 1 \
          -segment_start_number 1 \
          "$OUTDIR/''${base}-''${stamp}-part%d.mp4" >/dev/null 2>&1 \
          || die "GPU encode/segment failed (VAAPI node? codec?)"

        allfit=1
        for f in "$OUTDIR/''${base}-''${stamp}-part"*.mp4; do
          psz="$(${pkgs.coreutils}/bin/stat -c%s "$f")"
          [ "$psz" -gt "$CAP" ] && allfit=0
        done

        if [ "$allfit" = 1 ]; then
          final_parts=$parts
          break
        fi
        parts=$((parts+1))
        [ "$parts" -gt 30 ] && die "couldn't get parts under 10MB even at 30 splits"
      done

      # --- collect the parts in order ---
      files=()
      i=1
      while [ "$i" -le "$final_parts" ]; do
        f="$OUTDIR/''${base}-''${stamp}-part$i.mp4"
        [ -f "$f" ] || die "expected part $i missing"
        files+=("$f")
        i=$((i+1))
      done

      # number of batches = ceil(final_parts / BATCH)
      nbatches="$(${pkgs.gawk}/bin/awk "BEGIN{print int(($final_parts + $BATCH - 1)/$BATCH)}")"

      # Copy batches in REVERSE order (last batch first) so batch 1 ends up current.
      # Each wl-copy must fully land in cliphist before the next overwrites the
      # clipboard, so these run SYNCHRONOUSLY (not setsid -f) with a small settle.
      b="$nbatches"
      while [ "$b" -ge 1 ]; do
        start=$(( (b-1)*BATCH ))          # 0-based index of first file in this batch
        end=$(( start + BATCH ))
        uris=""
        j="$start"
        while [ "$j" -lt "$end" ] && [ "$j" -lt "$final_parts" ]; do
          enc="$(printf '%s' "''${files[$j]}" | ${pkgs.gnused}/bin/sed 's/ /%20/g')"
          uris="''${uris}file://''${enc}"$'\n'
          j=$((j+1))
        done
        tmpf="$(mktemp)"
        printf '%s' "$uris" > "$tmpf"
        ${pkgs.wl-clipboard}/bin/wl-copy -t text/uri-list < "$tmpf"
        rm -f "$tmpf"
        sleep 0.4      # let cliphist record this entry before the next overwrites
        b=$((b-1))
      done

      notify "done: $final_parts parts in $nbatches batch(es) of ≤$BATCH — batch 1 on clipboard, rest in history"
      printf 'split into %d parts, %d batch(es)\n' "$final_parts" "$nbatches"
    '';
  in {
    environment.systemPackages = [
      clipSplit pkgs.ffmpeg pkgs.file pkgs.wl-clipboard pkgs.libnotify
      pkgs.util-linux pkgs.bash pkgs.coreutils pkgs.gawk pkgs.gnused
    ];
  };
}
