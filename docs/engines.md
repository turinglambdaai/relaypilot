# Engine adapters

An engine adapter consumes a validated Relay Profile through an immutable `EnginePlan`. It emits an engine artifact plus metadata; it does not own profiles or decisions.

## Xray adapter v1

Implemented:

- VLESS outbound fields used by current Xray configuration
- RAW transport normalization (`tcp` imports normalize to current `raw` naming)
- TLS and REALITY client settings
- local SOCKS inbound with metadata-only route sniffing
- direct and block outbounds
- domain, domain-suffix, IPv4 CIDR, and final routes
- deterministic JSON bytes, SHA-256, rule tags, and a source map

Runtime (supervised Xray **process**, `app/core/engines/runtime.rkt`):

- pinned binary discovery (`RELAYPILOT_XRAY_BIN`, then `xray` on `PATH`) and version query
- config validation through `xray run -test` with bounded output evidence
- session start/stop lifecycle: private config dir, readiness probe on the loopback inbound, graceful stop with a kill fallback, private-config cleanup
- bounded structured event bridge (stdout/stderr lines, capped count and length, no config bytes or credentials)
- real loopback SOCKS request through a supervised session in tests and CI

Not implemented:

- embedded libXray (the in-process runtime used by the first native host)
- TUN inbound or platform fd handoff
- VMess, Trojan, Shadowsocks, WireGuard, Hysteria2, HTTP/SOCKS outbound adapters
- subscriptions or URI import
- DNS execution
- IPv6 and GeoIP evaluation parity
- engine statistics ingestion beyond the bounded startup/log event bridge

The configuration contract is based on current official Xray documentation. Runtime work must pin exact libXray and Xray versions because upstream explicitly does not promise libXray API stability.

