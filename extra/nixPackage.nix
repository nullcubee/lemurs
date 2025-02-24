{
  version,
  lib,
  bash,
  linux-pam,
  rustPlatform,
  systemdMinimal,
}:
rustPlatform.buildRustPackage {
  pname = "lemurs";
  inherit version;

  src = ../.;

  useFetchCargoVendor = true;
  cargoHash = "sha256-XoGtIHYCGXNuwnpDTU7NbZAs6rCO+69CAG89VCv9aAc=";

  buildInputs = [
    bash
    linux-pam
    systemdMinimal
  ];

  meta = {
    description = "Customizable TUI display/login manager written in Rust";
    homepage = "https://github.com/coastalwhite/lemurs";
    license = with lib.licenses; [
      asl20
      mit
    ];
    maintainers = with lib.maintainers; [
      jeremiahs
      nullcube
    ];
    mainProgram = "lemurs";
  };
}
