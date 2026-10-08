# RelayPilot agent contract

## Product boundary

- RelayPilot is an independent local-first network toolbox. Proxying is foundational, not the product boundary.
- Keep canonical profiles, rules, policy selection, DNS intent, connections, DecisionTrace, diagnostics, storage/sync, and AI patches inside RelayPilot.
- Treat Xray/libXray as an `EngineAdapter`, never as RelayPilot's data model.
- Do not invent new proxy protocols or begin a ground-up proxy core rewrite.

## Rivet boundary

- Preserve Racket application logic and first-party native UIs: SwiftUI/AppKit, WinUI 3, GTK4, and Compose.
- Do not introduce a cross-platform UI DSL or alter RVT1/embedding/runtime for product-specific needs.
- Keep VPN/TUN/service/engine semantics here. Open a Rivet issue or PR only after demonstrating a generally useful application primitive.

## Truthfulness

- Do not mark a platform supported until its native host and a real data path are verified.
- Every engine artifact must identify adapter version, engine version or pending boundary, deterministic digest, and source map.
- Unsupported imported syntax must produce a precise diagnostic. Never silently change semantics.
- AI never writes a live profile directly. Redact, validate a typed patch, simulate, preview, then require user apply.

## Verification

Run before submitting changes:

```bash
raco make app/backend.rkt
raco test tests/
```

Runtime/host changes need an end-to-end test on their target OS. Apple native validation belongs on macOS CI; do not claim it from Windows.

