{% set matrix_address = pillar["network"]["matrix_address"] %}
{% set ingress_proxy_address = pillar["network"]["ingress_proxy_address"] %}
{% set tls_enabled = pillar.get("tls", {}).get("enabled", true) %}

salt-livekit-ufw-package:
  pkg.installed:
    - name: ufw

salt-livekit-ufw-ipv6:
  file.replace:
    - name: /etc/default/ufw
    - pattern: '^IPV6=.*$'
    - repl: 'IPV6=yes'
    - append_if_not_found: true
    - backup: false
    - require:
      - pkg: salt-livekit-ufw-package

salt-livekit-ufw-default-incoming:
  file.replace:
    - name: /etc/default/ufw
    - pattern: '^DEFAULT_INPUT_POLICY=.*$'
    - repl: 'DEFAULT_INPUT_POLICY="DROP"'
    - append_if_not_found: true
    - backup: false
    - require:
      - pkg: salt-livekit-ufw-package

salt-livekit-ufw-manage-builtins:
  file.replace:
    - name: /etc/default/ufw
    - pattern: '^MANAGE_BUILTINS=.*$'
    - repl: 'MANAGE_BUILTINS=yes'
    - append_if_not_found: true
    - backup: false
    - require:
      - pkg: salt-livekit-ufw-package

salt-livekit-ufw-enabled:
  file.replace:
    - name: /etc/ufw/ufw.conf
    - pattern: '^ENABLED=.*$'
    - repl: 'ENABLED=yes'
    - append_if_not_found: true
    - backup: false
    - require:
      - pkg: salt-livekit-ufw-package

{% for suffix, family in (("", "v4"), ("6", "v6")) %}
salt-livekit-ufw-user{{ suffix }}-rules:
  file.managed:
    - name: /etc/ufw/user{{ suffix }}.rules
    - source: salt://livekit/ufw-user.rules.j2
    - template: jinja
    - context:
        family: {{ family }}
        matrix_address: {{ matrix_address | tojson }}
        ingress_proxy_address: {{ ingress_proxy_address | tojson }}
    - user: root
    - group: root
    - mode: '0640'
    - require:
      - pkg: salt-livekit-ufw-package
{% endfor %}

salt-livekit-turn-local-nat:
  file.blockreplace:
    - name: /etc/ufw/before.rules
    - marker_start: '# BEGIN Salt LiveKit local TURN route'
    - marker_end: '# END Salt LiveKit local TURN route'
    - content: |
        *nat
        :OUTPUT ACCEPT [0:0]
        -A OUTPUT -d {{ pillar["livekit"]["node_ip"] }}/32 -p udp -m multiport --dports 443,{{ pillar["livekit"]["relay_range_start"] }}:{{ pillar["livekit"]["relay_range_end"] }} -j DNAT --to-destination {{ pillar["network"]["private_address"] }}
        COMMIT
    - append_if_not_found: true
    - backup: false
    - require:
      - pkg: salt-livekit-ufw-package

salt-livekit-firewall-stop-before-config:
  service.dead:
    - name: ufw
    - require:
      - pkg: salt-livekit-ufw-package
    - prereq:
      - file: salt-livekit-ufw-ipv6
      - file: salt-livekit-ufw-default-incoming
      - file: salt-livekit-ufw-manage-builtins
      - file: salt-livekit-ufw-enabled
      - file: salt-livekit-ufw-user-rules
      - file: salt-livekit-ufw-user6-rules
      - file: salt-livekit-turn-local-nat

salt-livekit-firewall:
  service.running:
    - name: ufw
    - enable: true
    - require:
      - service: salt-livekit-firewall-stop-before-config
      - file: salt-livekit-ufw-ipv6
      - file: salt-livekit-ufw-default-incoming
      - file: salt-livekit-ufw-manage-builtins
      - file: salt-livekit-ufw-enabled
      - file: salt-livekit-ufw-user-rules
      - file: salt-livekit-ufw-user6-rules
      - file: salt-livekit-turn-local-nat
{% if tls_enabled %}
    - require_in:
      - service: salt-acme-bootstrap-service
{% endif %}
