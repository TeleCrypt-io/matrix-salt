salt-rsyslog-absent:
  pkg.purged:
    - name: rsyslog

salt-journald-limits:
  file.managed:
    - name: /etc/systemd/journald.conf.d/syslog.conf
    - contents: |
        [Journal]
        ForwardToSyslog=no
        SystemMaxUse=100M
        RuntimeMaxUse=100M
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: true

salt-journald-stop-before-config:
  service.dead:
    - name: systemd-journald.service
    - prereq:
      - file: salt-journald-limits

salt-journald:
  service.running:
    - name: systemd-journald.service
    - require:
      - file: salt-journald-limits
      - service: salt-journald-stop-before-config
