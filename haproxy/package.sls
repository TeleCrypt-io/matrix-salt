{% set versions = pillar["versions"] %}
salt-haproxy-keyring-directory:
  file.directory:
    - name: /usr/share/keyrings
    - mode: '0755'

salt-haproxy-repository-key:
  file.managed:
    - name: /usr/share/keyrings/HAPROXY-key-community.asc
    - source: https://pks.haproxy.com/linux/community/RPM-GPG-KEY-HAProxy
    - skip_verify: true
    - keep_source: false
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: salt-haproxy-keyring-directory

salt-haproxy-repository:
  file.managed:
    - name: /etc/apt/sources.list.d/haproxy.list
    - contents: |
        deb [signed-by=/usr/share/keyrings/HAPROXY-key-community.asc] https://www.haproxy.com/download/haproxy/performance/ubuntu/ha{{ versions.haproxy_series|replace('.', '') }} noble main
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: salt-haproxy-repository-key

salt-haproxy-package:
  pkg.installed:
    - name: haproxy-awslc
    - refresh: true
    - require:
      - file: salt-haproxy-repository
