# Roadmap

## M0 — Control-plane vertical slice (current)

- [x] Canonical Relay Profile schema and validation
- [x] Surge rule-line import
- [x] Deterministic domain, suffix, IPv4 CIDR, and final evaluation
- [x] Policy group selection and DecisionTrace
- [x] EngineAdapter and Xray VLESS/REALITY compiler
- [x] Canonical engine artifact, SHA-256, and rule source map
- [x] Atomic local-folder storage boundary
- [x] DiagnosticBundle, redaction, and typed ConfigPatch
- [x] Rivet RPC boundary and tests

## M1 — First real engine session

- [x] Pin Xray v26.3.27 for configuration compatibility and record checksums/provenance
- [x] Validate generated configuration with that exact binary in CI
- [ ] Pin the platform-specific libXray build used by the first runtime host
- Add a supervised process/library lifecycle adapter and structured event bridge
- Run a real loopback SOCKS request through a local test endpoint
- Keep credentials synthetic in CI and add third-party notices/source-offer workflow

## M2 — First usable desktop path

- Implement one native desktop host, preferably macOS or Windows
- Connect/disconnect/status and a minimal connection/DecisionTrace inspector
- Add the platform tunnel/service boundary without moving VPN semantics into Rivet
- Import a real user-owned Surge profile subset and report unsupported fields

## M3 — Cross-platform proof

- Implement the second desktop host on a different OS family
- Sync the same canonical profile through a user-owned folder
- Prove the same decision fixtures on both platforms
- Add DNS policy execution and IPv6 parity before claiming network consistency

## Later

iOS/iPadOS/tvOS NetworkExtension, Android VpnService, Linux daemon/TUN, subscriptions, iCloud Drive, WebDAV, connection history, richer diagnosis, and carefully selected NativeEngine capabilities.
