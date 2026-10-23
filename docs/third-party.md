# Third-party engine provenance

RelayPilot does not currently redistribute an engine binary in any release. CI and local verification download one official Xray release to validate generated configuration (`run -test`) and to drive supervised test sessions against loopback endpoints — with synthetic credentials only.

## Xray pin

- Project: [XTLS/Xray-core](https://github.com/XTLS/Xray-core)
- Version: `v26.3.27`
- License: MPL-2.0
- Linux x64 asset: `Xray-linux-64.zip` — SHA-256 `23cd9af937744d97776ee35ecad4972cf4b2109d1e0fe6be9930467608f7c8ae` (CI)
- macOS arm64 asset: `Xray-macos-arm64-v8a.zip` — SHA-256 `2e93a67e8aa1936ecefb307e120830fcbd4c643ab9b1c46a2d0838d5f8409eaf` (local verification)
- Windows x64 asset: `Xray-windows-64.zip` — SHA-256 `d004c39288ce9ada487c6f398c7c545f7d749e44bdfdd59dbc9f865afba4e1ad` (initial local boundary check)

These digests are also exposed by the corresponding GitHub release asset metadata. Updating the pin requires reviewing the current Xray configuration contract, changing the digest in CI **and** in `scripts/third-party-notices.rkt`, and passing the adapter tests, the loopback session test, and `xray run -test`.

The future application runtime is expected to use [XTLS/libXray](https://github.com/XTLS/libXray), which is MIT-licensed and warns that its API is not stable. That runtime is not pinned or redistributed yet.

## Notices and source-offer workflow

When a future bundle ships an engine binary, it must carry the generated NOTICE text and a written source offer:

- `racket scripts/third-party-notices.rkt` prints the NOTICE text for every pinned component; the output ships verbatim as `NOTICE` inside the bundle.
- `racket scripts/third-party-notices.rkt --check` verifies `docs/third-party.md` still carries the pinned version and license; it is part of the pre-release checklist next to `scripts/check-release-version.sh`.
- Bundles ship unmodified upstream archives; the SHA-256 pin above is the source-offer reference. RelayPilot never patches engine source, so the offer points at the upstream release.
- Credentials stay synthetic in CI: no test profile, log, or golden fixture contains real server addresses, UUIDs, or keys.
