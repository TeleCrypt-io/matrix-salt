# Certificate issuance and installation, driven by pillar["tls"]: cert_name, hosts (first host is
# the acme.sh certificate name), and acme_account_thumbprint. The shared ACME listener states
# live in haproxy/bootstrap.sls; they require_in the states
# below so issuance always runs after a challenge-capable listener is in place.
{% set tls = pillar["tls"] %}
{% set hosts = tls["hosts"] %}
{% set primary = hosts[0] %}
{% set domain_dir = '/home/ubuntu/.acme.sh/' ~ primary ~ '_ecc' %}
{% set issued_chain = domain_dir ~ '/fullchain.cer' %}
{% set domain_conf = domain_dir ~ '/' ~ primary ~ '.conf' %}
{% set cert_file = '/etc/haproxy/certs/' ~ tls["cert_name"] ~ '.pem' %}
{% set key_file = cert_file ~ '.key' %}
{% set reload_cmd = 'sudo -n /usr/bin/systemctl reload haproxy' %}
{% set acme_script = '/home/ubuntu/.acme.sh/acme.sh' %}
{% set issued_cert = salt['x509.read_certificate'](issued_chain) if salt['file.file_exists'](issued_chain) else {} %}
{% set issued_names = issued_cert.get('extensions', {}).get('subjectAltName', {}).get('value', []) %}
{% set requested_names = [] %}
{% for host in hosts %}
  {% set _ = requested_names.append('DNS:' ~ host) %}
{% endfor %}
{% set names_match = issued_names|sort == requested_names|sort %}
include:
  - haproxy.acme
  - os.access

salt-cert-issued:
  cmd.run:
    - name: >-
        {{ acme_script }} --issue --server letsencrypt --stateless --keylength ec-256{% for host in hosts %} -d {{ host }}{% endfor %}
        --key-file {{ key_file }} --fullchain-file {{ cert_file }}
        --reloadcmd '{{ reload_cmd }}' --home /home/ubuntu/.acme.sh
    - runas: ubuntu
    # Setup only: acme.sh's scheduled job owns expiry and renewal.
    # A command guard has its own exit status; module guards can inherit an earlier
    # failed command's retcode from Salt's shared execution context.
    - unless: /usr/bin/{{ "true" if names_match else "false" }}
    - require:
      - file: salt-acme-account-key
      - file: salt-acme-executable
      - file: salt-acme-auto-upgrade-disabled
      - file: salt-haproxy-cert-file
      - file: salt-haproxy-key-file
      - file: salt-access-sudoers

salt-cert-installed:
  cmd.run:
    - name: >-
        {{ acme_script }} --install-cert --ecc -d {{ primary }}
        --key-file {{ key_file }} --fullchain-file {{ cert_file }}
        --reloadcmd '{{ reload_cmd }}' --home /home/ubuntu/.acme.sh
    - runas: ubuntu
    # Set up missing destination files or changed installation settings.
    # acme.sh performs subsequent copies and reloads from its cron job.
    - unless:
      - test -s {{ cert_file }}
      - test -s {{ key_file }}
      - grep -Fxq "Le_RealKeyPath='{{ key_file }}'" {{ domain_conf }}
      - grep -Fxq "Le_RealFullChainPath='{{ cert_file }}'" {{ domain_conf }}
      - grep -Fxq "Le_ReloadCmd='__ACME_BASE64__START_{{ reload_cmd | base64_encode }}__ACME_BASE64__END_'" {{ domain_conf }}
    - require:
      - cmd: salt-cert-issued
      - file: salt-haproxy-cert-file
      - file: salt-haproxy-key-file
      - file: salt-access-sudoers
