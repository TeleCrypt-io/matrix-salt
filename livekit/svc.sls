{% set data_dir = "/home/ubuntu/salt_config/livekit" %}
{% set quadlet_dir = "/home/ubuntu/.config/containers/systemd" %}

include:
  - livekit.firewall

salt-livekit-data-directory:
  file.directory:
    - name: /home/ubuntu/salt_config
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true
    - require:
      - user: salt-operator

salt-livekit-configuration-directory:
  file.directory:
    - name: {{ data_dir }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true
    - require:
      - file: salt-livekit-data-directory

salt-livekit-quadlet-directory:
  file.directory:
    - name: {{ quadlet_dir }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true

# The official image drops to UID 999 after its entrypoint. In the rootless
# user namespace that UID maps to host UID 100998, so the read-only config stays
# private to Redis while the host parent remains 0700.
salt-livekit-redis-config:
  file.managed:
    - name: {{ data_dir }}/redis.conf
    - source: salt://livekit/redis.conf.j2
    - template: jinja
    - user: 100998
    - group: 100998
    - mode: '0400'
    - show_changes: false
    - require:
      - file: salt-livekit-configuration-directory

salt-livekit-redis-health-environment:
  file.managed:
    - name: {{ data_dir }}/redis-health.env
    - source: salt://livekit/redis-health.env.j2
    - template: jinja
    - user: ubuntu
    - group: ubuntu
    - mode: '0400'
    - show_changes: false
    - require:
      - file: salt-livekit-configuration-directory

salt-livekit-config:
  file.managed:
    - name: {{ data_dir }}/livekit.yaml
    - source: salt://livekit/config.yaml.j2
    - template: jinja
    - user: ubuntu
    - group: ubuntu
    - mode: '0400'
    - show_changes: false
    - require:
      - file: salt-livekit-configuration-directory

{% for name, image in (("livekit.container", pillar["versions"]["images"]["livekit"]), ("redis.container", pillar["versions"]["images"]["redis"])) %}
salt-livekit-quadlet-{{ name|replace(".", "-") }}:
  file.managed:
    - name: {{ quadlet_dir }}/{{ name }}
    - source: salt://livekit/quadlet/{{ name }}
    - template: jinja
    - context:
        image: {{ image }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - require:
      - file: salt-livekit-quadlet-directory
{% endfor %}

salt-livekit-quadlet-redis-data-volume:
  file.managed:
    - name: {{ quadlet_dir }}/redis-data.volume
    - source: salt://livekit/quadlet/redis-data.volume
    - template: jinja
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - require:
      - file: salt-livekit-quadlet-directory

# UDP/443 is the single LiveKit ICE mux listener. Rootless host networking can
# bind it once this kernel threshold is lowered; that grants unprivileged
# processes in this host's user namespaces access to ports 443 and higher.
salt-livekit-unprivileged-port-start:
  sysctl.present:
    - name: net.ipv4.ip_unprivileged_port_start
    - value: 443
    - config: /etc/sysctl.d/60-livekit.conf

salt-livekit-redis-stop-before-config:
  user_service.dead:
    - name: redis.service
    - user: ubuntu
    - timeout: 40
    - require:
      - service: salt-user-manager
    - prereq:
      - file: salt-livekit-redis-config
      - file: salt-livekit-redis-health-environment
      - file: salt-livekit-quadlet-redis-container
      - file: salt-livekit-quadlet-redis-data-volume

salt-livekit-stop-before-config:
  user_service.dead:
    - name: livekit.service
    - user: ubuntu
    - timeout: 140
    - require:
      - service: salt-user-manager
    - prereq:
      - file: salt-livekit-config
      - file: salt-livekit-quadlet-livekit-container

salt-livekit-redis-running:
  user_service.running:
    - name: redis.service
    - user: ubuntu
    - timeout: 960
    - require:
      - user_service: salt-livekit-redis-stop-before-config
      - service: salt-user-manager
      - service: salt-livekit-firewall
      - file: salt-livekit-redis-config
      - file: salt-livekit-redis-health-environment
      - file: salt-livekit-quadlet-redis-container
      - file: salt-livekit-quadlet-redis-data-volume

salt-livekit-running:
  user_service.running:
    - name: livekit.service
    - user: ubuntu
    - timeout: 960
    - require:
      - user_service: salt-livekit-redis-running
      - user_service: salt-livekit-stop-before-config
      - service: salt-user-manager
      - service: salt-livekit-firewall
      - sysctl: salt-livekit-unprivileged-port-start
      - file: salt-livekit-config
      - file: salt-livekit-quadlet-livekit-container
