{ config, pkgs, lib, ... }:
let
  # Module options shortcut
  cfg = config.services.lemurs;

  # Inherit
  inherit (lib)
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  # .desktop files for window manaagers/compositors
  sessionData = config.services.displayManager.sessionData;

  # TOML format
  tomlFmt = pkgs.formats.toml { };

  # Import config.toml as defaultConfig
  defaultConfig = lib.importTOML "${pkgs.lemurs.src}/extra/config.toml";

  # TTY Option
  tty = "tty${toString (cfg.tty)}";

  # Merge defaultConfig with extraSettings and module options
  # The priority for options goes
  # 1. Module options
  # 2. extraSettings
  # 3. defaultConfig
  # Lower numbers (i.e 1) will overwrite settings defined in higher numbers (i.e 3)
  lemursConfig = lib.recursiveUpdate defaultConfig (lib.recursiveUpdate cfg.extraSettings {
    # Map module options to lemurs' config.toml format
    # Also, in general, dirty hack

    inherit (cfg) tty;

    # Set correct shell (not an option)
    system_shell = lib.getExe pkgs.bash;
    environment_switcher.include_tty_shell = cfg.settings.ttyLogin;

    # Dont add x11 config if x11 isn't enabled
    x11 = lib.optionalAttrs cfg.x11.enable {
      xauth_path = "${cfg.settings.x11.xauth}/bin/xauth";
      xserver_path = "${cfg.settings.x11.xorgserver}/bin/X";
      xsessions_path = cfg.settings.x11.xsessions;
    };

    # Dont add wayland config if wayland isn't enabled
    wayland = lib.optionalAttrs cfg.wayland.enable {
      wayland_sessions_path = cfg.settings.wayland.wayland-sessions;
    };

  });
in
{
  options.services.lemurs = {
    enable = mkEnableOption "the Lemurs Display Manager";

    x11.enable = mkEnableOption "the X11 part of the Lemurs Display Manager";
    wayland.enable = mkEnableOption "the Wayland part of the Lemurs Display Manager";

    tty = mkOption {
      type = types.int;
      default = 2;
      description = ''
        The tty which contains lemurs.
      '';
    };

    settings = {
      ttyLogin = mkOption {
        type = types.bool;
        default = (defaultConfig.environment_switcher.include_tty_shell);
        description = ''
          Show an option for the TTY shell when logging in as one of the environments.
          NOTE: it is always shown when no viable options are found.
        '';
      };

      x11 = {
        xauth = mkOption {
          type = with types; nullOr package;
          default = if cfg.x11.enable then pkgs.xorg.xauth else null;
          description = ''
            The package used for xauth
          '';
        };

        xorgserver = mkOption {
          type = with types; nullOr package;
          default = if cfg.x11.enable then pkgs.xorg.xorgserver else null;
          description = ''
            The package used for xorgserver
          '';
        };

        xsessions = mkOption {
          type = types.path;
          default = "${sessionData.desktops.outPath}/share/xsessions";
          description = ''
            The path to X session .desktop files
          '';
        };
      };

      wayland = {
        wayland-sessions = mkOption {
          type = types.path;
          default = "${sessionData.desktops.outPath}/share/wayland-sessions";
          description = ''
            The path to wayland session .desktop files
          '';
        };
      };
    };

    extraSettings = mkOption {
      type = tomlFmt.type;
      example = lib.literalExpression /*nix*/ ''
        {
          do_log = true;
          cache_path = "/var/cache/lemurs";
          background = {
            show_background = true;
          };
        }
      '';
      default = { };
      description = ''
        Extra configuration to be applied to config.toml as a nix attribute set
        [lemurs/extra/config.toml](https://github.com/coastalwhite/lemurs/blob/main/extra/config.toml)
      '';
    };
  };

  config = mkIf cfg.enable {
    services.displayManager.enable = mkDefault true;

    # PAM setup
    security.pam.services = {
      lemurs.text = ''
        auth include login
        account include login
        session include login
        password include login
      '';

      # See https://github.com/coastalwhite/lemurs/issues/166
      login = {
        setLoginUid = false;
        enableGnomeKeyring = config.services.gnome.gnome-keyring.enable;
      };
    };

    environment = {
      sessionVariables = {
        XDG_SEAT = "seat0";
        XDG_VTNR = "${toString cfg.tty}";
      };

      etc = {
        "lemurs/config.toml".source = (tomlFmt.generate "lemurs-config.toml" lemursConfig);
      };
    };

    systemd.defaultUnit = "graphical.target";
    systemd.services = {
      "autovt@${tty}".enable = false;

      lemurs = {
        aliases = [ "display-manager.service" ];

        unitConfig = {
          Wants = [ "systemd-user-sessions.service" ];

          After = [
            "systemd-user-sessions.service"
            "plymouth-quit-wait.service"
            "getty@${tty}.service"
          ];

          Conflicts = [ "getty@${tty}.service" ];
        };

        serviceConfig = {
          ExecStart =
            let
              args = lib.cli.toGNUCommandLineShell { } {
                xsessions = cfg.settings.x11.xsessions;
                wlsessions = cfg.settings.wayland.wayland-sessions;
              };
            in
            "${pkgs.lemurs}/bin/lemurs ${args}";

          StandardInput = "tty";
          TTYPath = "/dev/${tty}";
          TTYReset = "yes";
          TTYVHangup = "yes";
          Type = "idle";
        };

        restartIfChanged = false;
        wantedBy = [ "graphical.target" ];
      };
    };

  };
}
