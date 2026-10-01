deployment:
  role: matrix
  environment: stage
tls:
  enabled: false
  cert_name: matrix
  hosts:
    - stage.example.invalid
    - backend.stage.example.invalid
  acme_account_thumbprint: REPLACE_WITH_ACCOUNT_THUMBPRINT
network:
  private_address: 192.0.2.10
  apps_address: 192.0.2.20
  livekit_address: 192.0.2.30
  ingress_proxy_address: 192.0.2.1
  ssh_port: 22
endpoints:
  cashier_internal_url: http://192.0.2.20:8080
matrix:
  mas:
    admin_client_id: REPLACE_WITH_CANONICAL_JANITOR_CLIENT_ID
