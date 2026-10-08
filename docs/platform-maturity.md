# Platform maturity

This table describes RelayPilot, not theoretical engine portability.

| Platform | Rivet / application base | Native host | Tunnel boundary | Engine runtime | Product claim |
|---|---|---|---|---|---|
| macOS | suitable desktop foundation | not started | not started | libXray build path exists upstream | architecture alpha |
| Windows | suitable desktop foundation | not started | not started | libXray/Xray build path exists upstream | architecture alpha |
| Linux | available but less mature | not started | not started | libXray/Xray build path exists upstream | architecture alpha |
| iOS/iPadOS | no RelayPilot integration yet | not started | not started | upstream Apple build path exists | research only |
| tvOS | no RelayPilot integration yet | not started | not started | upstream cgo build path exists | research only |
| Android | no RelayPilot integration yet | not started | not started | upstream AAR build path exists | research only |

An upstream build target is not evidence that RelayPilot handles lifecycle, NetworkExtension/VpnService rules, background execution, store policy, DNS, sleep/wake, network changes, or release signing.

