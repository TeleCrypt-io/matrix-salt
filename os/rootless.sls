{% set versions = pillar["versions"] %}
{% set uid = salt["user.info"]("ubuntu").get("uid", 1000)|int %}

# Alvistack's OBS signing key is scoped to this source with Signed-By; it is not imported into
# a system-wide trusted keyring. Fingerprint: 789C FFDE 0295 B8A1 F4E5 690C 4BEC C975 50D0 B1FD.
salt-alvistack-keyring-directory:
  file.directory:
    - name: /etc/apt/keyrings
    - user: root
    - group: root
    - mode: '0755'

salt-alvistack-repository-key:
  file.managed:
    - name: /etc/apt/keyrings/alvistack.asc
    - source: https://download.opensuse.org/repositories/home:/alvistack/xUbuntu_24.04/Release.key
    - skip_verify: true
    - keep_source: false
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: salt-alvistack-keyring-directory

salt-alvistack-repository:
  file.managed:
    - name: /etc/apt/sources.list.d/alvistack.list
    - contents: |
        deb [arch=amd64 signed-by=/etc/apt/keyrings/alvistack.asc] https://download.opensuse.org/repositories/home:/alvistack/xUbuntu_24.04/ /
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: salt-alvistack-repository-key

# Keep this OBS source available only to the Podman toolchain; Ubuntu remains the preferred source
# for unrelated packages on both hosts.
salt-alvistack-package-preferences:
  file.managed:
    - name: /etc/apt/preferences.d/alvistack-containers
    - contents: |
        Package: buildah catatonit conmon containernetworking containernetworking-plugins containers-common containers-storage crun fuse-overlayfs passt podman podman-aardvark-dns podman-netavark skopeo
        Pin: origin "download.opensuse.org"
        Pin-Priority: 700

        Package: *
        Pin: origin "download.opensuse.org"
        Pin-Priority: 1
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: salt-alvistack-repository

salt-operator:
  user.present:
    - name: ubuntu
    - remove_groups: false

# Alvistack's system storage.conf uses root-owned graphroot/runroot paths.
# Declare the operator's rootless storage locations explicitly.
salt-operator-containers-directory:
  file.directory:
    - name: /home/ubuntu/.config/containers
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true
    - require:
      - user: salt-operator

salt-operator-storage:
  file.managed:
    - name: /home/ubuntu/.config/containers/storage.conf
    - contents: |
        [storage]
        driver = "overlay"
        runroot = "/run/user/{{ uid }}/containers"
        graphroot = "/home/ubuntu/.local/share/containers/storage"
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - require:
      - file: salt-operator-containers-directory

salt-runtime-prerequisites:
  pkg.installed:
    - pkgs:
      - ca-certificates
      - curl
      - dbus-user-session
      - uidmap

salt-runtime-packages:
  pkg.installed:
    - pkgs:
      - buildah
      - catatonit
      - conmon
      - containernetworking-plugins
      - containers-common
      - containers-storage
      - crun
      - fuse-overlayfs
      - passt: '{{ versions.passt }}'
      - podman: '{{ versions.podman }}'
      - podman-aardvark-dns
      - podman-netavark
      - skopeo
    - refresh: true
    - ignore_epoch: false
    - require:
      - pkg: salt-runtime-prerequisites
      - file: salt-alvistack-package-preferences

salt-user-manager-delegation:
  file.managed:
    - name: /etc/systemd/system/user@.service.d/delegate.conf
    - contents: |
        [Service]
        Delegate=cpu cpuset io memory pids
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: true

salt-user-manager:
  service.running:
    - name: user@{{ uid }}.service
    - require:
      - user: salt-operator
      - file: salt-user-manager-delegation
      - file: salt-linger
      - pkg: salt-runtime-prerequisites
      - pkg: salt-runtime-packages
      - file: salt-operator-storage
      - file: salt-subuid
      - file: salt-subgid

salt-subuid:
  file.replace:
    - name: /etc/subuid
    - pattern: '^ubuntu:[0-9]+:[0-9]+$'
    - repl: 'ubuntu:100000:65536'
    - count: 1
    - append_if_not_found: true
    - backup: false
    - flags:
      - MULTILINE
    - require:
      - user: salt-operator

salt-subgid:
  file.replace:
    - name: /etc/subgid
    - pattern: '^ubuntu:[0-9]+:[0-9]+$'
    - repl: 'ubuntu:100000:65536'
    - count: 1
    - append_if_not_found: true
    - backup: false
    - flags:
      - MULTILINE
    - require:
      - user: salt-operator

# Linger is the systemd-native switch that keeps ubuntu's user manager available at boot and
# without a login session.
salt-linger:
  file.managed:
    - name: /var/lib/systemd/linger/ubuntu
    - user: root
    - group: root
    - mode: '0644'
    - contents: ''
    - require:
      - user: salt-operator
