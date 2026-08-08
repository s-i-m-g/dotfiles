{ self, inputs, ... }: {
  flake.nixosModules.mango = { pkgs, lib, ... }: {
    imports = [
      inputs.mangowm.nixosModules.mango
      inputs.home-manager.nixosModules.home-manager
    ];

    programs.mango.enable = true;

    environment.systemPackages = with pkgs; [
      rofi
    ];

    home-manager.users.sim = {
      imports = [ inputs.mangowm.hmModules.mango ];

      home.stateVersion = "26.05";

      wayland.windowManager.mango = {
        enable = true;

        autostart_sh = ''
          ${lib.getExe pkgs.swaybg} -i ${./wallpaperj1.jpg} -m fill &
	  mousekeys &
        '';

        extraConfig = ''
          # Window effect
          blur=1
          blur_layer=1
          blur_optimized=1
          blur_params_num_passes = 2
          blur_params_radius = 5
          blur_params_noise = 0.02
          blur_params_brightness = 0.9
          blur_params_contrast = 0.9
          blur_params_saturation = 1.2

          shadows = 0
          layer_shadows = 0
          shadow_only_floating = 1
          shadows_size = 10
          shadows_blur = 15
          shadows_position_x = 0
          shadows_position_y = 0
          shadowscolor= 0x000000ff

          border_radius=0
          no_radius_when_single=1
          focused_opacity=1.0
          unfocused_opacity=1.0

          # Animation Configuration(support type:zoom,slide)
          # tag_animation_direction: 1-horizontal,0-vertical
          animations=1
          layer_animations=1
          animation_type_open=slide
          animation_type_close=slide
          animation_fade_in=1
          animation_fade_out=1
          tag_animation_direction=1
          zoom_initial_ratio=0.4
          zoom_end_ratio=0.8
          fadein_begin_opacity=0.5
          fadeout_begin_opacity=0.8
          animation_duration_move=500
          animation_duration_open=400
          animation_duration_tag=350
          animation_duration_close=800
          animation_duration_focus=0
          animation_curve_open=0.46,1.0,0.29,1
          animation_curve_move=0.46,1.0,0.29,1
          animation_curve_tag=0.46,1.0,0.29,1
          animation_curve_close=0.08,0.92,0,1
          animation_curve_focus=0.46,1.0,0.29,1
          animation_curve_opafadeout=0.5,0.5,0.5,0.5
          animation_curve_opafadein=0.46,1.0,0.29,1

          # Scroller Layout Setting
          scroller_structs=0
          scroller_default_proportion=1.0
          scroller_focus_center=0
          scroller_prefer_center=0
          edge_scroller_pointer_focus=1
          edge_scroller_focus_allow_speed=0.0
          scroller_default_proportion_single=1.0
          scroller_proportion_preset=1.0,0.5

          # Overview Setting
          hotarea_size=10
          enable_hotarea=0
          ov_tab_mode=1
          ov_no_resize=1
          overviewgappi=5
          overviewgappo=30

          # Misc
          no_border_when_single=0
          axis_bind_apply_timeout=100
          focus_on_activate=1
          idleinhibit_ignore_visible=0
          sloppyfocus=1
          warpcursor=1
          focus_cross_monitor=0
          focus_cross_tag=0
          enable_floating_snap=0
          snap_distance=30
          cursor_size=24
          drag_tile_to_tile=1
          drag_tile_small=1

          # keyboard
          repeat_rate=25
          repeat_delay=600
          numlockon=0
          xkb_rules_layout=dvp-swap,us
          xkb_rules_variant=,
          xkb_rules_options=caps:escape
          bind=ALT+SHIFT,q,switch_keyboard_layout

          # Trackpad
          # need relogin to make it apply
          disable_trackpad=0
          tap_to_click=1
          tap_and_drag=1
          drag_lock=1
          trackpad_natural_scrolling=0
          disable_while_typing=1
          left_handed=0
          middle_button_emulation=0
          swipe_min_threshold=1

          # mouse
          # need relogin to make it apply
          mouse_natural_scrolling=0

          # Appearance
          gappih=0
          gappiv=0
          gappoh=0
          gappov=0
          scratchpad_width_ratio=0.8
          scratchpad_height_ratio=0.9
          borderpx=0
          rootcolor=0x201b14ff
          bordercolor=0x444444ff
          dropcolor=0x8FBA7C55
          splitcolor=0xEB441EFF
          focuscolor=0xc9b890ff
          maximizescreencolor=0x89aa61ff
          urgentcolor=0xad401fff
          scratchpadcolor=0x516c93ff
          globalcolor=0xb153a7ff
          overlaycolor=0x14a57cff

          # layout support:
          # tile,scroller,grid,deck,monocle,center_tile,vertical_tile,vertical_scroller
          tagrule=id:1,layout_name:scroller
          tagrule=id:2,layout_name:scroller
          tagrule=id:3,layout_name:scroller
          tagrule=id:4,layout_name:scroller
          tagrule=id:5,layout_name:scroller
          tagrule=id:6,layout_name:scroller
          tagrule=id:7,layout_name:scroller
          tagrule=id:8,layout_name:scroller
          tagrule=id:9,layout_name:scroller

          # Key Bindings
          # key name refer to `xev` or `wev` command output,
          # mod keys name: super,ctrl,alt,shift,none

          # reload config
          bind=SUPER+SHIFT,o,reload_config

          # menu and terminal
          bind=Alt,space,spawn,${lib.getExe pkgs.rofi} -show drun
          bind=Alt,return,spawn,${lib.getExe pkgs.kitty}

          # switch window focus
          bind=ALT,j,focusdir,left
          bind=ALT,p,focusdir,right
          bind=ALT,v,focusdir,up
          bind=ALT,c,focusdir,down

          # swap window
          bind=ALT+SHIFT,c,exchange_client,up
          bind=ALT+SHIFT,v,exchange_client,down
          bind=ALT+SHIFT,j,exchange_client,left
          bind=ALT+SHIFT,p,exchange_client,right

          # switch window status
          bind=ALT,comma,killclient,

          bind=SUPER,TAB,toggleoverview,
          bind=ALT,TAB,focuslast

          bind=ALT,y,togglefloating,
          bind=ALT,l,togglemaximizescreen

          bind=ALT,m,minimized,
          bind=ALT+SHIFT,M,restore_minimized
          bind=ALT,z,toggle_scratchpad

          bind=ALT,k,toggleoverlay,
          bind=ALT+SHIFT,k,toggleglobal,

          # scroller layout
          bind=ALT,x,switch_proportion_preset,
          bind=super,j,scroller_stack,left
          bind=super,p,scroller_stack,right
          bind=super,v,scroller_stack,up
          bind=super,c,scroller_stack,down

          # tag switch
          bind=ALT,1,view,1,0
          bind=ALT,2,view,2,0
          bind=ALT,3,view,3,0
          bind=ALT,4,view,4,0
          bind=ALT,5,view,5,0
          bind=ALT,6,view,6,0
          bind=ALT,7,view,7,0
          bind=ALT,8,view,8,0
          bind=ALT,9,view,9,0

          # tag: move client to the tag and focus it
          # tagsilent: move client to the tag and not focus it
          # bind=Alt,1,tagsilent,1
          bind=ALT+SHIFT,1,tagsilent,1,0
          bind=ALT+SHIFT,2,tagsilent,2,0
          bind=ALT+SHIFT,3,tagsilent,3,0
          bind=ALT+SHIFT,4,tagsilent,4,0
          bind=ALT+SHIFT,5,tagsilent,5,0
          bind=ALT+SHIFT,6,tagsilent,6,0
          bind=ALT+SHIFT,7,tagsilent,7,0
          bind=ALT+SHIFT,8,tagsilent,8,0
          bind=ALT+SHIFT,9,tagsilent,9,0

          # movewin
          bind=SUPER+SHIFT,v,movewin,+0,-50
          bind=SUPER+SHIFT,c,movewin,+0,+50
          bind=SUPER+SHIFT,j,movewin,-50,+0
          bind=SUPER+SHIFT,p,movewin,+50,+0

          # resizewin
          bind=SUPER+ALT,v,resizewin,+0,-50
          bind=SUPER+ALT,c,resizewin,+0,+50
          bind=SUPER+ALT,j,resizewin,-50,+0
          bind=SUPER+ALT,p,resizewin,+50,+0

          # layer rule
          layerrule=animation_type_open:zoom,layer_name:rofi
          layerrule=animation_type_close:zoom,layer_name:rofi

          # Monitor rule
          monitorrule=name:^eDP-1$,width:1920,height:1080,refresh:120,x:0,y:10,scale:1.25

          # volume
          bind=NONE,XF86AudioRaiseVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+
          bind=NONE,XF86AudioLowerVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-
          bind=NONE,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
          bind=NONE,XF86AudioMicMute,spawn,wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

          # brightness
          bind=NONE,XF86MonBrightnessUp,spawn,brightnessctl set +5%
          bind=NONE,XF86MonBrightnessDown,spawn,brightnessctl set 5%-

          # toggle-mousekeys
          bind=ALT,semicolon,spawn,pkill -f -USR1 mousekeys
 
          # screen-region
          bind=NONE,Print,spawn,shot-region
 
          # clipboard-history
          bind=SUPER,i,spawn,kitty --class clippicker -e clip-picker
          windowrule=isfloating:1,appid:clippicker
  
          # media-picker
          bind=SUPER,m,spawn,media-grid-float
          windowrule=isfloating:1,width:1400,height:900,appid:mediagrid
   
          # clip-reveal 
          bind=SUPER,o,spawn,clip-reveal
   
          # caption
          windowrule=isfloating:1,width:600,height:180,appid:captionbox
     
          # wlr-which-key
          bind=ALT,ALT_R,spawn,wlr-which-key
    
          # plode
          windowrule=isfloating:1,width:300,height:90,appid:plodevalue
    '';
      };
    };

    services.greetd = {
      enable = true;
      settings = {
        initial_session = {
          command = "mango";
          user = "sim";
        };
        default_session = {
          command = "${lib.getExe pkgs.tuigreet} --cmd mango";
          user = "greeter";
        };
      };
    };
  };
}
