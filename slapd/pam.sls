## see https://help.ubuntu.com/lts/serverguide/openldap-server.html#openldap-server-installation
## primarily this setup is for ubuntu and debian
## see also https://help.ubuntu.com/lts/serverguide/openldap-server.html#openldap-server-installation

{% from "slapd/package-map.jinja" import slapd with context %}

pam-packages:
    pkg.installed:
        - pkgs: {{ slapd.pam_pkgs|json }}

{% if grains['os'] == 'Ubuntu' %}
ldap-auth-debconf:
    debconf.set:
        - name: ldap-auth-config
        - data:
            'ldap-auth-config/bindpw': {'type': 'password', 'value': '{{ slapd.get("password", "password") }}' }
            'ldap-auth-config/rootbindpw': {'type': 'password', 'value': '{{ slapd.get("password", "password") }}' }
            'ldap-auth-config/dbrootlogin': { 'type': 'boolean', 'value': 'true' }
            'ldap-auth-config/rootbinddn': {'type': 'string', 'value': '{{ slapd.get("rootbinddn", "cn=admin,dc=foo,dc=bar") }}' }
            'ldap-auth-config/pam_password': {'type': 'string', 'value': 'crypt' }
            'ldap-auth-config/move-to-debconf': { 'type': 'boolean', 'value': 'true' }
            'ldap-auth-config/ldapns/ldap-server': {'type': 'string', 'value': '{{ slapd.get("host", "localhost") }}' }
            'ldap-auth-config/ldapns/base-dn': {'type': 'string', 'value': '{{ slapd.get("dc", "dc=foo,dc=bar") }}' }
            'ldap-auth-config/override': {'type': 'password', 'value': '{{ slapd.get("password", "password") }}' }
            'ldap-auth-config/ldapns/ldap_version': {'type': 'string', 'value': '3' }
            'ldap-auth-config/dblogin': { 'type': 'boolean', 'value': 'false' }
        - require_in:
          - name: pam-packages

auth-client-config -t nss -p lac_ldap:
    cmd.run:
        - user: root
        - group: root

DEBIAN_FRONTEND=noninteractive pam-auth-update:
    cmd.run:
        - user: root
        - group: root

/etc/pam.d/common-password:
    file.managed:
        - source: salt://slapd/files/common-password
        - backup: ".bak"
{% endif %}

/etc/ldap.secret:
    file.managed:
        - source: salt://slapd/files/ldapscripts.passwd
        - user: root
        - group: root
        - mode: 0400
        - template: jinja

etc-ldap-base:
    file.replace:
        - name: {{ slapd.configfile }}
        - pattern: ^base .*
        - repl: base {{ slapd.get("dc", "dc=foo,dc=bar") }}
    require:
        - file: /etc/ldap.secret

etc-ldap-rootbinddn:
    file.replace:
        - name: {{ slapd.configfile }}
        - pattern: ^rootbinddn .*
        - repl: rootbinddn {{ slapd.get('rootbinddn', 'cn=admin,dc=foo,dc=bar') }}
    require:
        - file: /etc/ldap.secret

etc-ldap-uri:
    file.replace:
        - name: {{ slapd.configfile }}
        - pattern: ^uri ldap.*
        - repl: uri ldap://{{ slapd.get("host", "localhost") }}/
    require:
        - file: /etc/ldap.secret

etc-ldap-host:
    file.replace:
        - name: {{ slapd.configfile }}
        - pattern: ^host .*
        - repl: host {{ slapd.get("host", "localhost") }}
    require:
        - file: /etc/ldap.secret


# do this to check
#
# ldapsearch -w password -x -D cn=admin,dc=foo,dc=bar -b ou=people,dc=foo,dc=bar -s base -ZZ
# 
# disabling tls checks leaves things open for a man in the middle attack,
# certs should be distributed, however for a compute environment this is adequate for now.
etc-ldap-tlscertchain:
    file.replace:
        - name: {{ slapd.ldap_configfile }}
        - pattern: "^TLS_CACERT.*/etc/ssl/certs/ca-certificates.crt"
        - repl: "#TLS_CACERT     /etc/ssl/certs/ca-certificates.crt"
    require:
        - file: /etc/ldap.secret

etc-ldap-tlsreqcert:
    file.append:
        - name: {{ slapd.ldap_configfile }}
        - text: "TLS_REQCERT    never"
    require:
        - file: /etc/ldap.secret

{% if grains['os'] == 'Debian' %}
etc-nsswitch-passwd:
    file.replace:
        - name: /etc/nsswitch.conf
        - pattern: ^passwd:.*
        - repl: "passwd:         compat ldap"

etc-nsswitch-group:
    file.replace:
        - name: /etc/nsswitch.conf
        - pattern: ^group:.*
        - repl: "group:          compat ldap"
 
etc-nsswitch-shadow:
    file.replace:
        - name: /etc/nsswitch.conf
        - pattern: ^shadow:.*
        - repl: "shadow:         compat ldap"

{% endif %}
