{ self, inputs, ... }: {
  flake.nixosModules.screen-record = { pkgs, lib, ... }:
  let
    audioDev = "bluez_output.BC_0F_F3_A0_63_A7.1.monitor";
    amdRenderNode = "/dev/dri/renderD129";  # AMD iGPU (PCI:5:0:0) — drives the display

    rec-start = pkgs.writeShellScriptBin "rec-start" ''
      # rec-start: begin a fullscreen recording of eDP-1 with system audio,
      # using VAAPI HARDWARE encoding on the AMD iGPU (which drives the display).
      # Frames are captured via DMA-BUF and encoded in place on the AMD GPU — no
      # cross-GPU copy, no software encode, so the CPU stays near idle even while
      # gaming. (YUV colors — the tradeoff for hardware encoding.)
      set -euo pipefail

      OUTDIR="''${HOME}/Media/recordings"
      mkdir -p "$OUTDIR"
      PIDFILE="''${XDG_RUNTIME_DIR:-/tmp}/wf-recorder.pid"
      FILEREF="''${XDG_RUNTIME_DIR:-/tmp}/wf-recorder.file"

      notify() { ${pkgs.libnotify}/bin/notify-send "screen-record" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "rec-start: $1" >&2; exit 1; }

      if [ -f "$PIDFILE" ] && ${pkgs.procps}/bin/kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        die "already recording (run rec-stop)"
      fi

      mapfile -t outs < <(${pkgs.wlr-randr}/bin/wlr-randr --json \
        | ${pkgs.jq}/bin/jq -r '.[].name')
      [ "''${#outs[@]}" -gt 0 ] || die "no outputs found"
      if [ "''${#outs[@]}" -eq 1 ]; then
        output="''${outs[0]}"
      else
        output="$(printf '%s\n' "''${outs[@]}" \
          | ${pkgs.rofi}/bin/rofi -dmenu -p "record which monitor?")"
        [ -n "$output" ] || die "no monitor selected"
      fi

      out="$OUTDIR/rec-$(date +%Y%m%d-%H%M%S).mp4"
      printf '%s' "$out" > "$FILEREF"

      # VAAPI hardware encode on the AMD render node. Let VAAPI use its native
      # nv12 format (do NOT force -x/-t — that breaks the vaapi filter chain).
      ${pkgs.wf-recorder}/bin/wf-recorder \
        -o "$output" \
        --audio="${audioDev}" \
        -c h264_vaapi \
        -d ${amdRenderNode} \
        -p qp=22 \
        -f "$out" >/dev/null 2>&1 &
      echo $! > "$PIDFILE"

      sleep 0.5
      if ! ${pkgs.procps}/bin/kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        rm -f "$PIDFILE" "$FILEREF"
        die "recorder failed to start (VAAPI node? audio device?)"
      fi
      notify "recording started"
    '';

    rec-start-region = pkgs.writeShellScriptBin "rec-start-region" ''
      # rec-start-region: like rec-start, but drag out a rectangular zone with
      # slurp and record only that region (wf-recorder -g). Same VAAPI hardware
      # encode on the AMD node; shares the pidfile/fileref so rec-stop works as-is.
      set -euo pipefail

      OUTDIR="''${HOME}/Media/recordings"
      mkdir -p "$OUTDIR"
      PIDFILE="''${XDG_RUNTIME_DIR:-/tmp}/wf-recorder.pid"
      FILEREF="''${XDG_RUNTIME_DIR:-/tmp}/wf-recorder.file"

      notify() { ${pkgs.libnotify}/bin/notify-send "screen-record" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "rec-start-region: $1" >&2; exit 1; }

      if [ -f "$PIDFILE" ] && ${pkgs.procps}/bin/kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        die "already recording (run rec-stop)"
      fi

      # drag a region; slurp prints "X,Y WxH" which is exactly wf-recorder -g's format.
      # empty output = user pressed Escape / cancelled.
      region="$(${pkgs.slurp}/bin/slurp 2>/dev/null || true)"
      [ -n "$region" ] || die "no region selected"

      out="$OUTDIR/rec-$(date +%Y%m%d-%H%M%S).mp4"
      printf '%s' "$out" > "$FILEREF"

      # -g takes the slurp geometry; wf-recorder infers the output from it.
      ${pkgs.wf-recorder}/bin/wf-recorder \
        -g "$region" \
        --audio="${audioDev}" \
        -c h264_vaapi \
        -d ${amdRenderNode} \
        -p qp=22 \
        -f "$out" >/dev/null 2>&1 &
      echo $! > "$PIDFILE"

      sleep 0.5
      if ! ${pkgs.procps}/bin/kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        rm -f "$PIDFILE" "$FILEREF"
        die "recorder failed to start (VAAPI node? audio device? odd region size?)"
      fi
      notify "recording region started"
    '';

    rec-stop = pkgs.writeShellScriptBin "rec-stop" ''
      # rec-stop: finalize the recording (SIGINT for a clean mp4), then copy the
      # file to the clipboard as a percent-encoded uri-list.
      set -euo pipefail

      PIDFILE="''${XDG_RUNTIME_DIR:-/tmp}/wf-recorder.pid"
      FILEREF="''${XDG_RUNTIME_DIR:-/tmp}/wf-recorder.file"

      notify() { ${pkgs.libnotify}/bin/notify-send "screen-record" "$1" 2>/dev/null || true; }
      die()    { notify "$1"; echo "rec-stop: $1" >&2; exit 1; }

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

      [ -f "$PIDFILE" ] || die "not recording"
      pid="$(cat "$PIDFILE")"
      ${pkgs.procps}/bin/kill -0 "$pid" 2>/dev/null || { rm -f "$PIDFILE"; die "not recording"; }

      ${pkgs.procps}/bin/kill -INT "$pid"
      for _ in $(seq 1 50); do
        ${pkgs.procps}/bin/kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
      done
      rm -f "$PIDFILE"

      out="$(cat "$FILEREF" 2>/dev/null || true)"
      rm -f "$FILEREF"
      [ -n "$out" ] && [ -f "$out" ] || die "recording file missing"

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
      rec-start rec-start-region rec-stop
      pkgs.wf-recorder pkgs.wlr-randr pkgs.rofi pkgs.jq pkgs.slurp
      pkgs.libnotify pkgs.procps pkgs.util-linux pkgs.bash pkgs.wl-clipboard
    ];
  };
}
