# Both deployment repositories share the same role entry convention.
base:
  '*':
    - os
    - {{ pillar['deployment']['role'] }}.svc
    - haproxy.ingress
