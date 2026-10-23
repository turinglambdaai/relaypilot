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
- [x] Supervised process lifecycle adapter (`app/core/engines/runtime.rkt`): binary discovery, version query, `run -test` validation, session start/stop with bounded structured events
- [x] Real loopback SOCKS request through a supervised local engine session against a local test endpoint (CI + local, synthetic credentials only)
- [x] Credentials synthetic in CI; third-party notices/source-offer workflow (`scripts/third-party-notices.rkt`, `docs/third-party.md`)
- [ ] Pin the platform-specific libXray build used by the first runtime host (stays open until the first embedded runtime exists; the process pin above is separate)

## M2 — First usable desktop path

- [ ] Implement one native desktop host, preferably macOS or Windows
- [ ] Connect/disconnect/status and a minimal connection/DecisionTrace inspector
- [ ] Add the platform tunnel/service boundary without moving VPN semantics into Rivet
- [ ] Import a real user-owned Surge profile subset and report unsupported fields

## M3 — Cross-platform proof

- [ ] Implement the second desktop host on a different OS family
- [ ] Sync the same canonical profile through a user-owned folder
- [ ] Prove the same decision fixtures on both platforms
- [ ] Add DNS policy execution and IPv6 parity before claiming network consistency

## Later

iOS/iPadOS/tvOS NetworkExtension, Android VpnService, Linux daemon/TUN, subscriptions, iCloud Drive, WebDAV, connection history, richer diagnosis, and carefully selected NativeEngine capabilities.

## 当前交付优先级（2026-10-23）

保留架构 Alpha，暂不销售。profile→DecisionTrace→adapter dry-run→诊断的可执行纵切已于 2026-10-23 交付：agent-first CLI（`docs/CLI-SPEC.md` + 20 例 golden 契约）、受监督 Xray 进程 runtime（pin v26.3.27）、回环 SOCKS 实测、事件桥、RPC dry-run/会话扩展、notices/source-offer 工作流。未完成的跨平台、硬件或真实支付验证仍是显式门禁；本节不表示这些验证已通过。目标平台仍未支持，不把架构能力写成产品能力。

执行场景与完成标准见[本仓审查 issue](https://github.com/turinglambdaai/relaypilot/issues/1)及家族[交付标准](https://github.com/turinglambdaai/turinglambdaai.github.io/blob/master/docs/PRODUCT-STANDARD.md)。后续一次认领一个切片（下一个：M2 第一条原生桌面宿主路径或实际网络接管评审切片），证据回填本文件与 issue。
