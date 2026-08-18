{ self, inputs, ... }: {
  flake.nixosModules.mousekeys =
    { pkgs, lib, ... }:
    let
      mousekeys =
        pkgs.writers.writePython3Bin "mousekeys"
          {
            libraries = [ pkgs.python3Packages.evdev ];
            flakeIgnore = [
              "E501"
              "E302"
              "E305"
              "E303"
            ];
          }
          ''
            import evdev
            from evdev import ecodes as e
            import time
            import sys
            import signal

            kbd = None
            for path in evdev.list_devices():
                d = evdev.InputDevice(path)
                caps = d.capabilities().get(e.EV_KEY, [])
                if e.KEY_A in caps and e.KEY_Z in caps and e.KEY_LEFTSHIFT in caps:
                    kbd = d
                    break
            if kbd is None:
                sys.exit("no keyboard found")

            kbd_keys = kbd.capabilities().get(e.EV_KEY, [])

            ui = evdev.UInput({e.EV_REL: [e.REL_X, e.REL_Y, e.REL_WHEEL, e.REL_HWHEEL],
                               e.EV_KEY: [e.BTN_LEFT, e.BTN_RIGHT, e.BTN_MIDDLE] + kbd_keys},
                              name="mousekeys")

            held = set()
            active = False
            left_held = False
            right_held = False

            SLOW = 3
            FAST = 20

            MODS = {e.KEY_LEFTCTRL, e.KEY_RIGHTCTRL,
                    e.KEY_LEFTALT, e.KEY_RIGHTALT,
                    e.KEY_LEFTMETA, e.KEY_RIGHTMETA,
                    e.KEY_LEFTSHIFT, e.KEY_RIGHTSHIFT}

            HANDLED = {e.KEY_Q, e.KEY_ESC,
                       e.KEY_E, e.KEY_D, e.KEY_S, e.KEY_F,
                       e.KEY_I, e.KEY_K, e.KEY_J, e.KEY_L,
                       e.KEY_V, e.KEY_N, e.KEY_G, e.KEY_H,
                       e.KEY_A, e.KEY_SEMICOLON, e.KEY_SLASH}

            def mod_down():
                return bool(held & MODS)

            def forward(code, value):
                ui.write(e.EV_KEY, code, value)
                ui.syn()

            def activate(signum, frame):
                global active, held, left_held, right_held
                if active:
                    return
                # grab only once the trigger chord is released, with a timeout so a
                # phantom held key can't lock us out permanently.
                deadline = time.time() + 3
                while kbd.active_keys() and time.time() < deadline:
                    time.sleep(0.001)
                held = set()
                left_held = False
                right_held = False
                kbd.grab()
                while kbd.read_one() is not None:
                    pass
                active = True

            def deactivate():
                global active, left_held, right_held
                if not active:
                    return
                ui.write(e.EV_KEY, e.BTN_LEFT, 0)
                ui.write(e.EV_KEY, e.BTN_RIGHT, 0)
                # brute-force release every key so nothing can stick in the
                # compositor, regardless of what held tracked.
                for code in kbd_keys:
                    ui.write(e.EV_KEY, code, 0)
                ui.syn()
                held.clear()
                left_held = False
                right_held = False
                kbd.ungrab()
                active = False

            signal.signal(signal.SIGUSR1, activate)

            tick = 0
            try:
                while True:
                    if not active:
                        time.sleep(0.05)
                        continue

                    while True:
                        ev = kbd.read_one()
                        if ev is None:
                            break
                        if ev.type != e.EV_KEY:
                            continue

                        if ev.value == 1:
                            held.add(ev.code)
                        elif ev.value == 0:
                            held.discard(ev.code)

                        # modifier held, or non-mouse key: forward it untouched
                        if mod_down() or ev.code not in HANDLED:
                            forward(ev.code, ev.value)
                            continue

                        # no modifier, mouse-layer key, act on press only
                        if ev.value != 1:
                            continue

                        if ev.code in (e.KEY_Q, e.KEY_ESC):
                            deactivate()
                            break
                        if ev.code == e.KEY_V:
                            ui.write(e.EV_KEY, e.BTN_LEFT, 1)
                            ui.syn()
                            time.sleep(0.01)
                            ui.write(e.EV_KEY, e.BTN_LEFT, 0)
                            ui.syn()
                        if ev.code == e.KEY_N:
                            ui.write(e.EV_KEY, e.BTN_RIGHT, 1)
                            ui.syn()
                            time.sleep(0.01)
                            ui.write(e.EV_KEY, e.BTN_RIGHT, 0)
                            ui.syn()
                        if ev.code == e.KEY_G:
                            left_held = not left_held
                            ui.write(e.EV_KEY, e.BTN_LEFT, 1 if left_held else 0)
                            ui.syn()
                        if ev.code == e.KEY_H:
                            right_held = not right_held
                            ui.write(e.EV_KEY, e.BTN_RIGHT, 1 if right_held else 0)
                            ui.syn()

                    if not active:
                        continue

                    dx = dy = 0

                    if not mod_down():
                        if e.KEY_S in held:
                            dx -= SLOW
                        if e.KEY_F in held:
                            dx += SLOW
                        if e.KEY_E in held:
                            dy -= SLOW
                        if e.KEY_D in held:
                            dy += SLOW

                        if e.KEY_J in held:
                            dx -= FAST
                        if e.KEY_L in held:
                            dx += FAST
                        if e.KEY_I in held:
                            dy -= FAST
                        if e.KEY_K in held:
                            dy += FAST

                    if dx or dy:
                        if dx:
                            ui.write(e.EV_REL, e.REL_X, dx)
                        if dy:
                            ui.write(e.EV_REL, e.REL_Y, dy)
                        ui.syn()

                    if tick % 5 == 0 and not mod_down():
                        if e.KEY_A in held:
                            ui.write(e.EV_REL, e.REL_WHEEL, -1)
                            ui.syn()
                        if e.KEY_SEMICOLON in held:
                            ui.write(e.EV_REL, e.REL_WHEEL, 1)
                            ui.syn()
                        if e.KEY_SLASH in held:
                            ui.write(e.EV_REL, e.REL_HWHEEL, 1)
                            ui.syn()
                        if e.KEY_Z in held:
                            ui.write(e.EV_REL, e.REL_HWHEEL, -1)
                            ui.syn()

                    tick += 1
                    time.sleep(0.01)
            except KeyboardInterrupt:
                pass
            finally:
                if active:
                    kbd.ungrab()
                ui.close()
          '';
    in
    {
      environment.systemPackages = [ mousekeys ];

      users.users.sim.extraGroups = [ "input" ];

      services.udev.extraRules = ''
        KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
      '';
    };
}
