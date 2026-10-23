# RelayPilot agent contract

## Authorization decision before implementation

Decision `2026-10-auth-1`: No commercial Permit credentials, Commerce checkout or licensing account. Read the complete [local authorization decision](PRICING.md#authorization-decision-for-implementation) and its Chinese counterpart before commercial, trial, update-eligibility or credential work. Record this decision revision and the source/policy SHAs actually read in the PR/handoff. Refresh at each bounded slice; existing agent conversations do not receive this change automatically. Follow the existing product contract and implementation issue; do not activate a payment gate merely because a plan exists.

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
python3 shared/cli-golden/runner.py --binary scripts/relaypilot-cli.sh
scripts/check-release-version.sh
racket scripts/third-party-notices.rkt --check
```

With `RELAYPILOT_XRAY_BIN` pointing at the pinned Xray binary, `raco test tests/` additionally runs config validation and a real loopback SOCKS session through a supervised engine process; without it those tests skip with a printed reason — a skip is not a pass.

Runtime/host changes need an end-to-end test on their target OS. Apple native validation belongs on macOS CI; do not claim it from Windows.

## CLI contract

- The CLI is implemented once in `app/cli.rkt`; launchers are thin shims (`scripts/relaypilot-cli.sh` / `.cmd`). Do not add a second implementation path.
- Behavior changes land in `docs/CLI-SPEC.md` first, then re-record `shared/cli-golden/` with `--record` and review the diff; never edit golden bytes by hand and never delete a case to get green.
- Engine-dependent golden behavior is intentionally out of the golden contract; the runner strips `RELAYPILOT_XRAY_BIN`.


## 产品交付与下一步（2026-10-23）

- 家族[交付标准](https://github.com/turinglambdaai/turinglambdaai.github.io/blob/master/docs/PRODUCT-STANDARD.md)与[组合策略](https://github.com/turinglambdaai/turinglambdaai.github.io/blob/master/PORTFOLIO.md)是共用政策；本仓具体行为以 `ROADMAP.md` 为准，不复制五库依赖图。
- 当前执行入口：[产品审查 issue](https://github.com/turinglambdaai/relaypilot/issues/1)。保留架构 Alpha，暂不销售。profile→DecisionTrace→adapter dry-run→诊断的可执行纵切已于 2026-10-23 交付（CLI + golden 契约 + 受监督 Xray runtime + 回环 SOCKS 实测）；下一个切片在 M2 桌面宿主路径与实际网络接管评审切片之间认领，一次只做一个。
- 开工先检查干净工作树与远端，以 fast-forward-only 更新并记录 SHA；共享文件一次一个写入者，保留其他 checkout 的未提交工作。
- 每次只完成一个可验收切片，记录 owned files、依赖 pin、命令/平台/产物证据和回滚。已实现、已发布、实机验收分别陈述；不修改 requirements 或复用旧证据来制造通过。

## 组合定位（Portfolio placement）

- 当前决策（2026-10-v2）：实验冻结；不收费。具体价格、免费/付费边界和开卖门禁以本仓 [PRICING.md](PRICING.md) 为唯一权威；旧版收费候选与早鸟方案已被替代。
- 组合归属：[PORTFOLIO](https://github.com/turinglambdaai/turinglambdaai.github.io/blob/master/PORTFOLIO.md)。当前全部产品开发中、没有实际用户；目标定价不表示已经开卖，不因此立即给开发版加收费墙。
- 免费产品不接商业激活；付费层先实现可验证价值，再接 Commerce/Permit。优先完成本仓既有产品审查 issue；不修改现行源码 LICENSE。

## Documentation languages

Public default documentation is English; maintain complete Chinese user paths in `*.zh-CN.md`, with reciprocal links. Update both languages when prices, quotas, installation, recovery, privacy or supported platforms change. API/protocol identifiers and commands remain unchanged; do not maintain a second normative protocol or implementation. Follow the [family language policy](https://github.com/turinglambdaai/turinglambdaai.github.io/blob/master/docs/DOCUMENTATION-LANGUAGES.md). Existing internal notes are not a claim that every document is bilingual.
