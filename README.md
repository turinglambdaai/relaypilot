# RelayPilot

RelayPilot is an architecture alpha for canonical network profiles and explainable routing. It currently provides a Racket source CLI and a supervised loopback engine slice; planned native hosts are not released clients.

[![CI](https://github.com/turinglambdaai/relaypilot/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/relaypilot/actions/workflows/ci.yml) ![built with](https://img.shields.io/badge/built%20with-Rivet-9333ea) ![license](https://img.shields.io/badge/license-Proprietary-red) ![stage](https://img.shields.io/badge/stage-architecture%20alpha-C15F3C)

**English** · [中文](README.zh-CN.md) · 🌐 [jrtx.site/relaypilot](https://jrtx.site/relaypilot/)

RelayPilot is not an "Xray GUI." RelayPilot owns profiles, rules, policy selection, DNS intent, connection history, deterministic decision traces, diagnostics, sync boundaries, and typed AI patches. Xray/libXray is the first protocol engine behind an adapter and may later coexist with a native engine or other implementations.

## Start here

Free architecture experiment with no sale, subscription or commercial activation. Existing source licence restrictions remain in force. Architecture alpha with a source CLI and a loopback engine slice. Desktop/mobile source foundations do not constitute released VPN, TUN or system-wide network clients.

[Installation, first use, privacy, backup and recovery](docs/USER-GUIDE.md) · [简体中文](docs/USER-GUIDE.zh-CN.md)

## What works today

- Canonical Relay Profile JSON with validation and round-trip serialization
- Surge-compatible import for `DOMAIN`, `DOMAIN-SUFFIX`, `IP-CIDR`, `IP-CIDR6`, `GEOIP`, `FINAL`, and `MATCH` syntax
- Deterministic local evaluation for exact domain, suffix, IPv4 CIDR, and final rules
- Select/fallback policy groups with cycle detection and stable selection
- `DecisionTrace`: rule source, policy resolution, selected outbound, steps, warnings, and stable trace ID
- Xray adapter slice for VLESS + RAW/TLS/REALITY, SOCKS ingress, `freedom`/`blackhole`, ordered routes, rule tags, source maps, canonical JSON, and SHA-256 identity
- Agent-first CLI (`validate` / `decide` / `compile` / `dry-run` / `import-surge` / `diagnose` / `version`): canonical JSON, exit codes that never lie, byte-level golden contract ([CLI-SPEC](docs/CLI-SPEC.md))
- Supervised Xray process runtime: pinned binary discovery, version query, `run -test` config validation, session start/stop lifecycle, bounded structured event bridge, and a real loopback SOCKS request through a local test endpoint
- Rivet RPC boundary for route explanation, engine compilation, dry runs, and engine session lifecycle
- Atomic local-folder storage boundary; provider-specific sync remains outside the profile model
- Typed `DiagnosticBundle`, secret redaction, and preconditioned `ConfigPatch`
- 58 passing Racket tests with the pinned engine (42 without it; engine tests skip with a printed reason), plus a 20-case golden CLI suite
- CI: checksum-pinned Xray v26.3.27, release-identity and notice-pin checks, golden suite, and real engine session tests

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
    ↓ supervised engine runtime (pinned Xray process)
Validate (`run -test`) · loopback SOCKS session · structured events
```

The same RelayPilot evaluator that explains a route is the source of the adapter plan. Unsupported local semantics are rejected at compilation instead of silently delegating truth to an engine. Every engine artifact identifies its adapter version, engine pin, deterministic digest, and source map; the runtime adds bounded execution evidence without ever rewriting the artifact.

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
python3 shared/cli-golden/runner.py --binary scripts/relaypilot-cli.sh
```

With the pinned engine configured (`RELAYPILOT_XRAY_BIN=/path/to/xray`), the test suite additionally runs config validation and a real loopback SOCKS session through a supervised Xray process; without it, those tests skip with a printed reason.

The CLI is the executable slice (full contract in [docs/CLI-SPEC.md](docs/CLI-SPEC.md)):

```bash
scripts/relaypilot-cli.sh version
scripts/relaypilot-cli.sh validate examples/relay-profile.json
scripts/relaypilot-cli.sh decide examples/relay-profile.json --domain api.openai.com --port 443
scripts/relaypilot-cli.sh dry-run examples/relay-profile.json
scripts/relaypilot-cli.sh compile examples/relay-profile.json --out /tmp/xray.json
```

## Repository layout

```text
relaypilot/
├── rivet.rktd                 # Rivet application contract
├── app/backend.rkt            # typed native-host RPC boundary
├── app/cli.rkt                # agent-facing CLI (docs/CLI-SPEC.md)
├── app/core/
│   ├── profile/               # canonical Relay Profile
│   ├── rules/                 # Surge syntax + deterministic evaluator
│   ├── policy/                # group selection
│   ├── engines/               # adapter contract, Xray compiler, supervised runtime
│   ├── diagnostics/           # DecisionTrace bundles
│   ├── storage/               # local-first provider boundary
│   └── ai/                    # redaction + typed ConfigPatch
├── shared/cli-golden/         # byte-level CLI golden contract
├── tests/                     # domain, adapter, runtime and RPC contract tests
├── examples/                  # synthetic, non-secret profile and rules
├── scripts/                   # CLI launchers, release/notice checks
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
