slapd-tls-deps:
    pkg.installed:
        - pkgs:
            - gnutls-bin
            - ssl-cert
            - python-openssl

self-signed-cert:
    require:
        - name: slapd-tls-deps
    module.run:
        - name: tls.create_self_signed_cert
        - cacert_path: /etc/ssl
        - tls_dir: local
        - days: {{ slapd.get("slapd_cert_days", "365") }}
        - CN: {{ slapd.get("slapd_cn") }}
        - C: {{ slapd.get("slapd_cert_country", "IE") }}
        - ST: {{ slapd.get("slapd_cert_state", "Dublin") }}
        - L: {{ slapd.get("slapd_cert_location", "Dublin") }}
        - O: {{ slapd.get("slapd_cert_org", "Quux Corp") }}
        - emailAddress: {{ slapd.get("slapd_cert_email", "nops@foo.bar") }}
