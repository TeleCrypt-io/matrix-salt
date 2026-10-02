{% set role = pillar['deployment']['role'] %}
{% set tls = pillar.get('tls', {}) %}
{% set tls_enabled = tls.get('enabled', true) %}
{% set supplied_certificate = tls.get('certificate_source') is not none %}
include:
{% if role == 'apps' or not tls_enabled %}
  - haproxy.package
{% elif supplied_certificate %}
  - haproxy.cert
{% else %}
  - haproxy.bootstrap
  - haproxy.cert
{% endif %}

{% if role != 'livekit' or tls_enabled %}
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
{% if role != 'apps' and tls_enabled %}
{% if supplied_certificate %}
      - file: salt-haproxy-cert-file
      - file: salt-haproxy-key-file
{% else %}
      - cmd: salt-cert-installed
{% endif %}
{% endif %}

salt-ingress-stop-before-config:
  service.dead:
    - name: haproxy
    - require:
      - pkg: salt-haproxy-package
{% if role != 'apps' and tls_enabled %}
{% if not supplied_certificate %}
      - cmd: salt-cert-installed
{% endif %}
{% endif %}
    - prereq:
      - file: salt-ingress-config
{% if role != 'apps' and tls_enabled and supplied_certificate %}
      - file: salt-haproxy-cert-file
      - file: salt-haproxy-key-file
{% endif %}

salt-ingress-service:
  service.running:
    - name: haproxy
    - enable: true
    - require:
      - service: salt-ingress-stop-before-config
      - file: salt-ingress-config
{% else %}
salt-ingress-stopped:
  service.dead:
    - name: haproxy
    - enable: false
    - require:
      - pkg: salt-haproxy-package
{% endif %}
