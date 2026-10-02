include:
  - haproxy.acme

{% set primary = pillar["tls"]["hosts"][0] %}

salt-acme-bootstrap-config:
  file.managed:
    - name: /etc/haproxy/haproxy.cfg
    - source: salt://haproxy/acme.cfg.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    # A supplied certificate may exist without an acme.sh chain; restore HTTP-01 until issuance.
    - unless: test -s /home/ubuntu/.acme.sh/{{ primary }}_ecc/fullchain.cer
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
    - require_in:
      - cmd: salt-cert-issued
