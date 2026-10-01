{% set data_dir = "/home/ubuntu/salt_config" %}
{% set runtime_dir = data_dir ~ "/runtime" %}
{% set secrets_dir = data_dir ~ "/secrets" %}

matrix-data-directory:
  file.directory:
    - name: {{ data_dir }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true
    - require:
      - user: salt-operator

matrix-runtime-directory:
  file.directory:
    - name: {{ runtime_dir }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - require:
      - file: matrix-data-directory

matrix-secrets-directory:
  file.directory:
    - name: {{ secrets_dir }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - require:
      - file: matrix-data-directory

# This path contains only disposable media staging/cache data. S3 remains the durable media store.
matrix-synapse-staging-directory:
  file.directory:
    - name: {{ runtime_dir }}/synapse-staging
    - user: ubuntu
    - group: ubuntu
    - mode: '1777'
    - makedirs: true
    - require:
      - file: matrix-runtime-directory

matrix-synapse-config:
  file.managed:
    - name: {{ runtime_dir }}/synapse.yaml
    - source: salt://matrix/synapse/homeserver.yaml.j2
    - template: jinja
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - show_changes: false
    - require:
      - file: matrix-runtime-directory

matrix-synapse-log-config:
  file.managed:
    - name: {{ runtime_dir }}/synapse.log.config
    - source: salt://matrix/synapse/log.config.j2
    - template: jinja
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - show_changes: false
    - require:
      - file: matrix-runtime-directory

matrix-mas-config:
  file.managed:
    - name: {{ runtime_dir }}/mas.yaml
    - source: salt://matrix/mas/config.yaml.j2
    - template: jinja
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - show_changes: false
    - require:
      - file: matrix-runtime-directory

# Synapse and MAS keep their complete native secret overlays as owner-provided files. The signing
# key and Cashier credential stay separate at their consumers.
{% for name, target_name, mode in (
  ("synapse.secrets.json", "synapse.secrets.json", "0444"),
  ("mas.secrets.json", "mas.secrets.json", "0444"),
  ("synapse_signing.key", "synapse_signing.key", "0444"),
  ("cashier-synapse-token.env", "cashier-synapse-token.env", "0600")
) %}
matrix-private-{{ target_name|replace(".", "-")|replace("_", "-") }}:
  file.managed:
    - name: {{ secrets_dir }}/{{ target_name }}
    - source: salt://hosts/{{ grains["id"] }}/secrets/{{ name }}
    - user: ubuntu
    - group: ubuntu
    - mode: '{{ mode }}'
    - show_changes: false
    - require:
      - file: matrix-secrets-directory
{% endfor %}

# LiveKit's API reads a top-level API-key-to-secret YAML map and rejects files with any
# world permission. Rootless container UID 991 maps to host UID/GID 100990 (100000 + 990).
matrix-private-livekit-keys-yaml:
  file.managed:
    - name: {{ secrets_dir }}/livekit.keys.yaml
    - contents: |
        {{ pillar["rtc"]["key"] | tojson }}: {{ pillar["rtc"]["secret"] | tojson }}
    - user: 100990
    - group: 100990
    - mode: '0400'
    - show_changes: false
    - require:
      - file: matrix-secrets-directory
