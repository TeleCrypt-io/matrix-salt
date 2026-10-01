# Identity of the selected configuration, not a deployment-success receipt.
# Salt's result and actual service health establish whether the apply succeeded.
salt-source-commit:
  file.managed:
    - name: /etc/salt-source-commit
    - contents: '{{ pillar["deployment"]["commit"] }}'
    - user: root
    - group: root
    - mode: '0644'
