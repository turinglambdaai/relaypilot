# Third-party engine provenance

RelayPilot does not currently redistribute an engine binary. CI downloads one official Xray release only to validate generated configuration in `run -test` mode.

## Xray validation pin

- Project: [XTLS/Xray-core](https://github.com/XTLS/Xray-core)
- Version: `v26.3.27`
- License: MPL-2.0
- Linux x64 asset: `Xray-linux-64.zip`
- Linux x64 SHA-256: `23cd9af937744d97776ee35ecad4972cf4b2109d1e0fe6be9930467608f7c8ae`
- Windows x64 asset used for the initial local boundary check: `Xray-windows-64.zip`
- Windows x64 SHA-256: `d004c39288ce9ada487c6f398c7c545f7d749e44bdfdd59dbc9f865afba4e1ad`

These digests are also exposed by the corresponding GitHub release asset metadata. Updating the pin requires reviewing the current Xray configuration contract, changing the digest in CI, and passing adapter tests plus `xray run -test`.

The future application runtime is expected to use [XTLS/libXray](https://github.com/XTLS/libXray), which is MIT-licensed and warns that its API is not stable. That runtime is not pinned or redistributed yet.

