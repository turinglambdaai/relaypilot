# RelayPilot

RelayPilot 是统一网络配置与可解释路由的架构 Alpha。目前提供 Racket 源码 CLI 和受监督的回环引擎纵切；规划中的原生宿主尚不是已发布客户端。

[![CI](https://github.com/turinglambdaai/relaypilot/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/relaypilot/actions/workflows/ci.yml) ![built with](https://img.shields.io/badge/built%20with-Rivet-9333ea) ![license](https://img.shields.io/badge/license-Proprietary-red) ![stage](https://img.shields.io/badge/stage-architecture%20alpha-C15F3C)

[English](README.md) · **中文** · 🌐 [relaypilot.jrtx.site](https://relaypilot.jrtx.site/)

RelayPilot 不是“Xray GUI”。Profile、规则、策略组选择、DNS 意图、连接记录、`DecisionTrace`、诊断、同步边界和 AI 的 typed patch 都属于 RelayPilot。Xray/libXray 只是第一个可替换的协议引擎。

## 开始使用

免费架构实验，不销售、不订阅、不接商业激活；现行源码许可限制仍然有效。 架构 Alpha，已有源码 CLI 与回环引擎纵切。桌面或移动源码基础不等于已发布的 VPN、TUN 或系统全局网络客户端。

[安装、首次使用、隐私与备份恢复](docs/USER-GUIDE.zh-CN.md) · [English](docs/USER-GUIDE.md)

## 当前已经实现

- Canonical Relay Profile JSON：校验与稳定往返序列化
- Surge 兼容规则导入：`DOMAIN`、`DOMAIN-SUFFIX`、`IP-CIDR`、`IP-CIDR6`、`GEOIP`、`FINAL`、`MATCH`
- `DOMAIN`、`DOMAIN-SUFFIX`、IPv4 CIDR、最终规则的本地确定性求值
- select/fallback 策略组、显式选择、循环检测
- `DecisionTrace`：规则来源、策略解析、最终 outbound、步骤、告警、稳定 trace ID
- 第一段 Xray adapter：VLESS + RAW/TLS/REALITY、SOCKS ingress、`freedom`/`blackhole`、有序路由、rule tag、source map、canonical JSON、SHA-256
- Agent-first CLI（`validate` / `decide` / `compile` / `dry-run` / `import-surge` / `diagnose` / `version`）：canonical JSON、退出码从不说谎、字节级 golden 契约（[CLI-SPEC](docs/CLI-SPEC.md)）
- 受监督的 Xray 进程 runtime：pin 版本二进制发现、版本查询、`run -test` 配置验证、会话启动/停止生命周期、有界结构化事件桥，以及穿过本地测试端点的真实回环 SOCKS 请求
- 面向原生 host 的 Rivet typed RPC：路由解释、引擎编译、dry-run、引擎会话生命周期
- 原子写入的本地文件夹 storage 边界
- typed `DiagnosticBundle`、脱敏和带前置条件的 `ConfigPatch`
- 固定引擎就位时 58 项 Racket 测试通过（无引擎时 42 项通过，引擎测试打印原因后跳过），另有 20 例 golden CLI 套件
- CI：SHA-256 固定的 Xray v26.3.27、发布身份与 notice pin 检查、golden 套件、真实引擎会话测试

仓库目前**还不是可运行 VPN 客户端**：尚未集成 TUN、未打包 Xray/libXray、没有原生界面、后台服务、订阅、生产 DNS 或商业系统。下一步见[路线图](ROADMAP.md)，控制平面设计见[架构](ARCHITECTURE.md)。

## 第一条纵向链路

```text
Relay Profile
    ↓ 校验
Surge 兼容规则
    ↓ first-match 求值
策略组选择
    ↓ 确定性 DecisionTrace
EnginePlan + source map
    ↓ Xray adapter
canonical Xray JSON + SHA-256
    ↓ 受监督引擎 runtime（pin 版本 Xray 进程）
配置验证（run -test）· 回环 SOCKS 会话 · 结构化事件
```

解释路由和生成 engine plan 使用同一套 RelayPilot 语义。尚未本地实现的规则不会悄悄交给 Xray 得出另一套答案，而是在编译边界明确拒绝。每个引擎工件都标注 adapter 版本、引擎 pin、确定性摘要与 source map；runtime 只补充有界的执行证据，从不改写工件。

## 平台状态

| 平台 | 原生 UI 目标 | 当前状态 |
|---|---|---|
| macOS | SwiftUI/AppKit + Rivet | host 尚未开始；控制平面边界已就绪 |
| Windows | WinUI 3 + Rivet | host 尚未开始；控制平面边界已就绪 |
| Linux | GTK4 + Rivet | host 尚未开始；Rivet 路线成熟度更低 |
| iOS / iPadOS | SwiftUI + NetworkExtension | 仅架构；不宣称 Rivet 已支持 |
| tvOS | SwiftUI + NetworkExtension | 仅架构；libXray cgo 可行性不等于产品已构建 |
| Android | Jetpack Compose + VpnService | 仅架构；不宣称 Rivet 已支持 |

精确边界见 [平台成熟度](docs/platform-maturity.md)。

## 构建与测试

需要 Racket CS 9.x 和 [Rivet](https://github.com/turinglambdaai/rivet)：

```bash
raco pkg install --auto --no-docs rivet
raco make app/backend.rkt
raco test tests/
python3 shared/cli-golden/runner.py --binary scripts/relaypilot-cli.sh
```

配置固定引擎（`RELAYPILOT_XRAY_BIN=/path/to/xray`）后，测试套件会额外运行配置验证和穿过受监督 Xray 进程的真实回环 SOCKS 会话；未配置时这些测试打印原因后跳过。

CLI 是当前可执行的纵向链路（完整契约见 [docs/CLI-SPEC.md](docs/CLI-SPEC.md)）：

```bash
scripts/relaypilot-cli.sh version
scripts/relaypilot-cli.sh validate examples/relay-profile.json
scripts/relaypilot-cli.sh decide examples/relay-profile.json --domain api.openai.com --port 443
scripts/relaypilot-cli.sh dry-run examples/relay-profile.json
scripts/relaypilot-cli.sh compile examples/relay-profile.json --out /tmp/xray.json
```

## 仓库结构

```text
relaypilot/
├── rivet.rktd                 # Rivet 应用契约
├── app/backend.rkt            # 面向原生 host 的 typed RPC 边界
├── app/cli.rkt                # agent-facing CLI（docs/CLI-SPEC.md）
├── app/core/
│   ├── profile/               # canonical Relay Profile
│   ├── rules/                 # Surge 语法 + 确定性求值器
│   ├── policy/                # 策略组选择
│   ├── engines/               # adapter 契约 + Xray 编译器 + 受监督 runtime
│   ├── diagnostics/           # DecisionTrace 诊断包
│   ├── storage/               # local-first 存储边界
│   └── ai/                    # 脱敏 + typed ConfigPatch
├── shared/cli-golden/         # CLI 字节级 golden 契约
├── tests/                     # 领域、adapter、runtime 与 RPC 契约测试
├── examples/                  # 合成的非保密 profile 与规则
├── scripts/                   # CLI 启动器、发布身份与 notice 检查
├── macos-host/ windows/ linux/# 第一方桌面 host（计划中）
├── apple/ android/            # 移动/TV 隧道 host（计划中）
├── docs/                      # 产品与工程契约
└── site/                      # 静态产品站
```

## 产品约束

- local-first：当前不需要账号、License server、自建云或必须依赖的服务器。
- 用户自有同步：Apple 平台优先 iCloud Drive；跨平台使用本地文件夹、WebDAV 等 provider。
- 每个平台都是真原生 UI；Rivet 承载 typed application logic，不引入跨平台 UI DSL。
- AI 只能解释或提出可校验 typed patch，不能直接修改运行配置。
- 协议引擎是可替换基础设施，RelayPilot 语义必须留在本仓库。

商业系统现在不实现。方向是“买断当前功能世代 + 可选付费功能更新”，定价低于 Surge。

## 许可证

Copyright © 2026 turinglambdaai。当前尚未授予开源许可证。未来分发第三方 engine 时将分别履行 notice 和源码提供义务。
