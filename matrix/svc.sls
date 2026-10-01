include:
  - matrix.units
  - matrix.runtime

# The pod owns only the shared network namespace. Each application unit starts separately so its
# service dependencies and all native application inputs converge before it runs.
matrix-pod-running:
  user_service.running:
    - name: matrix-pod.service
    - user: ubuntu
    - timeout: 900
    - require:
      - service: salt-user-manager
      - user_service: matrix-pod-quiescent
      - file: matrix-pod-quadlet
      - file: matrix-mas-quadlet
      - file: matrix-synapse-quadlet
      - file: matrix-lk-jwt-quadlet

matrix-mas-running:
  user_service.running:
    - name: mas.service
    - user: ubuntu
    - timeout: 900
    - require:
      - user_service: matrix-pod-running
      - user_service: matrix-mas-quiescent
      - file: matrix-mas-quadlet
      - file: matrix-mas-config
      - file: matrix-private-mas-secrets-json

matrix-synapse-running:
  user_service.running:
    - name: synapse.service
    - user: ubuntu
    - timeout: 900
    - require:
      - user_service: matrix-mas-running
      - user_service: matrix-synapse-quiescent
      - file: matrix-synapse-quadlet
      - file: matrix-synapse-config
      - file: matrix-synapse-log-config
      - file: matrix-private-synapse-secrets-json
      - file: matrix-private-synapse-signing-key
      - file: matrix-private-cashier-synapse-token-env

matrix-lk-jwt-running:
  user_service.running:
    - name: lk-jwt.service
    - user: ubuntu
    - timeout: 900
    - require:
      - user_service: matrix-synapse-running
      - user_service: matrix-lk-jwt-quiescent
      - file: matrix-lk-jwt-quadlet
      - file: matrix-private-livekit-keys-yaml
