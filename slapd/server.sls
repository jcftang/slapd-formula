## This is really ubuntu specific and probably needs to be refactor if debian is needed as a server
{% from "slapd/package-map.jinja" import slapd with context %}

ldap-dependencies:
    pkg.installed:
        - pkgs: {{ slapd.server_pkgs|json }}

{{ slapd.slapd_pkg }}:
    pkg.installed:
      - name: {{ slapd.slapd_pkg }}
    service.running:
        - name: {{ slapd.slapd_pkg }}
        - enable: true

slapd-debconf:
    debconf.set:
        - name: slapd
        - data:
            #'slapd/adminpw': {'type': 'password', 'value': '{{ slapd.get("password", "password") }}' }
            #'slapd/internal/adminpw': {'type': 'password', 'value': '{{ slapd.get("password", "password") }}' }
            #'slapd/internal/generated_adminpw': {'type': 'password', 'value': '{{ slapd.get("password", "password") }}' }
            'slapd/password1': {'type': 'password', 'value': '{{ slapd.get("password", "password") }}' }
            'slapd/password2': {'type': 'password', 'value': '{{ slapd.get("password", "password") }}' }
            'shared/organization': {'type': 'string', 'value': '{{ slapd.get("organisation", "Quux Corp") }}' }
            'slapd/domain': {'type': 'string', 'value': '{{ slapd.get("domain", "foo.bar") }}' }
            'slapd/backend': {'type': 'select', 'value': 'HDB' }
        - require_in:
          - pkg: {{ slapd.slapd_pkg }}

slapd-domain:
  file.managed:
    - source: salt://slapd/files/domain.ldif
    - name: /etc/ldap/domain.ldif
    - user: root
    - group: root
    - template: jinja
  require:
    - pkg: {{ slapd.slapd_pkg }}

ldapscripts-conf:
  file.managed:
    - name: /etc/ldapscripts/ldapscripts.conf
    - source: salt://slapd/files/ldapscripts.conf
    - template: jinja
    - user: root
    - group: root
  require:
    - pkg: {{ slapd.slapd_pkg }}

ldapscripts-passwd:
  file.managed:
    - name: /etc/ldapscripts/ldapscripts.passwd
    - source: salt://slapd/files/ldapscripts.passwd
    - template: jinja
    - user: root
    - group: root
    - mode: 0600
  require:
    - pkg: {{ slapd.slapd_pkg }}

# ldapsearch -w {{ slapd.get("password", "password") }} -x -D cn=admin,{{ slapd.get("dc", "dc") }} -b ou=people,{{ slapd.get("dc", "dc") }} -s base || echo 

##slapd-reconfigure:
##  cmd.run:
##    - name: dpkg-reconfigure -f noninteractive slapd && touch /var/lib/ldap/slapd_created
##    - creates: /var/lib/ldap/slapd_created
##  require:
##    - pkg: {{ slapd.slapd_pkg }}

slapd-domain-conf:
  cmd.run:
    - name: ldapadd -w {{ slapd.get("password", "password") }} -x -D cn=admin,{{ slapd.get("dc", "dc=foo,dc=bar") }}  -f /etc/ldap/domain.ldif && touch /var/lib/ldap/rootdn_created
    #- name: ldapmodify -Y EXTERNAL -H ldapi:/// -f /etc/ldap/domain.ldif 
    - requires:
      - name: slapd-domain
      - pkg: {{ slapd.slapd_pkg }}
    - watch:
      - file: /etc/ldap/domain.ldif
    - creates: /var/lib/ldap/rootdn_created

## setup self signed certs to encrypt everything
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

/etc/ssl/local/certs/{{ slapd.get("slapd_cn") }}.key:
    require:
        - name: self-signed-cert
    file.managed:
        - mode: 0640
        - user: openldap
        - group: openldap

/etc/ssl/local/certs/{{ slapd.get("slapd_cn") }}.crt:
    file.managed:
        - mode: 0640
        - user: openldap
        - group: openldap

/etc/ssl/local/certinfo.ldif:
    file.managed:
        - source: salt://slapd/files/certinfo.ldif
        - name: /etc/ssl/local/certinfo.ldif
        - template: jinja

/etc/ssl/local/certinfo-update.ldif:
    file.managed:
        - source: salt://slapd/files/certinfo-update.ldif
        - name: /etc/ssl/local/certinfo-update.ldif
        - template: jinja

slapd_modify_hosts:
  file.replace:
    - name: /etc/hosts 
    - pattern: ^127\.0\.1\.1.*
    - repl: "127.0.1.1       {{ grains['id'] }}"

#ldapmodify -w {{ slapd.get("password", "password") }} -x -D cn=admin,{{ slapd.get("dc", "dc") }}  -f /etc/ssl/local/certinfo.ldif && touch /var/lib/ldap/certinfo_created:
ldapmodify -Y EXTERNAL -H ldapi:/// -f /etc/ssl/local/certinfo.ldif && touch /etc/ssl/local/certinfo_created:
    cmd.run:
        - creates: /etc/ssl/local/certinfo_created
    require:
        - file: /etc/ssl/local/certinfo.ldif
        - file: /etc/apparmor.d/local/usr.sbin.slapd
        - name: slapd-domain-conf
        - name: service-apparmor
        #- name: modify_hosts

service-apparmor:
    service.running:
        - name: apparmor
        - watch:
            - file: /etc/apparmor.d/usr.sbin.slapd
            - file: /etc/apparmor.d/local/usr.sbin.slapd

/etc/apparmor.d/usr.sbin.slapd:
    file.managed:
        - pattern: "  #include <local/usr.sbin.slapd>"
        - repl: "  include <local/usr.sbin.slapd>"

/etc/apparmor.d/local/usr.sbin.slapd:
    file.managed:
        - source: salt://slapd/files/slapd-app-armor
        - name: /etc/apparmor.d/local/usr.sbin.slapd
        - watch_in:
            - service: {{ slapd.slapd_pkg }}
