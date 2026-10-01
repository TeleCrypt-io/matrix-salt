# Copy to the private input root. Each key is an exact SSH alias/Salt target.
base:
  matrix:
    - runtime
    - matrix
    - rtc
    - shared.stage
    - hosts.matrix.settings
    - deployment
  livekit:
    - runtime
    - livekit
    - rtc
    - shared.stage
    - hosts.livekit.settings
    - deployment
