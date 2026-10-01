deployment:
  role: livekit
  environment: stage
tls:
  enabled: false
  cert_name: livekit-turn
  hosts: [turn.stage.example.invalid]
  acme_account_thumbprint: REPLACE_WITH_ACCOUNT_THUMBPRINT
network:
  private_address: 192.0.2.30
  matrix_address: 192.0.2.10/32
  ingress_proxy_address: 192.0.2.1
  ssh_port: 22
livekit:
  turn_host: turn.stage.example.invalid
  node_ip: 203.0.113.10
  credentials:
    REDIS_PASSWORD: REPLACE_WITH_RANDOM_PASSWORD
