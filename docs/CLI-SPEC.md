# RelayPilot CLI contract

The CLI is the agent-facing executable surface of the profile → DecisionTrace
→ adapter dry-run slice. It is implemented once, in `app/cli.rkt`; the
`scripts/relaypilot-cli.sh` (POSIX) and `scripts/relaypilot-cli.cmd` (Windows)
launchers run it with the system Racket. Every behavior change lands here
first, then in `shared/cli-golden/` (`--record` re-run, diff reviewed), then
in the implementation.

## Output rules

- **stdout carries exactly one canonical JSON value** per successful
  invocation: sorted keys, no whitespace, UTF-8, newline-terminated. The
  envelope always contains `"ok":true` plus the command's result fields.
- **stderr carries exactly one canonical JSON error object** on failure:
  `{"error":<message>,"exitCode":N,"kind":"<kind>","ok":false}`. `kind` is one
  of `validation`, `usage`, `engine`.
- **Exit codes never lie**: `0` ok · `1` invalid input (bad profile, bad flag
  value, engine-rejected input data) · `2` usage (unknown command, missing or
  extra arguments, `-h/--help/help` prints the usage text to stderr) ·
  `3` engine failure (the engine binary rejected or could not run the
  artifact).
- **Determinism**: identical argv + files produce byte-identical stdout,
  stderr and exit code. Traces, digests and source maps are derived
  (SHA-256), never sampled; no wall-clock timestamps appear in output.
- Input files may be `-` (stdin) where a profile or rules path is expected.

## Commands

### `relaypilot version`

`{"build":1,"channel":"alpha","identifier":"…","name":"RelayPilot","ok":true,"version":"…"}` —
identity mirrors `rivet.rktd`; `scripts/check-release-version.sh` enforces the
agreement.

### `relaypilot validate <profile.json>`

`{"nodes":N,"ok":true,"policies":N,"profileId":"…","rules":N,"schemaVersion":1}`.
Structural or semantic profile errors are `validation` failures with the
precise diagnostic in `error`.

### `relaypilot decide <profile.json> [--domain D] [--ip I] [--port P] [--network tcp|udp] [--source-app S]`

At least one of `--domain`/`--ip` is required (otherwise `usage`). `--port`
defaults to `0`, `--network` to `tcp`. Returns:

```json
{"flow":{"domain":…,"ip":…,"network":"tcp","port":443,"sourceApp":…},
 "ok":true,
 "trace":{"matchedKind":…,"matchedValue":…,"outbound":…,"policy":…,
          "profileId":…,"ruleIndex":N,"ruleSource":…,"steps":[…],
          "traceId":"<16 hex>","warnings":[…]}}
```

Absent flow facts are `null`, never inferred. A profile without a matching
rule (no FINAL/MATCH) is a `validation` failure.

### `relaypilot compile <profile.json> [--out PATH] [--socks-port N]`

Compiles the frozen engine artifact. `--socks-port` defaults to `1080` and is
part of the artifact (recorded in the `inbound` field, so it changes the
SHA-256 honestly). With `--out`, the canonical config bytes are written
atomically to `PATH` and the envelope carries `"writtenTo"` instead of
`"config"`.

### `relaypilot dry-run <profile.json> [--socks-port N] [--binary PATH]`

compile + engine validation. When no engine binary is configured (env
`RELAYPILOT_XRAY_BIN`, then `xray` on `PATH`; `--binary` overrides and must
exist), the envelope reports `"engine":{"available":false,…,"validated":false}`
and exits `0` — the compile-only dry run is honest about what did not run.
When the engine rejects the artifact, the command fails with `engine`/exit 3
and the bounded engine output in `error`. Golden cases cover only the
no-engine path (byte-stable everywhere); the real-engine path is covered by
`tests/runtime.rkt` under CI's pinned binary.

### `relaypilot import-surge <rules.list> --id ID [--name NAME]`

Parses Surge rule lines into a profile skeleton (`nodes`, `policies` empty).
Syntax errors are precise `validation` failures. Referenced policies that the
skeleton cannot resolve are reported in `"unresolvedPolicies"` (exit `0`) —
never silently dropped.

### `relaypilot diagnose <profile.json> [flow flags]`

Emits a redacted `DiagnosticBundle` (schema 1): connection, decision,
engine events (empty in the CLI slice), comparable failures. Secret material
from profile node credentials/TLS (strings ≥ 8 chars) is replaced with
`[REDACTED]` before output; the envelope states `"redacted":true`.

## Golden suite

`python3 shared/cli-golden/runner.py --binary scripts/relaypilot-cli.sh`
verifies byte-identical stdout/stderr/exit for every case in
`shared/cli-golden/cases.json`; `--record` re-records after a reviewed spec
change. The runner strips `RELAYPILOT_XRAY_BIN` (engine path stays outside
the golden contract) and normalizes `{{repo}}`, `{{work}}`, `{{version}}` and
the OS errno detail after `system error:`.
