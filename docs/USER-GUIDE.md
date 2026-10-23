# RelayPilot user guide

**English** · [简体中文](USER-GUIDE.zh-CN.md)

Explore canonical network profiles, deterministic routing decisions and supervised engine adapters.

## Availability

Free architecture experiment with no sale, subscription or commercial activation. Existing source licence restrictions remain in force.

## Platforms and installation

Architecture alpha with a source CLI and a loopback engine slice. Desktop/mobile source foundations do not constitute released VPN, TUN or system-wide network clients.

See the [README](../README.md) for source installation and execution; release assets do not constitute a deployed service.

## Your first successful session

1. Use synthetic profiles and the documented CLI workflow; validate before evaluating a route.
2. Inspect DecisionTrace and adapter dry-run output before running a pinned engine.
3. Keep tests on a disposable loopback setup; do not import real subscriptions or make it your system network path.

## Data, backup and recovery

Preserve profile sources and engine/version/digest evidence. Diagnostic traces can contain destinations and credentials; use redacted synthetic fixtures in reports. Keep a known-good network configuration outside this experiment.

## Network, keys and privacy

A configured engine can make real network connections even when the control model is local. No anonymous browsing, traffic security, VPN protection or service availability guarantee is made.

## Known limits

No public release assets currently exist. Platform maturity and actual network takeover remain explicit gates; do not interpret planned platforms as supported products.

## Upgrading and stopping use

Back up configuration/data and identify the source and dependency versions. Validate in isolation before replacing the version in use. Stop the process before removing local data; content and credentials at external services must be managed or revoked there separately.

## Get help

Report problems in [GitHub Issues](https://github.com/turinglambdaai/relaypilot/issues), in English or Chinese. Include the version, OS/architecture, installation channel, steps, expected result and actual result. Reproduce with synthetic input first; do not attach keys, credentials, databases, private source documents or complete logs. Public support has no guaranteed response time.

## Further reading

- [Platform maturity](../docs/platform-maturity.md)
- [CLI contract](../docs/CLI-SPEC.md)
- [Engine boundary](../docs/engines.md)
- [Project overview and development](../README.md)
- [Current licence](../README.md#license)
