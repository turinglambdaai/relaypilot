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

## 当前交付优先级（2026-10-23）

保留架构 Alpha，暂不销售；下一步仅限 profile→DecisionTrace→adapter dry-run 的可执行纵切，不把目标平台写成已支持。

执行场景与完成标准见[本仓审查 issue](https://github.com/turinglambdaai/relaypilot/issues/1)及家族[交付标准](https://github.com/turinglambdaai/turinglambdaai.github.io/blob/master/docs/PRODUCT-STANDARD.md)。未完成的跨平台、硬件或真实支付验证仍是显式门禁；本节不表示这些验证已通过。后续一次认领一个切片，证据回填本文件与 issue。
