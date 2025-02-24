{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.lemurs;

  inherit (lib)
    getExe
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    types
    mkPackageOption
    ;

  # desktop files for window managers/compositors
  dmConf = config.services.displayManager;
  sessionData = dmConf.sessionData.desktops;

  tomlFmt = pkgs.formats.toml { };

  # Import config.toml to get the default config
  defaultConfig = lib.importTOML "${cfg.package.src}/extra/config.toml";

  tty = "tty${toString (cfg.tty)}";

  # Merge defaultConfig with extraSettings and module options
  # The priority for options goes
  # 1. Module options
  # 2. extraSettings
  # 3. defaultConfig
  # Lower numbers (i.e 1) will overwrite settings defined in higher numbers (i.e 3)
  lemursConfig = lib.recursiveUpdate defaultConfig (
    lib.recursiveUpdate cfg.extraSettings {
      # Map module options to lemurs' config.toml format
      # Also, in general, dirty hack

      inherit (cfg) tty;
      system_shell = lib.getExe pkgs.bash;
      initial_path = "/run/current-system/sw/bin";
      environment_switcher.include_tty_shell = cfg.settings.ttyLogin;

      x11 = {
        xauth_path = "${cfg.settings.x11.xauth}/bin/xauth";
        xserver_path = "${cfg.settings.x11.xorgserver}/bin/X";
        xsessions_path = cfg.settings.x11.xsessions;
      };

      wayland = {
        wayland_sessions_path = cfg.settings.wayland.wayland-sessions;
      };
    }
  );
in
{
  options.services.lemurs = {
    enable = mkEnableOption "Lemurs Display Manager";
    package = mkPackageOption pkgs "lemurs" { };

    x11.enable = mkEnableOption "managing X11 sessions";
    wayland.enable = mkEnableOption "managing Wayland sessions";

    tty = mkOption {
      type = types.int;
      default = 2;
      description = ''
        The tty which contains lemurs
      '';
    };

    settings = {
      ttyLogin = mkOption {
        type = types.bool;
        default = defaultConfig.environment_switcher.include_tty_shell;
        description = ''
          Show an option for the TTY shell when logging in as one of the environments.
          NOTE: it is always shown when no viable options are found.
        '';
      };

      x11 = {
        xauth = mkOption {
          type = with types; nullOr package;
          default = pkgs.xorg.xauth;
          description = ''
            The package used for xauth
          '';
        };

        xorgserver = mkOption {
          type = with types; nullOr package;
          default = pkgs.xorg.xorgserver;
          description = ''
            The package used for xorgserver
          '';
        };

        xsessions = mkOption {
          type = types.path;
          default = "${sessionData.outPath}/share/xsessions";
          description = ''
            The path to X session .desktop files
          '';
        };
      };

      wayland = {
        wayland-sessions = mkOption {
          type = types.path;
          default = "${sessionData.outPath}/share/wayland-sessions";
          description = ''
            The path to wayland session .desktop files
          '';
        };
      };
    };

    extraSettings = mkOption {
      type = tomlFmt.type;
      example =
        lib.literalExpression # nix
          ''
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
    assertions = [
      {
        assertion = !dmConf.autoLogin.enable;
        message = ''
          lemurs doesn't support auto login.
        '';
      }
    ];

    services.displayManager = {
      enable = mkDefault true;
      execCmd =
        let
          args = lib.cli.toGNUCommandLineShell { } {
            xsessions = if cfg.x11.enable then cfg.settings.x11.xsessions else null;
            wlsessions = if cfg.wayland.enable then cfg.settings.wayland.wayland-sessions else null;
          };
        in
        "${getExe cfg.package} ${args}";
    };

    services.dbus.packages = [ cfg.package ];
    services.xserver = {
      tty = null;
      display = null;
      displayManager.lightdm.enable = false;
    };

    # PAM setup
    security.pam.services = {
      lemurs = {
        startSession = true;
        unixAuth = true;
        enableGnomeKeyring = lib.mkDefault config.services.gnome.gnome-keyring.enable;
      };

      # lemurs.text = ''
      #   auth include login
      #   account include login
      #   session include login
      #   password include login
      # '';

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

      etc."lemurs/config.toml".source = (tomlFmt.generate "lemurs-config.toml" lemursConfig);

      systemPackages = [ cfg.package ];
    };

    systemd.defaultUnit = "graphical.target";
    systemd.services = {
      "autovt@${tty}".enable = false;

      display-manager = {
        aliases = [ "lemurs.service" ];

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

  meta.maintainers = with lib.maintainers; [ nullcube ];
}
