# Matrix deployment through Salt SSH

TeleCrypt's custom Synapse and policy module, MAS and MatrixRTC JWT run on the
Matrix host. LiveKit and Redis run on a separate host. Application containers run
as `ubuntu` under rootless Podman/Quadlet. PostgreSQL and durable S3 remain external.
HAProxy owns ingress; acme.sh owns HTTP-01 certificate issuance and renewal.

This is adapted source from [PotemkinCo/matrix-salt](https://github.com/PotemkinCo/matrix-salt),
with no GitHub fork relationship. Upstream licenses and attribution are retained.
Versions and images are native Salt Pillar values in `pillar/`; there is no separate
version catalog, image manifest or configuration release package.

With `tls.enabled: false`, public TLS listeners and certificate issuance are skipped.
Matrix HAProxy still serves the private application API on port 8080; LiveKit HAProxy
stays stopped. Production can enable direct UDP 443
in its private host settings; the shared public UDP port belongs to only that LiveKit
host, not Stage or HTTP/3.

While FreeBSD edge routing is pending, temporary Stage TLS can be enabled with an
already generated certificate by setting `tls.enabled: true` plus both
`tls.certificate_source` and `tls.private_key_source` to their Salt source URLs. Remove
both source settings when the edge is ready to restore the normal ACME issuance path.

LiveKit's TURN relay advertises `livekit.node_ip` on its configured UDP relay
range. The incoming firewall keeps that range closed; an OUTPUT-only UFW DNAT
maps this host's UDP traffic to its own advertised IP on UDP 443 and the relay
range back to `network.private_address`.

Use a clean configuration commit, private inputs and native `salt-ssh state.highstate`.
See [private inputs](examples/README.md) and the authoritative
[Harness deployment procedure](https://github.com/TeleCrypt-io/Harness/blob/main/docs/deployment.md).
The application deployment reuses the OS, HAProxy and user-service states through
a pinned Git submodule; it selects its own images and highstate.

Unchanged inputs must make no changes. Files stop their affected service before
replacement; running states recover a service left stopped by an interrupted apply.
Verify convergence, interruption recovery and actual product workflows on Stage.
The [Harness deployment log](https://github.com/TeleCrypt-io/Harness/blob/main/docs/deployment-log.md)
records the current deployment and acceptance results.
