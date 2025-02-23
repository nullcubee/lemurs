{
  description = "Lemurs: A customizable TUI display/login manager written in Rust";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      rust-overlay,
      flake-parts,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ flake-parts.flakeModules.easyOverlay ];

      # System types to support.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        # "x86_64-darwin"
        # "aarch64-darwin"
      ];

      perSystem =
        {
          config,
          system,
          pkgs,
          ...
        }:
        let
          pname = "lemurs";
          version = "3.2.0-nightly";
          rustBin = pkgs.rust-bin.stable.latest.default;
        in
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          };

          formatter = pkgs.nixfmt-rfc-style;

          overlayAttrs = {
            inherit (config.packages) lemurs;
          };

          packages = {
            default = config.packages.lemurs;
            lemurs = pkgs.callPackage ./nix/package.nix {
              inherit pname version;
              rustPlatform = pkgs.makeRustPlatform {
                cargo = rustBin;
                rustc = rustBin;
              };
            };
          };

          devShells = {
            default = pkgs.mkShell {
              packages = with pkgs; [
                config.formatter
                bash
                pam
                rustBin
              ];
            };
          };
        };

      flake = {
        nixosModules = rec {
          default = lemurs;
          lemurs = ./nix/nixosModule.nix;
        };
      };
    };
}
