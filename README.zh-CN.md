# RelayPilot

一套 Profile，覆盖每一台设备。RelayPilot 是面向 macOS、Windows、Linux、iPhone、iPad、Android 和 Apple TV 的 local-first 原生网络工具箱：一套 Racket 控制平面，各平台第一方原生 UI，同样的网络决策与解释体验。

[![CI](https://github.com/turinglambdaai/relaypilot/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/relaypilot/actions/workflows/ci.yml) ![built with](https://img.shields.io/badge/built%20with-Rivet-9333ea) ![license](https://img.shields.io/badge/license-Proprietary-red) ![stage](https://img.shields.io/badge/stage-architecture%20alpha-C15F3C)

[English](README.md) · **中文** · 🌐 [relaypilot.jrtx.site](https://relaypilot.jrtx.site)


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

## 构建与测试

需要 Racket CS 9.x 和 [Rivet](https://github.com/turinglambdaai/rivet)：

```bash
raco pkg install --auto --no-docs rivet
raco make app/backend.rkt
raco test tests/
```

通过 RPC 边界编译仓库自带的非保密示例：

```bash
racket -e '(require "app/core/profile/json.rkt" "app/core/engines/xray.rkt") (compile-xray-config (read-relay-profile (string->path "examples/relay-profile.json")))'
```

如需写出产物检查：

```bash
racket scripts/compile-profile.rkt examples/relay-profile.json /tmp/xray.json
```

## 仓库结构

```text
relaypilot/
├── rivet.rktd                 # Rivet 应用契约
├── app/backend.rkt            # 面向原生 host 的 typed RPC 边界
├── app/core/
│   ├── profile/               # canonical Relay Profile
│   ├── rules/                 # Surge 语法 + 确定性求值器
│   ├── policy/                # 策略组选择
│   ├── engines/               # adapter 契约 + Xray 编译器
│   ├── diagnostics/           # DecisionTrace 诊断包
│   ├── storage/               # local-first 存储边界
│   └── ai/                    # 脱敏 + typed ConfigPatch
├── tests/                     # 领域与 adapter 契约测试
├── examples/                  # 合成的非保密 profile 与规则
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
