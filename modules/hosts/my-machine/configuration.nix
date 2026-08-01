{ self, inputs, ...}: {
	flake.nixosModules.myMachineConfiguration = { config, lib, pkgs, ... }: {
	  imports =
	    [
	    	self.nixosModules.myMachineHardware
		self.nixosModules.mango
		self.nixosModules.kitty
		self.nixosModules.vesktop
		self.nixosModules.zen
		self.nixosModules.swaybg
		self.nixosModules.btop
		self.nixosModules.mousekeys
		self.nixosModules.xkb-swap
		self.nixosModules.screenshare
		self.nixosModules.obs
		self.nixosModules.flatpak
		self.nixosModules.audio
		self.nixosModules.screenshot
		self.nixosModules.mullvad
		self.nixosModules.yazi
		self.nixosModules.mpv
		self.nixosModules.zsh
		self.nixosModules.clipboard
		self.nixosModules.clip-to-gif
		self.nixosModules.clip-split
		self.nixosModules.clip-reveal
		self.nixosModules.media-grid
		self.nixosModules.dl-media
		self.nixosModules.mako
		self.nixosModules.to-mp4
		self.nixosModules.upload-video
		self.nixosModules.mullvad-browser
		self.nixosModules.concord
		self.nixosModules.screen-record
		self.nixosModules.nvtop
		self.nixosModules.caption-gif

	    ];

	  boot.loader.systemd-boot.enable = true;
	  boot.loader.efi.canTouchEfiVariables = true;

	  boot.kernelPackages = pkgs.linuxPackages_latest;

	  networking.hostName = "sim";

	  networking.networkmanager.enable = true;

	  time.timeZone = "America/Cayenne";

	  i18n.defaultLocale = "en_US.UTF-8";
	  console = {
	    font = "Lat2-Terminus16";
	    keyMap = "dvorak-programmer";
	  };

	  services.pipewire = {
	    enable = true;
	    pulse.enable = true;
	  };

	  services.libinput.enable = true;

	  # Electron apps (Vesktop included) only take the native-Wayland path
	  # (and with it, continuous PipeWire screencast capture) when this is
	  # set. Without it they fall back to XWayland, whose screen-share/
	  # window-share picker grabs a single static frame instead of a live
	  # stream - the "stream freezes on one image" symptom.
	  environment.sessionVariables.NIXOS_OZONE_WL = "1";

	  # amdgpu fails to negotiate DMA-BUF format modifiers with mango's
	  # ext-image-copy-capture screencast path: pipewire logs "out of
	  # buffers" / "unable to export buffer" and the stream never sends
	  # a second frame. Forcing linear (unmodified) buffers avoids the
	  # negotiation entirely. Known wlroots/amdgpu workaround.
	  environment.sessionVariables.WLR_DRM_NO_MODIFIERS = "1";

	  users.users.sim = {
	    isNormalUser = true;
	    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
	    packages = with pkgs; [
	      tree
	    ];
	  };

	  environment.systemPackages = with pkgs; [
	    wget
	    neovim
	    git
	    curl
	    wl-clipboard # clipboard
	    wlr-randr # idk
	    wireplumber # for audio
	    brightnessctl # for brightness
	    claude-code # for coding
	    grim  # for screenshot
	    slurp
	    obsidian
	    unzip
	  ];

	  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
	  system.stateVersion = "26.05"; # Did you read the comment?
	  hardware.graphics.enable = true;

	  # Hybrid AMD (iGPU) + Nvidia RTX 3050 (dGPU) laptop.
	  # AMD drives the internal display by default; Nvidia is offloaded
	  # on demand via `nvidia-offload <command>`.
	  services.xserver.videoDrivers = [ "nvidia" ];
	  hardware.nvidia = {
	    modesetting.enable = true;
	    open = true; # Ampere (RTX 30xx) is supported by the open kernel modules
	    nvidiaSettings = true;
	    package = config.boot.kernelPackages.nvidiaPackages.stable;

	    prime = {
	      offload = {
	        enable = true;
	        enableOffloadCmd = true;
	      };
	      amdgpuBusId = "PCI:5:0:0";
	      nvidiaBusId = "PCI:1:0:0";
	    };
	  };

	  fonts.packages = with pkgs; [
		nerd-fonts.jetbrains-mono
	  ];

	  nix.settings.experimental-features = [ "nix-command" "flakes" ];
	  security.sudo.wheelNeedsPassword = false;
	  nixpkgs.config.allowUnfree = true;

	  hardware.bluetooth = {
	    enable = true;
	    powerOnBoot = true;
	  };

	  environment.sessionVariables.EDITOR = "nvim";


	};
}

