# Private setup

Provision Ubuntu 24.04 amd64 with Python 3 and an `ubuntu` account with SSH keys and
passwordless sudo. Keep trusted host keys in the controller's known_hosts. Each
SSH alias is the Salt target; it need not equal the OS hostname or public domain.
Use the dedicated environment deployment key and the actual SSH port.

Copy the example Pillar tree once to a private directory outside the checkout.
Populate each target's settings; rename `hosts/matrix` and `hosts/livekit` to the
actual aliases and update the private `top.sls`. Never overwrite existing private
inputs with examples. Keep this directory mode 0700 and secret files mode 0600.
Ordinary settings/images come from tracked `pillar/`; identity, addresses, domains,
credentials and keys stay private. `shared/stage.sls` owns the site identity and payment-webhook
path shared by Matrix ingress and the application host.

Preserve existing PostgreSQL and S3 credentials, Synapse signing key, MAS encryption
and signing keys, application client credentials, and Cashier service token. Server
recreation does not mean regenerating identities. The Matrix target's secret directory
contains the application-native files referenced by `matrix/runtime.sls`. `rtc.sls`
owns the single LiveKit key and secret; Matrix renders the API key file from those shared
values for the JWT service. Do not duplicate them in per-host settings.

## Certificates

The example Stage host settings currently set `tls.enabled: false`. This skips the
ACME and certificate states and public TCP listeners; Matrix HAProxy keeps its private
application API on port 8080, while LiveKit HAProxy stays stopped. No ACME account key
or thumbprint is needed while TLS is disabled. Set `enabled: true` for both hosts when
the Stage edge can serve HTTP-01 and the private ACME inputs are ready; the existing
stateless acme.sh issuance and renewal states then run as before.

While FreeBSD edge routing is pending, temporary Stage TLS can use an already generated
self-signed PEM by setting `tls.enabled: true` and both `tls.certificate_source` and
`tls.private_key_source` to Salt source URLs for the certificate and matching key. Remove
both source settings after the edge is ready to return to ACME issuance and renewal.

When TLS is enabled, reuse acme.sh stateless HTTP-01 through HAProxy, as in the source
project. Public TCP 80 must reach the owning Linux host's HAProxy; the edge forwards
challenges by Host name. The Matrix host owns its apex/backend certificate and Matrix
signaling domain; the LiveKit host owns the TURN certificate. Salt installs certificates in
`/etc/haproxy/certs/<tls.cert_name>.pem` with the adjacent `.pem.key` file. acme.sh's
cron renews them and reloads that host's HAProxy. The private application host does
not need a public certificate.

For each certificate-owning host, keep its ACME account key at
`hosts/<target>/secrets/acme-account.key` and the matching JWK thumbprint in
`tls.acme_account_thumbprint`. Reuse existing accounts where available. If an account
must be created, download acme.sh from the official release selected by
`pillar/runtime.sls`, run its `--register-account --server letsencrypt` command in a
private temporary directory, and retain the resulting account key and thumbprint in
the private inputs. Salt downloads the same executable from its official source;
no upstream executable is committed here.

With TLS enabled, public MatrixRTC signaling uses TCP 443 on the Matrix backend domain
and media can use TURN/TLS on TCP 443 on the LiveKit host. While Stage TLS is deferred,
neither listener is public. `livekit.public_udp: false` closes inbound UDP. The SFU and
embedded TURN relay still exchange UDP locally. Reserve the shared public
IP's UDP 443 for Production: set `livekit.public_udp: true` in its private host settings
and forward that public UDP port only to its LiveKit host. Neither environment exposes
HTTP/3 on that IP. TCP 80 serves certificate validation when TLS is enabled. Do not
expose the reference project's other media ports.
LiveKit's normal ICE negotiation may try UDP before falling back to TURN/TLS;
this setting controls public reachability, not the client's initial candidate order.
FreeBSD edge forwarding remains owner-operated. Complete the edge routes before
claiming public certificate or media verification; supplied certificates allow private tests meanwhile.

## Controller

Cache the Python environment using the `versions.salt_controller` selection in
`pillar/runtime.sls`. Use the controller session in the
[Harness deployment procedure](https://github.com/TeleCrypt-io/Harness/blob/main/docs/deployment.md).
Controller configuration, generated deployment Pillar, caches, logs and controller
keys live in a private temporary directory removed on exit. Original private inputs
remain outside it. `controller/master.example` lists the native Salt settings.

Preview with `state.highstate test=True`; apply with `state.highstate`, then reapply
unchanged and verify zero changes. Preview is not acceptance. Record the selected
commit, changes, recovery checks and real Stage workflows in Harness's deployment
log before production cutover.
