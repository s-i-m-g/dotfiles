{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";


    mangowm = {
    	url = "github:mangowm/mango";
	inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
    	url = "github:nix-community/home-manager";
	inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
    	url = "github:youwen5/zen-browser-flake";
	inputs.nixpkgs.follows = "nixpkgs";
    };

    nvf = {
        url = "github:notashelf/nvf";
        inputs.nixpkgs.follows = "nixpkgs";
    };


    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";

    concord.url = "github:chojs23/concord";

    blender-cuda.url = "github:adithyagenie/blender-cuda-nixos";

    nixcord.url = "github:FlameFlag/nixcord";

  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules);
}
