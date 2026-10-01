{% set versions = pillar["versions"] %}
{% set tls = pillar["tls"] %}
include:
  - haproxy.package

salt-acme-home:
  file.directory:
    - name: /home/ubuntu/.acme.sh
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true

salt-acme-executable:
  file.managed:
    - name: /home/ubuntu/.acme.sh/acme.sh
    - source: https://raw.githubusercontent.com/acmesh-official/acme.sh/{{ versions.acme_sh }}/acme.sh
    - skip_verify: true
    - keep_source: false
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - require:
      - file: salt-acme-home

# Stateless challenges must use the thumbprint of this exact account key.
# Private Pillar supplies the thumbprint reported when this account is registered.
salt-acme-account-directory:
  file.directory:
    - name: /home/ubuntu/.acme.sh/ca/acme-v02.api.letsencrypt.org/directory
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true
    - require:
      - file: salt-acme-home

salt-acme-account-key:
  file.managed:
    - name: /home/ubuntu/.acme.sh/ca/acme-v02.api.letsencrypt.org/directory/account.key
    - source: salt://hosts/{{ grains['id'] }}/secrets/acme-account.key
    - user: ubuntu
    - group: ubuntu
    - mode: '0600'
    - show_changes: false
    - require:
      - file: salt-acme-account-directory

salt-acme-account-config:
  file.managed:
    - name: /home/ubuntu/.acme.sh/account.conf
    - contents: "AUTO_UPGRADE='0'"
    - replace: false
    - user: ubuntu
    - group: ubuntu
    - mode: '0600'
    - require:
      - file: salt-acme-home

salt-acme-auto-upgrade-disabled:
  file.replace:
    - name: /home/ubuntu/.acme.sh/account.conf
    - pattern: '^AUTO_UPGRADE=.*$'
    - repl: "AUTO_UPGRADE='0'"
    - append_if_not_found: true
    - backup: false
    # Match acme.sh's _saveaccountconf quoting so both writers preserve the same value.
    - require:
      - file: salt-acme-account-config

salt-haproxy-certs-directory:
  file.directory:
    - name: /etc/haproxy/certs
    - user: root
    - group: haproxy
    - mode: '0755'
    - require:
      - pkg: salt-haproxy-package

# acme.sh preserves owner and mode when it updates an existing file. Keep the files writable by
# ubuntu for unattended renewal and readable by HAProxy; Salt manages their metadata, not content.
salt-haproxy-cert-file:
  file.managed:
    - name: /etc/haproxy/certs/{{ tls["cert_name"] }}.pem
    - user: ubuntu
    - group: haproxy
    - mode: '0640'
    - replace: false
    - show_changes: false
    - require:
      - file: salt-haproxy-certs-directory

salt-haproxy-key-file:
  file.managed:
    - name: /etc/haproxy/certs/{{ tls["cert_name"] }}.pem.key
    - user: ubuntu
    - group: haproxy
    - mode: '0640'
    - replace: false
    - show_changes: false
    - require:
      - file: salt-haproxy-certs-directory

salt-acme-renewal:
  cron.present:
    - name: /home/ubuntu/.acme.sh/acme.sh --cron --home /home/ubuntu/.acme.sh >/dev/null
    - user: ubuntu
    - minute: 17
    - hour: '3,15'
    - require:
      - file: salt-acme-executable
      - file: salt-acme-auto-upgrade-disabled
      - cmd: salt-cert-installed
