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
          version = "0.4.0-nightly";
          rust-toolchain = pkgs.rust-bin.stable.latest.default;

          rustPlatform = pkgs.makeRustPlatform {
            cargo = rust-toolchain;
            rustc = rust-toolchain;
          };
        in
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          };

          formatter = pkgs.nixfmt-rfc-style;

          overlayAttrs = config.packages;

          packages.default = rustPlatform.buildRustPackage {
            inherit pname version;
            src = ./.;

            postPatch = ''
              substituteInPlace extra/config.toml \
                --replace-fail "/usr/sh" "${pkgs.bash}/bin/bash"

              substituteInPlace extra/config.toml \
                --replace-fail "/usr/bin/X" "${pkgs.xorg.xorgserver}/bin/X"

              substituteInPlace extra/config.toml \
                --replace-fail "/usr/bin/xauth" "${pkgs.xorg.xauth}/bin/xauth"
            '';

            buildInputs = [
              pkgs.linux-pam
            ];

            cargoLock.lockFile = ./Cargo.lock;
          };

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              linux-pam
              rust-toolchain
              cargo-dist
            ];
          };
        };
    };
}
