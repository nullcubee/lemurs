{
  lib,
  bash,
  pam,
  pname,
  rustPlatform,
  systemdMinimal,
  version,
}:
rustPlatform.buildRustPackage {
  inherit pname version;

  src = ../.;

  buildInputs = [
    bash
    pam
    systemdMinimal
  ];

  patches = [
    # For testing:
    # https://github.com/coastalwhite/lemurs/pull/211
    ./append-logs.patch
  ];

  cargoHash = "sha256-GqIgpDMgXVNtM7SX58ycdOimOqVUbpRqSwprwkfk0d4=";

  meta = with lib; {
    description = "A customizable TUI display/login manager written in Rust";
    homepage = "https://github.com/coastalwhite/lemurs";
    license = with licenses; [
      asl20
      mit
    ];
  };
}
