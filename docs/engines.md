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

Not implemented:

- loading or starting Xray/libXray
- TUN inbound or platform fd handoff
- VMess, Trojan, Shadowsocks, WireGuard, Hysteria2, HTTP/SOCKS outbound adapters
- subscriptions or URI import
- DNS execution
- IPv6 and GeoIP evaluation parity
- engine statistics/event ingestion

The configuration contract is based on current official Xray documentation. Runtime work must pin exact libXray and Xray versions because upstream explicitly does not promise libXray API stability.

