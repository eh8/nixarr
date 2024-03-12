# TODO: Dir creation and file permissions in nix
{
  config,
  lib,
  ...
}:
with lib; let
  defaultPort = 9696;
  nixarr = config.nixarr;
  cfg = config.nixarr.prowlarr;
in {
  imports = [
    ./prowlarr-module
  ];

  options.nixarr.prowlarr = {
    enable = mkEnableOption "the Prowlarr service.";

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/prowlarr";
      defaultText = literalExpression ''"''${nixarr.stateDir}/prowlarr"'';
      example = "/home/user/.local/share/nixarr/prowlarr";
      description = "The state directory for Prowlarr.";
    };

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''"''${nixarr.vpn.enable}"'';
      default = !cfg.vpn.enable;
      example = true;
      description = "Open firewall for Prowlarr";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

        Route Prowlarr traffic through the VPN.
      '';
    };
  };

  config = mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.vpn.enable -> nixarr.vpn.enable;
          message = ''
            The nixarr.prowlarr.vpn.enable option requires the
            nixarr.vpn.enable option to be set, but it was not.
          '';
        }
      ];

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0700 prowlarr root - -"
    ];

    util-nixarr.services.prowlarr = {
      enable = true;
      openFirewall = cfg.openFirewall;
      dataDir = cfg.stateDir;
    };

    # Enable and specify VPN namespace to confine service in.
    systemd.services.prowlarr.vpnconfinement = mkIf cfg.vpn.enable {
      enable = true;
      vpnnamespace = "wg";
    };

    # Port mappings
    vpnnamespaces.wg = mkIf cfg.vpn.enable {
      portMappings = [{ from = defaultPort; to = defaultPort; }];
    };

    services.nginx = mkIf cfg.vpn.enable {
      enable = true;

      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      virtualHosts."127.0.0.1:${builtins.toString defaultPort}" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = defaultPort;
          }
        ];
        locations."/" = {
          recommendedProxySettings = true;
          proxyWebsockets = true;
          proxyPass = "http://192.168.15.1:${builtins.toString defaultPort}";
        };
      };
    };
  };
}
