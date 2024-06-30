{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Module options shortcut
  cfg = config.services.lemurs;
  # .desktop files for window manaagers/compositors
  sessionData = config.services.displayManager.sessionData.desktops.outPath;
  # TOML format
  settingsFormat = pkgs.formats.toml { };
  # Import config.toml as defaultConfig
  defaultConfig = lib.importTOML ../extra/config.toml;
  inherit (lib)
    mkDefault
    mkEnableOption
    mkOption
    types
    mkIf
    ;
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

    shell = mkOption {
      type = types.str;
      default = "${pkgs.bash}/bin/bash";
      # I wanted to set this to the default shell system-wide
      # but I wasn't sure of a great way to have that work properly
      # default = config.users.defaultUserShell;
      description = ''
        Path to system shell that gets used to execute linux commands.
        In almost all cases, this should refer to a bash shell.
      '';
    };

    settings = {
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
          default = "${sessionData}/share/xsessions";
          description = ''
            The path to X session .desktop files
          '';
        };
      };

      wayland = {
        wayland-sessions = mkOption {
          type = types.path;
          default = "${sessionData}/share/wayland-sessions";
          description = ''
            The path to wayland session .desktop files
          '';
        };
      };
    };

    extraSettings = mkOption {
      type = settingsFormat.type;
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

  config =
    let
      # Merge defaultConfig with extraSettings and module options
      # The priority for options goes
      # 1. Module options
      # 2. extraSettings
      # 3. defaultConfig
      # Lower numbers (i.e 1) will overwrite settings defined in higher numbers (i.e 3)
      lemursConfig = lib.recursiveUpdate defaultConfig (lib.recursiveUpdate
        # Nested recursiveUpdate
        (cfg.extraSettings)
        {
          # Map module options to lemurs' config.toml format
          # Also, in general, dirty hack
          tty = cfg.tty;
          system_shell = cfg.shell;
          x11 =
            # Dont add x11 config if x11 isn't enabled
            if cfg.x11.enable then {
              xauth_path = "${cfg.settings.x11.xauth}/bin/xauth";
              xserver_path = "${cfg.settings.x11.xorgserver}/bin/X";
              xsessions_path = cfg.x11.settings.xsessions;
            } else { };
          wayland =
            # Dont add wayland config if wayland isn't enabled
            if cfg.wayland.enable then {
              wayland_sessions_path = cfg.settings.wayland.wayland-sessions;
            } else { };
          # Hack
          power_controls.base_entries = [
            {
              hint = "Shutdown";
              hint_color = "dark gray";
              hint_modifiers = "";
              key = "F1";
              cmd = "${pkgs.systemd}/bin/systemctl poweroff";
            }
            {
              hint = "Reboot";
              hint_color = "dark gray";
              hint_modifiers = "";
              key = "F2";
              cmd = "${pkgs.systemd}/bin/systemctl reboot";
            }
          ];
        });

      tty = "tty${toString (cfg.tty)}";
    in
    lib.mkIf cfg.enable {

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

      environment.sessionVariables = {
        XDG_SEAT = "seat0";
        XDG_VTNR = "${toString cfg.tty}";
      };

      services.displayManager = {
        enable = mkDefault true;
      };

      environment.etc = {
        "lemurs/config.toml".source = (settingsFormat.generate "lemurs-config.toml" lemursConfig);
      };

      systemd.defaultUnit = "graphical.target";
      systemd.services = {
        "autovt@${tty}".enable = false;

        lemurs = {
          aliases = [ "display-manager.service" ];

          unitConfig = {
            Wants = [
              "systemd-user-sessions.service"
            ];

            After = [
              "systemd-user-sessions.service"
              "plymouth-quit-wait.service"
              "getty@${tty}.service"
            ];

            Conflicts = [
              "getty@${tty}.service"
            ];
          };

          serviceConfig = {
            ExecStart = ''
              ${pkgs.lemurs}/bin/lemurs \
                --xsessions  ${cfg.settings.x11.xsessions} \
                --wlsessions ${cfg.settings.wayland.wayland-sessions}
            '';
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
