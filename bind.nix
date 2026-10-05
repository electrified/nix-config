# from https://github.com/holochain/holochain-infra/blob/fa3d1091e05ca382f8a59a5760ae4c9db1907efd/modules/flake-parts/nixosConfigurations.dweb-reverse-tl>
{ pkgs, ... }:

let
  fqdn2domain = "cluster.badgerfields.internal";
  ipv4 = "192.168.1.9";

  dnskeysConfPath = "/var/lib/secrets/${fqdn2domain}-dnskeys.conf";

  dnskeysSecretPath = "/var/lib/secrets/${fqdn2domain}-dnskeys.secret";
in
{
  #
  # Authoritative zone
  #
  environment.etc."bind/zones/${fqdn2domain}.zone" = {
    enable = true;
    user = "named";
    group = "named";
    mode = "0644";

    text = ''
      $ORIGIN .
      $TTL 60

      ${fqdn2domain} IN SOA ns1.${fqdn2domain}. admin.holochain.org. (
          2001062504 ; serial
          21600      ; refresh (6 hours)
          3600       ; retry (1 hour)
          604800     ; expire (1 week)
          86400      ; minimum (1 day)
      )

      ${fqdn2domain}.        NS      ns1.${fqdn2domain}.

      $ORIGIN ${fqdn2domain}.

      ns1                   A       ${ipv4}
      @                     A       ${ipv4}

      *                     CNAME   ${fqdn2domain}.

      cheese                A       127.0.0.1
    '';
  };

  #
  # BIND
  #
  services.bind = {
    enable = true;

    forwarders = [
      "192.168.1.1"
    ];

    #
    # The TSIG key is deliberately generated at runtime and therefore
    # does not exist inside the Nix build sandbox.
    #
    # NixOS 26.05's build-time named-checkconf consequently cannot
    # validate this include.
    #
    checkConfig = false;

    extraConfig = ''
      include "${dnskeysConfPath}";
    '';

    zones = {
      "${fqdn2domain}" = {
        master = true;

        file = "/etc/bind/zones/${fqdn2domain}.zone";

        allowQuery = [
          "any"
        ];

        extraConfig = ''
          update-policy {
            grant rfc2136key.${fqdn2domain} zonesub ANY;
          };
        '';
      };
    };
  };

  #
  # Generate the RFC2136 TSIG key.
  #
  # This is deliberately done at runtime so that the TSIG secret never
  # appears in the Nix store.
  #
  systemd.services.dns-rfc2136-2-conf = {
    description = "Generate RFC2136 TSIG key for ${fqdn2domain}";

    requiredBy = [
      "bind.service"
      "acme-${fqdn2domain}.service"
    ];

    before = [
      "bind.service"
      "acme-${fqdn2domain}.service"
    ];

    unitConfig = {
      ConditionPathExists = "!${dnskeysConfPath}";
    };

    serviceConfig = {
      Type = "oneshot";
      UMask = "0077";
    };

    path = [
      pkgs.bind
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
    ];

    script = ''
            set -eu

            mkdir -p /var/lib/secrets
            chmod 0755 /var/lib/secrets

            #
            # Generate BIND TSIG key.
            #
            tsig-keygen \
              -a hmac-sha256 \
              rfc2136key.${fqdn2domain} \
              > ${dnskeysConfPath}

            chown named:root ${dnskeysConfPath}
            chmod 0400 ${dnskeysConfPath}

            #
            # Extract the secret for clients such as ACME / RFC2136 tools.
            #
            secret="$(
              sed -n \
                's/^[[:space:]]*secret[[:space:]]*"\([^"]*\)";.*/\1/p' \
                ${dnskeysConfPath}
            )"

            if [ -z "$secret" ]; then
              echo "Failed to extract RFC2136 TSIG secret" >&2
              exit 1
            fi

            cat > ${dnskeysSecretPath} <<EOF
      RFC2136_NAMESERVER='127.0.0.1:53'
      RFC2136_TSIG_ALGORITHM='hmac-sha256.'
      RFC2136_TSIG_KEY='rfc2136key.${fqdn2domain}'
      RFC2136_TSIG_SECRET='$secret'
      EOF

            chown root:root ${dnskeysSecretPath}
            chmod 0400 ${dnskeysSecretPath}
    '';
  };
}
