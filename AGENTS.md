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


## 产品交付与下一步（2026-10-23）

- 家族[交付标准](https://github.com/turinglambdaai/turinglambdaai.github.io/blob/master/docs/PRODUCT-STANDARD.md)与[组合策略](https://github.com/turinglambdaai/turinglambdaai.github.io/blob/master/PORTFOLIO.md)是共用政策；本仓具体行为以 `ROADMAP.md` 为准，不复制五库依赖图。
- 当前执行入口：[产品审查 issue](https://github.com/turinglambdaai/relaypilot/issues/1)。保留架构 Alpha，暂不销售；下一步仅限 profile→DecisionTrace→adapter dry-run 的可执行纵切，不把目标平台写成已支持。
- 开工先检查干净工作树与远端，以 fast-forward-only 更新并记录 SHA；共享文件一次一个写入者，保留其他 checkout 的未提交工作。
- 每次只完成一个可验收切片，记录 owned files、依赖 pin、命令/平台/产物证据和回滚。已实现、已发布、实机验收分别陈述；不修改 requirements 或复用旧证据来制造通过。

## 组合定位（Portfolio placement）

- 当前决策（2026-10-v2）：实验冻结；不收费。具体价格、免费/付费边界和开卖门禁以本仓 [PRICING.md](PRICING.md) 为唯一权威；旧版收费候选与早鸟方案已被替代。
- 组合归属：[PORTFOLIO](https://github.com/turinglambdaai/turinglambdaai.github.io/blob/master/PORTFOLIO.md)。当前全部产品开发中、没有实际用户；目标定价不表示已经开卖，不因此立即给开发版加收费墙。
- 免费产品不接商业激活；付费层先实现可验证价值，再接 Commerce/Permit。优先完成本仓既有产品审查 issue；不修改现行源码 LICENSE。
