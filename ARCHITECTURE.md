# Architecture

## Invariants

1. RelayPilot Core is not Xray Core.
2. A Relay Profile is the only canonical product configuration.
3. Rule evaluation and route explanation are RelayPilot semantics.
4. Engine adapters translate a frozen plan; they do not redefine the plan.
5. Native hosts own presentation and OS lifecycle. Racket owns application policy.
6. Storage providers move canonical bytes and revisions; provider metadata never enters the profile.
7. AI receives a redacted `DiagnosticBundle` and returns a typed `ConfigPatch` with preconditions.

## Layers

```text
First-party native UI
SwiftUI · WinUI 3 · GTK4 · Compose
                 │ typed RVT1 RPC where Rivet is available
                 ▼
RelayPilot control plane (Racket)
Profile · Rules · Policy · DNS intent · Connections · DecisionTrace
Diagnostics · Storage abstraction · AI patch validation
                 │ frozen EnginePlan + source map
                 ▼
EngineAdapter
                 │
       ┌─────────┴─────────┐
       ▼                   ▼
 Xray/libXray         future NativeEngine
 protocol/transport   selected owned paths
                 │
                 ▼
Platform tunnel boundary
NetworkExtension · VpnService · Windows service · Linux daemon
```

## First implemented slice

`app/core/profile/json.rkt` loads and validates schema v1. `app/core/rules/surge.rkt` imports the supported Surge line grammar. `app/core/decision.rkt` produces a stable `DecisionTrace`. `app/core/engines/plan.rkt` freezes current policy selections and source locations. `app/core/engines/xray.rkt` emits canonical JSON and a SHA-256 identity.

The Xray compiler currently supports one intentionally narrow protocol slice: VLESS over RAW with TLS or REALITY. Unsupported protocols and rules fail at compile time. This is preferable to a broad adapter whose runtime behavior RelayPilot cannot explain.

## Xray boundary

The adapter may use Xray routing as the first execution mechanism, but route order, tags, and selected outbounds are generated from the RelayPilot plan. Every generated Xray rule carries `ruleTag: relaypilot:<line>` and the compiled artifact includes a source map back to the canonical rule.

The engine runtime must be version-pinned. libXray documents that it tracks only the latest Xray release and does not guarantee API stability, so adapter compatibility tests and binary provenance are release gates.

The next runtime boundary should expose:

- `validate(config-bytes) -> diagnostics`
- `start(config-bytes, platform-tun-context) -> session-id`
- `stop(session-id)`
- bounded structured events tagged with RelayPilot trace/source identifiers
- engine version, build provenance, and third-party notices

## Rivet boundary

Rivet remains the application foundation for platforms where it is mature: embedding Racket, typed RVT1 transport, generated native clients, resources, packaging, and general desktop services. VPN lifecycle, TUN semantics, engine management, connection models, and profile semantics live in RelayPilot until a capability has demonstrated general value outside this product.

No cross-platform UI DSL is introduced. Each host is a first-party native UI.

## Storage and sync

The storage interface is revision-oriented and provider-neutral. Local folder is first. Planned providers are:

- iCloud Drive document container on Apple platforms;
- user-selected local/synced folder on desktop;
- WebDAV with credentials stored in the OS vault;
- import/export for platforms with constrained background file access.

Conflict handling belongs above providers and operates on profile revisions. Secret material must be separable before broad sync support is enabled.

## Deterministic observability

`DecisionTrace` is generated before an engine runs. Engine events enrich a trace but never replace its rule/policy explanation. If a platform or engine cannot provide a fact, the field remains explicitly unavailable rather than inferred from logs.

