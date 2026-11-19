# Shared by Matrix and Apps; each VM owns its own database storage.
{% set base = '/home/ubuntu/salt_config' %}
{% set units = '/home/ubuntu/.config/containers/systemd' %}
{% set peers = [pillar['network'].get('matrix_address'), pillar['network'].get('apps_address')] %}
{% for directory in [base, base ~ '/secrets', units] %}
{{ directory }}:
  file.directory:
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true
{% endfor %}

postgres-environment:
  file.managed:
    - name: {{ base }}/secrets/postgres.env
    - source: salt://hosts/{{ grains['id'] }}/secrets/postgres.env
    - user: ubuntu
    - group: ubuntu
    - mode: '0600'
    - show_changes: false
    - require:
      - file: {{ base }}/secrets

{{ base }}/postgres-tls:
  file.directory:
    - user: 100998
    - group: 100998
    - mode: '0700'
    - require:
      - file: {{ base }}

postgres-tls:
  cmd.run:
    - name: >-
        openssl req -x509 -newkey rsa:3072 -nodes -days 3650
        -subj /CN=telecrypt-postgresql
        -keyout {{ base }}/postgres-tls/server.key
        -out {{ base }}/postgres-tls/server.crt
        && chown 100998:100998 {{ base }}/postgres-tls/server.key {{ base }}/postgres-tls/server.crt
        && chmod 0600 {{ base }}/postgres-tls/server.key
    - creates: {{ base }}/postgres-tls/server.key
    - require:
      - file: {{ base }}/postgres-tls

postgres-quiescent:
  user_service.dead:
    - name: postgres.service
    - user: ubuntu
    - timeout: 120
    - prereq:
      - file: postgres-quadlet
      - file: postgres-environment

postgres-quadlet:
  file.managed:
    - name: {{ units }}/postgres.container
    - source: salt://postgres/postgres.container.j2
    - template: jinja
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - require:
      - file: {{ units }}

postgres-volume:
  file.managed:
    - name: {{ units }}/postgres-data.volume
    - source: salt://postgres/postgres-data.volume
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - require:
      - file: {{ units }}

postgres-running:
  user_service.running:
    - name: postgres.service
    - user: ubuntu
    - timeout: 900
    - require:
      - user_service: postgres-quiescent
      - file: postgres-quadlet
      - file: postgres-volume
      - file: postgres-environment
      - cmd: postgres-tls
