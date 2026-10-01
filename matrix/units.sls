{% set quadlet_dir = "/home/ubuntu/.config/containers/systemd" %}
{% set images = pillar["versions"]["images"] %}

matrix-quadlet-directory:
  file.directory:
    - name: {{ quadlet_dir }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true
    - require:
      - user: salt-operator

# Stopping the Quadlet pod stops its BindsTo containers before Salt replaces the pod definition.
matrix-pod-quiescent:
  user_service.dead:
    - name: matrix-pod.service
    - user: ubuntu
    - timeout: 900
    - prereq:
      - file: matrix-pod-quadlet
    - require:
      - service: salt-user-manager

matrix-pod-quadlet:
  file.managed:
    - name: {{ quadlet_dir }}/matrix.pod
    - source: salt://matrix/quadlet/matrix.pod
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - follow_symlinks: false
    - require:
      - file: matrix-quadlet-directory

{% set service_inputs = {
  "mas": (
    "matrix-mas-quadlet",
    "matrix-mas-config",
    "matrix-private-mas-secrets-json"
  ),
  "synapse": (
    "matrix-synapse-quadlet",
    "matrix-synapse-config",
    "matrix-synapse-log-config",
    "matrix-private-synapse-secrets-json",
    "matrix-private-synapse-signing-key",
    "matrix-private-cashier-synapse-token-env"
  ),
  "lk-jwt": (
    "matrix-lk-jwt-quadlet",
    "matrix-private-livekit-keys-yaml"
  )
} %}
{% for name in ("mas", "synapse", "lk-jwt") %}
matrix-{{ name }}-quiescent:
  user_service.dead:
    - name: {{ name }}.service
    - user: ubuntu
    - timeout: 900
    - prereq:
{% for state in service_inputs[name] %}
      - file: {{ state }}
{% endfor %}
    - require:
      - service: salt-user-manager

matrix-{{ name }}-quadlet:
  file.managed:
    - name: {{ quadlet_dir }}/{{ name }}.container
    - source: salt://matrix/quadlet/{{ name }}.container
    - template: jinja
    - context:
        image: {{ images[name] }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - follow_symlinks: false
    - require:
      - file: matrix-quadlet-directory
      - file: matrix-pod-quadlet
{% endfor %}
