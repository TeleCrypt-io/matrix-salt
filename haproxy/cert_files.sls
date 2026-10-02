{% set tls = pillar["tls"] %}
{% set certificate_source = tls.get("certificate_source") %}
{% set supplied_certificate = certificate_source is not none %}

include:
  - haproxy.package

salt-haproxy-certs-directory:
  file.directory:
    - name: /etc/haproxy/certs
    - user: root
    - group: haproxy
    - mode: '0755'
    - require:
      - pkg: salt-haproxy-package

# acme.sh preserves owner and mode when it updates an existing file. Keep the files writable by
# ubuntu for unattended renewal and readable by HAProxy; Salt manages their metadata by default.
salt-haproxy-cert-file:
  file.managed:
    - name: /etc/haproxy/certs/{{ tls["cert_name"] }}.pem
{% if supplied_certificate %}
    - source: {{ certificate_source | tojson }}
    - replace: true
{% else %}
    - replace: false
{% endif %}
    - user: ubuntu
    - group: haproxy
    - mode: '0640'
    - show_changes: false
    - require:
      - file: salt-haproxy-certs-directory

salt-haproxy-key-file:
  file.managed:
    - name: /etc/haproxy/certs/{{ tls["cert_name"] }}.pem.key
{% if supplied_certificate %}
    - source: {{ tls["private_key_source"] | tojson }}
    - replace: true
{% else %}
    - replace: false
{% endif %}
    - user: ubuntu
    - group: haproxy
    - mode: '0640'
    - show_changes: false
    - require:
      - file: salt-haproxy-certs-directory
