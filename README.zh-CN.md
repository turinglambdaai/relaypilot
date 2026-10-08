# RelayPilot

一套 Profile，覆盖每一台设备。RelayPilot 是面向 macOS、Windows、Linux、iPhone、iPad、Android 和 Apple TV 的 local-first 原生网络工具箱：一套 Racket 控制平面，各平台第一方原生 UI，同样的网络决策与解释体验。

[English](README.md) · **中文** · [架构](ARCHITECTURE.md) · [路线图](ROADMAP.md)

RelayPilot 不是“Xray GUI”。Profile、规则、策略组选择、DNS 意图、连接记录、`DecisionTrace`、诊断、同步边界和 AI 的 typed patch 都属于 RelayPilot。Xray/libXray 只是第一个可替换的协议引擎。

## 当前已经实现

- Canonical Relay Profile JSON：校验与稳定往返序列化
- Surge 兼容规则导入：`DOMAIN`、`DOMAIN-SUFFIX`、`IP-CIDR`、`IP-CIDR6`、`GEOIP`、`FINAL`、`MATCH`
- `DOMAIN`、`DOMAIN-SUFFIX`、IPv4 CIDR、最终规则的本地确定性求值
- select/fallback 策略组、显式选择、循环检测
- `DecisionTrace`：规则来源、策略解析、最终 outbound、步骤、告警、稳定 trace ID
- 第一段 Xray adapter：VLESS + RAW/TLS/REALITY、SOCKS ingress、`freedom`/`blackhole`、有序路由、rule tag、source map、canonical JSON、SHA-256
- 原子写入的本地文件夹 storage 边界
- typed `DiagnosticBundle`、脱敏和带前置条件的 `ConfigPatch`
- 给各平台原生 UI 使用的 Rivet typed RPC
- 初始实现本地 40 项 Racket 测试通过，包含 RVT1 往返验证

仓库目前**还不是可运行 VPN 客户端**：尚未集成 TUN、未打包 Xray/libXray、没有原生界面、后台服务、订阅、生产 DNS 或商业系统。

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
    ↓ 下一里程碑
固定版本的 libXray / Xray runtime
```

解释路由和生成 engine plan 使用同一套 RelayPilot 语义。尚未本地实现的规则不会悄悄交给 Xray 得出另一套答案，而是在编译边界明确拒绝。

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

## 开发

需要 Racket CS 9.x 和 [Rivet](https://github.com/turinglambdaai/rivet)：

```bash
raco pkg install --auto --no-docs rivet
raco make app/backend.rkt
raco test tests/
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
