{ self, inputs, ... }: {
	flake.nixosModules.myMachineHardware = { config, lib, pkgs, modulesPath, ... }:
		{
		  imports =
		    [ (modulesPath + "/installer/scan/not-detected.nix")
		    ];

		  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usb_storage" "usbhid" "sd_mod" ];
		  boot.initrd.kernelModules = [ ];
		  boot.kernelModules = [ "kvm-amd" ];
		  boot.extraModulePackages = [ ];

		  fileSystems."/" =
		    { device = "/dev/disk/by-uuid/9b4a2a39-61e5-4631-8e12-1062d0bcb8cf";
		      fsType = "ext4";
		    };

		  fileSystems."/boot" =
		    { device = "/dev/disk/by-uuid/A430-BC06";
		      fsType = "vfat";
		      options = [ "fmask=0077" "dmask=0077" ];
		    };

		  swapDevices =
		    [ { device = "/dev/disk/by-uuid/e6e49c99-9cdf-436d-bc5c-57ea97f51415"; }
		    ];

		  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
		  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
		};
}
