include:
  - haproxy.acme

{% set cert_file = '/etc/haproxy/certs/' ~ pillar['tls']['cert_name'] ~ '.pem' %}

salt-acme-bootstrap-config:
  file.managed:
    - name: /etc/haproxy/haproxy.cfg
    - source: salt://haproxy/acme.cfg.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    # Retain an installed runtime configuration during the supplied-certificate transition.
    # A fresh host needs only the same raw TLS dispatcher until issuance succeeds.
    - unless: test -s {{ cert_file }} -a -s {{ cert_file }}.key
    - check_cmd: /usr/sbin/haproxy -c -f
    - require:
      - pkg: salt-haproxy-package
    - require_in:
      - cmd: salt-cert-issued

salt-acme-bootstrap-stop-before-config:
  service.dead:
    - name: haproxy
    - require:
      - pkg: salt-haproxy-package
    - prereq:
      - file: salt-acme-bootstrap-config

salt-acme-bootstrap-service:
  service.running:
    - name: haproxy
    - enable: true
    - require:
      - service: salt-acme-bootstrap-stop-before-config
      - file: salt-acme-bootstrap-config
      - service: salt-ingress-stop-before-certificates
      - file: salt-haproxy-cert-file
      - file: salt-haproxy-key-file
    - require_in:
      - cmd: salt-cert-issued
