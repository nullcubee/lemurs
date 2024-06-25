{
  config,
  pkgs,
  lib,
  ...
}:
let
  sessionData = config.services.displayManager.sessionData.desktops.outPath;
in
{
  options.services.lemurs = rec {
    enable = lib.mkEnableOption "Enable the Lemurs Display Manager";

    x11.enable = lib.mkEnableOption "Enable the X11 part of the Lemurs Display Manager";
    wayland.enable = lib.mkEnableOption "Enable the Wayland part of the Lemurs Display Manager";

    tty = lib.mkOption {
      type = lib.types.str;
      default = "tty2";
    };

    settings = {
      x11 = {
        xauth = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = if x11.enable then pkgs.xorg.xauth else null;
        };

        xorgserver = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = if x11.enable then pkgs.xorg.xorgserver else null;
        };

        xsessions = lib.mkOption {
          type = lib.types.path;
          default = "${sessionData}/share/xsessions";
        };
      };

      wayland = {
        wayland-sessions = lib.mkOption {
          type = lib.types.path;
          default = "${sessionData}/share/wayland-sessions";
        };
      };
    };
  };

  config =
    let
      cfg = config.services.lemurs;
    in
    lib.mkIf cfg.enable {
      security.pam.services.lemurs = {
        allowNullPassword = true;
        startSession = true;
        setLoginUid = false;
        enableGnomeKeyring = lib.mkDefault config.services.gnome.gnome-keyring.enable;
      };

      systemd.services."autovt@${cfg.tty}".enable = false;

      systemd.services.lemurs = {
        aliases = [ "display-manager.service" ];

        unitConfig = {
          Wants = [
            "systemd-user-sessions.service"
          ];

          After = [
            "systemd-user-sessions.service"
            "plymouth-quit-wait.service"
            "getty@${cfg.tty}.service"
          ];

          Conflicts = [
            "getty@${cfg.tty}.service"
          ];
        };

        serviceConfig = {
          ExecStart = ''
            ${pkgs.lemurs}/bin/lemurs \
              --xsessions  ${cfg.settings.x11.xsessions} \
              --wlsessions ${cfg.settings.wayland.wayland-sessions}
          '';

          StandardInput = "tty";
          TTYPath = "/dev/${cfg.tty}";
          TTYReset = "yes";
          TTYVHangup = "yes";

          Type = "idle";
        };

        restartIfChanged = false;

        wantedBy = [ "graphical.target" ];
      };

      systemd.defaultUnit = "graphical.target";

    };
}
