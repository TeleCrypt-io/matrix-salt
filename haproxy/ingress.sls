{% set role = pillar['deployment']['role'] %}
include:
{% if role == 'apps' %}
  - haproxy.package
{% else %}
  - haproxy.bootstrap
  - haproxy.cert
{% endif %}

salt-ingress-config:
  file.managed:
    - name: /etc/haproxy/haproxy.cfg
    - source: salt://{{ 'apps/haproxy.cfg.j2' if role == 'apps' else 'haproxy/' ~ role ~ '.cfg.j2' }}
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - show_changes: false
    - check_cmd: /usr/sbin/haproxy -c -f
    - require:
      - pkg: salt-haproxy-package
{% if role != 'apps' %}
      - cmd: salt-cert-installed
{% endif %}

salt-ingress-stop-before-config:
  service.dead:
    - name: haproxy
    - require:
      - pkg: salt-haproxy-package
{% if role != 'apps' %}
      - cmd: salt-cert-installed
{% endif %}
    - prereq:
      - file: salt-ingress-config

salt-ingress-service:
  service.running:
    - name: haproxy
    - enable: true
    - require:
      - service: salt-ingress-stop-before-config
      - file: salt-ingress-config
