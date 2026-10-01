versions:
  images:
    livekit: docker.io/livekit/livekit-server:v1.13.7
    redis: docker.io/library/redis:8.10.1-alpine3.23
livekit:
  # Stage uses TURN/TLS only. Enable direct UDP explicitly on Production's host.
  public_udp: false
  relay_range_start: 30000
  relay_range_end: 40000
