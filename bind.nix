# from https://github.com/holochain/holochain-infra/blob/fa3d1091e05ca382f8a59a5760ae4c9db1907efd/modules/flake-parts/nixosConfigurations.dweb-reverse-tl>
{ pkgs, ... }:
let
  fqdn2domain = "cluster.badgerfields.internal";
  ipv4 = "192.168.1.9";
in
{
  environment.etc."bind/zones/${fqdn2domain}.zone" = {
    enable = true;
    user = "named";
    group = "named";
    mode = "0644";
    text = ''
      $ORIGIN .
      $TTL 60 ; 1 minute
      ${fqdn2domain} IN SOA ns1.${fqdn2domain}. admin.holochain.org. (
                                        2001062504 ; serial
                                        21600      ; refresh (6 hours)
                                        3600       ; retry (1 hour)
                                        604800     ; expire (1 week)
                                        86400      ; minimum (1 day)
                                      )

                              NS      ns1.${fqdn2domain}.
      $ORIGIN ${fqdn2domain}.
      ns1                                      A       ${ipv4}
      ${fqdn2domain}.                          A       ${ipv4}

      *.${fqdn2domain}.                        CNAME   ${fqdn2domain}.

      cheese.${fqdn2domain}.           A       127.0.0.1
    '';
  };

  services.bind = {
    enable = true;
    forwarders = [ "192.168.1.1" ];
    extraConfig = ''
      include "/var/lib/secrets/*-dnskeys.conf";
    '';

    zones = {
      "cluster.badgerfields.internal" = {
        allowQuery = [ "any" ];
        file = "/etc/bind/zones/${fqdn2domain}.zone";
        master = true;
        extraConfig = ''
#		allow-update { key rfc2136key.${fqdn2domain}; };
#		allow-transfer { key rfc2136key.${fqdn2domain}; };
	    update-policy {
		        grant rfc2136key.${fqdn2domain} zonesub ANY;
    		};
	'';
      };
    };
  };

  systemd.services.dns-rfc2136-2-conf =
    let
      dnskeysConfPath = "/var/lib/secrets/${fqdn2domain}-dnskeys.conf";
      dnskeysSecretPath = "/var/lib/secrets/${fqdn2domain}-dnskeys.secret";
    in
    {
      requiredBy = [
        "acme-${fqdn2domain}.service"
        "bind.service"
      ];
      before = [
        "acme-${fqdn2domain}.service"
        "bind.service"
      ];
      unitConfig = {
        ConditionPathExists = "!${dnskeysConfPath}";
      };
      serviceConfig = {
        Type = "oneshot";
        UMask = 77;
      };
      path = [ pkgs.bind ];
      script = ''
        mkdir -p /var/lib/secrets
        chmod 755 /var/lib/secrets
        tsig-keygen rfc2136key.${fqdn2domain} > ${dnskeysConfPath}
        chown named:root ${dnskeysConfPath}
        chmod 400 ${dnskeysConfPath}

        # extract secret value from the dnskeys.conf
        while read x y; do if [ "$x" = "secret" ]; then secret="''${y:1:''${#y}-3}"; fi; done < ${dnskeysConfPath}

        cat > ${dnskeysSecretPath} << EOF
        RFC2136_NAMESERVER='127.0.0.1:53'
        RFC2136_TSIG_ALGORITHM='hmac-sha256.'
        RFC2136_TSIG_KEY='rfc2136key.${fqdn2domain}'
        RFC2136_TSIG_SECRET='$secret'
        EOF
        chmod 400 ${dnskeysSecretPath}
      '';
    };

}
