# RelayPilot

One profile. Every device. RelayPilot is a local-first network toolbox for macOS, Windows, Linux, iPhone, iPad, Android, and Apple TV — one Racket control plane, first-party native UIs, and the same network decisions everywhere.

**English** · [中文](README.zh-CN.md) · 🌐 [jrtx.site/relaypilot](https://jrtx.site/relaypilot/)

[![CI](https://github.com/turinglambdaai/relaypilot/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/relaypilot/actions/workflows/ci.yml) ![stage](https://img.shields.io/badge/stage-architecture%20alpha-C15F3C) ![built with](https://img.shields.io/badge/built%20with-Rivet-9333ea) ![license](https://img.shields.io/badge/license-Proprietary-red)

RelayPilot is not an "Xray GUI." RelayPilot owns profiles, rules, policy selection, DNS intent, connection history, deterministic decision traces, diagnostics, sync boundaries, and typed AI patches. Xray/libXray is the first protocol engine behind an adapter and may later coexist with a native engine or other implementations.

## What works today

- Canonical Relay Profile JSON with validation and round-trip serialization
- Surge-compatible import for `DOMAIN`, `DOMAIN-SUFFIX`, `IP-CIDR`, `IP-CIDR6`, `GEOIP`, `FINAL`, and `MATCH` syntax
- Deterministic local evaluation for exact domain, suffix, IPv4 CIDR, and final rules
- Select/fallback policy groups with cycle detection and stable selection
- `DecisionTrace`: rule source, policy resolution, selected outbound, steps, warnings, and stable trace ID
- Xray adapter slice for VLESS + RAW/TLS/REALITY, SOCKS ingress, `freedom`/`blackhole`, ordered routes, rule tags, source maps, canonical JSON, and SHA-256 identity
- Atomic local-folder storage boundary; provider-specific sync remains outside the profile model
- Typed `DiagnosticBundle`, secret redaction, and preconditioned `ConfigPatch`
- Rivet RPC boundary for route explanation and deterministic engine compilation
- 40 passing Racket tests on the initial implementation, including an RVT1 round trip
- CI validation of the generated example with checksum-pinned Xray v26.3.27 in `run -test` mode

The repository does **not** yet contain a runnable VPN app, TUN integration, a bundled Xray/libXray binary, native screens, background services, subscriptions, production DNS, or commercial infrastructure. What ships next is tracked in [ROADMAP.md](ROADMAP.md); the control-plane design in [ARCHITECTURE.md](ARCHITECTURE.md).

## First vertical slice

```text
Relay Profile
    ↓ validate
Surge-compatible rules
    ↓ first-match evaluation
Policy group selection
    ↓ deterministic DecisionTrace
EnginePlan + source map
    ↓ Xray adapter
Canonical Xray JSON + SHA-256
    ↓ (next milestone)
Pinned libXray / Xray runtime
```

The same RelayPilot evaluator that explains a route is the source of the adapter plan. Unsupported local semantics are rejected at compilation instead of silently delegating truth to an engine.

## Platform status

| Platform | Native UI target | RelayPilot status |
|---|---|---|
| macOS | SwiftUI/AppKit via Rivet | Host not started; control-plane boundary ready |
| Windows | WinUI 3 via Rivet | Host not started; control-plane boundary ready |
| Linux | GTK4 via Rivet | Host not started; Rivet path remains less mature |
| iOS / iPadOS | SwiftUI + NetworkExtension | Architecture only; no claim of Rivet host support |
| tvOS | SwiftUI + NetworkExtension | Architecture only; libXray cgo feasibility, not a product build |
| Android | Jetpack Compose + VpnService | Architecture only; no claim of Rivet host support |

See [platform maturity](docs/platform-maturity.md) for the exact boundary.

## Build and test

Requires Racket CS 9.x and [Rivet](https://github.com/turinglambdaai/rivet):

```bash
raco pkg install --auto --no-docs rivet
raco make app/backend.rkt
raco test tests/
```

Compile the included non-secret example through the RPC boundary:

```bash
racket -e '(require "app/core/profile/json.rkt" "app/core/engines/xray.rkt") (compile-xray-config (read-relay-profile (string->path "examples/relay-profile.json")))'
```

To write a generated artifact for inspection:

```bash
racket scripts/compile-profile.rkt examples/relay-profile.json /tmp/xray.json
```

## Repository layout

```text
relaypilot/
├── rivet.rktd                 # Rivet application contract
├── app/backend.rkt            # typed native-host RPC boundary
├── app/core/
│   ├── profile/               # canonical Relay Profile
│   ├── rules/                 # Surge syntax + deterministic evaluator
│   ├── policy/                # group selection
│   ├── engines/               # adapter contract + Xray compiler
│   ├── diagnostics/           # DecisionTrace bundles
│   ├── storage/               # local-first provider boundary
│   └── ai/                    # redaction + typed ConfigPatch
├── tests/                     # domain and adapter contract tests
├── examples/                  # synthetic, non-secret profile and rules
├── macos-host/ windows/ linux/# first-party desktop hosts (planned)
├── apple/ android/            # mobile/tv tunnel hosts (planned)
├── docs/                      # product and engineering contracts
└── site/                      # static product site
```

## Product constraints

- Local-first. No required account, license server, RelayPilot cloud, or mandatory service.
- User-owned sync: iCloud Drive first on Apple; local folders and WebDAV across platforms.
- Native UI on every platform. Rivet carries typed application logic, not a cross-platform UI DSL.
- AI can explain or propose a typed, validated patch. It cannot directly mutate a live profile.
- Protocol engines are replaceable infrastructure. RelayPilot-specific semantics stay here.

The commercial model is intentionally deferred. The working direction is a one-time purchase for the current feature generation with optional paid feature updates, at a lower price than Surge.

## License

Copyright © 2026 turinglambdaai. No open-source license has been granted yet. Third-party engine distributions will carry their own notices and source-offer obligations.
