# Operator access policy for every target: a hardened sshd and the passwordless sudo rule the
# operator's workflow depends on (SSH key login as ubuntu, then sudo for root). Included by
# os/init.sls and livekit.svc so both hosts carry one posture instead of per-host hand edits.
salt-access-sshd-package:
  pkg.installed:
    - name: openssh-server

salt-sshd-drop-in:
  file.managed:
    - name: /etc/ssh/sshd_config.d/90-salt-hardening.conf
    - contents: |
        Port {{ pillar["network"]["ssh_port"] }}
        PermitRootLogin no
        PubkeyAuthentication yes
        PasswordAuthentication no
        KbdInteractiveAuthentication no
        X11Forwarding no
        AllowUsers ubuntu
        AllowAgentForwarding no
        AllowTcpForwarding no
    - user: root
    - group: root
    - mode: '0644'
    - show_changes: false
    - require:
      - pkg: salt-access-sshd-package

# Stop only the listener; Ubuntu's KillMode=process preserves established SSH sessions.
# The socket remains available for access if a subsequent state fails.
salt-sshd-stop-before-config:
  service.dead:
    - name: ssh.service
    - prereq:
      - file: salt-sshd-drop-in

salt-sshd:
  service.running:
    - name: ssh.service
    - require:
      - file: salt-sshd-drop-in
      - service: salt-sshd-stop-before-config

# Passwordless sudo is the operator's root access.
salt-access-sudoers:
  file.managed:
    - name: /etc/sudoers.d/90-ubuntu-salt
    - contents: 'ubuntu ALL=(ALL:ALL) NOPASSWD:ALL'
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -cf
