{
  description = "Lemurs: A customizable TUI display/login manager written in Rust";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
    }:
    let
      pname = "lemurs";
      version = "3.2.0-nightly";

      # System types to support.
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        # "x86_64-darwin"
        # "aarch64-darwin"
      ];

      forAllSystems =
        function:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          function (
            import nixpkgs {
              inherit system;
              overlays = [
                self.overlays.default
                rust-overlay.overlays.default
                (final: prev: {
                  rustPlatform = prev.makeRustPlatform {
                    cargo = final.rust-bin.stable.latest.minimal;
                    rustc = final.rust-bin.stable.latest.minimal;
                  };
                })
              ];
            }
          )
        );
    in
    {
      overlays = {
        default = final: prev: { lemurs = self.packages.${final.system}.lemurs; };
      };

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);

      packages = forAllSystems (pkgs: rec {
        default = lemurs;
        lemurs = pkgs.callPackage ./nix/lemurs.nix {
          inherit pname version;
        };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            bash
            nixpkgs-fmt
            pam
            rust-bin.stable.latest.default
          ];
        };
      });

      nixosModules = rec {
        default = lemurs;
        lemurs = (import ./nix/lemurs-module.nix);
      };
    };
}
