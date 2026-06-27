# Clash Verge Rev 技术栈与代理架构分析

> 会话时间: 2026-06-27 15:06
> 项目: clash-verge-dev (Clash Verge Rev)
> 分支: dev-tools

---

## 目录

- [Clash Verge Rev 技术栈与代理架构分析](#clash-verge-rev-技术栈与代理架构分析)
  - [目录](#目录)
  - [1. Rust 语言简介](#1-rust-语言简介)
  - [2. 项目技术栈总览](#2-项目技术栈总览)
    - [整体架构](#整体架构)
    - [各层技术选型](#各层技术选型)
    - [Rust 工作空间 Crates](#rust-工作空间-crates)
  - [3. Tauri vs Electron 对比](#3-tauri-vs-electron-对比)
    - [核心差异一览](#核心差异一览)
    - [Tauri 的优点](#tauri-的优点)
    - [Tauri 的缺点](#tauri-的缺点)
    - [为什么 clash-verge 选择 Tauri？](#为什么-clash-verge-选择-tauri)
  - [4. Flutter vs Tauri vs Electron 三方对比](#4-flutter-vs-tauri-vs-electron-三方对比)
    - [架构差异](#架构差异)
    - [全维度对比](#全维度对比)
    - [决策矩阵](#决策矩阵)
    - [为什么 clash-verge 选 Tauri？](#为什么-clash-verge-选-tauri)
  - [5. 代理体系调用链分析](#5-代理体系调用链分析)
    - [5.1 系统代理模式](#51-系统代理模式)
      - [调用链](#调用链)
      - [代理守卫](#代理守卫)
    - [5.2 PAC 模式](#52-pac-模式)
    - [5.3 TUN 模式](#53-tun-模式)
      - [调用链](#调用链-1)
      - [安全机制](#安全机制)
      - [默认 TUN 配置](#默认-tun-配置)
    - [5.4 Mihomo 路由模式](#54-mihomo-路由模式)
  - [6. 全局架构总图](#6-全局架构总图)
    - [三种代理方式本质区别](#三种代理方式本质区别)
  - [7. 关键文件索引](#7-关键文件索引)
    - [前端核心文件 (TypeScript/React)](#前端核心文件-typescriptreact)
    - [Rust 后端核心文件](#rust-后端核心文件)
    - [核心依赖 Crates](#核心依赖-crates)

---

## 1. Rust 语言简介

`.rs` 扩展名的文件是 **Rust** 语言的源代码文件。Rust 是一种系统级编程语言，由 Mozilla 开发，注重内存安全、并发性和性能。

- `.rs` — Rust 源代码文件
- `.rlib` — Rust 编译后的库文件

在本项目中，Rust 代码位于 `src-tauri/` 目录下，用于处理后端/系统层的逻辑。

---

## 2. 项目技术栈总览

### 整体架构

```
┌──────────────────────────────────────────┐
│  React 19 + TypeScript 6 + Vite 8        │  ← 前端
│  MUI v9 + Emotion + SCSS                 │
│  TanStack React Query v5 + Context       │
├──────────────────────────────────────────┤
│  Tauri 2.11 (Rust 2024 edition)           │  ← 桥接层
│  @tauri-apps/api invoke()                │
├──────────────────────────────────────────┤
│  Rust 后端                                │  ← 系统层
│  Warp HTTP Server / Boa JS Engine        │
│  Mihomo 内核 (sidecar)                   │
│  WebDAV / 系统代理 / TUN / 备份          │
└──────────────────────────────────────────┘
```

### 各层技术选型

| 层级 | 技术选型 |
|------|----------|
| **前端框架** | React 19 + TypeScript 6 |
| **构建工具** | Vite 8（Terser 压缩） |
| **UI 组件库** | MUI (Material UI) v9 + Emotion CSS-in-JS |
| **状态管理** | TanStack React Query v5（服务端状态）+ React Context（共享数据）+ foxact（轻量全局状态） |
| **代码编辑器** | Monaco Editor + monaco-yaml（YAML/配置编辑） |
| **拖拽** | @dnd-kit（导航排序） |
| **国际化** | i18next + react-i18next |
| **桌面框架** | **Tauri 2.11** (Rust 2024 edition) |
| **Rust 依赖** | tokio (异步), warp (HTTP), boa_engine (JS 脚本), reqwest (HTTP 客户端), serde_yaml 等 |
| **代理内核** | Mihomo (Clash.Meta)，通过 sidecar 方式集成 |
| **包管理器** | pnpm 11 |

### Rust 工作空间 Crates

| Crate | 路径 | 用途 |
|-------|------|------|
| `clash-verge-draft` | `crates/clash-verge-draft` | 配置草稿系统 |
| `clash-verge-logging` | `crates/clash-verge-logging` | 日志系统 |
| `clash-verge-signal` | `crates/clash-verge-signal` | 信号处理 |
| `clash-verge-i18n` | `crates/clash-verge-i18n` | 国际化 |
| `clash-verge-limiter` | `crates/clash-verge-limiter` | 限流器 |
| `tauri-plugin-clash-verge-sysinfo` | `crates/tauri-plugin-clash-verge-sysinfo` | 系统信息插件 |

---

## 3. Tauri vs Electron 对比

### 核心差异一览

| 维度 | Tauri 2 | Electron |
|------|---------|----------|
| **后端语言** | **Rust** | Node.js (JavaScript/TypeScript) |
| **WebView 引擎** | 系统原生 WebView（Linux: WebKitGTK, macOS: WKWebView, Windows: WebView2） | 内置 Chromium（打包在应用中） |
| **安装包体积** | 🟢 **极小**（通常 3-10 MB） | 🔴 大（通常 60-150 MB+） |
| **内存占用** | 🟢 **低**（Rust 无 GC，WebView 共享系统资源） | 🔴 高（独立 Chromium 实例 + V8 GC） |
| **启动速度** | 🟢 **快**（原生二进制） | 🟡 较慢（需加载 Chromium + Node） |
| **安全性** | 🟢 **强**（Rust 内存安全保证，最小权限能力模型） | 🟡 中等（Node.js 全权限，需手动 sandbox） |
| **前端一致性** | 🟡 依赖系统 WebView（各平台渲染可能差异） | 🟢 **完全一致**（统一 Chromium 版本） |
| **Node.js 生态** | ❌ 不可直接用（需通过 Rust 桥接或 sidecar） | 🟢 **完整支持** |

### Tauri 的优点

1. **安装包极小** — 复用系统 WebView，不内置浏览器。对工具类应用下载体验优势巨大。
2. **内存和性能优异** — Rust 无 GC，内存控制精确；系统 WebView 由所有应用共享。
3. **安全模型更优** — Tauri 2 采用基于能力 (capability-based) 的权限模型，Rust 语言本身的内存安全保证。
4. **Rust 生态的系统编程能力** — 系统代理设置 (`sysproxy`)、TUN 虚拟网卡操作、底层网络操作等有天然优势。
5. **启动速度快** — 原生 Rust 二进制，无需启动 Node.js 运行时和 Chromium。

### Tauri 的缺点

1. **WebView 兼容性风险** — 不同操作系统的 WebView 实现不同，可能存在 CSS/JS 行为差异。
2. **Node.js 生态不可直接使用** — 需要用 Rust 重写后端逻辑或通过 sidecar 间接集成。
3. **Rust 学习曲线陡峭** — 团队需要掌握 Rust，招聘难度更大。
4. **生态成熟度** — Tauri 2 相对年轻（2024 年稳定），部分场景可能缺少现成的插件。
5. **打包复杂度** — 需要 Rust 编译链 + 系统 WebView 依赖。

### 为什么 clash-verge 选择 Tauri？

代理工具对安装包体积、内存占用、系统集成能力都有较高要求，这些恰好是 Tauri + Rust 的核心优势所在。

---

## 4. Flutter vs Tauri vs Electron 三方对比

### 架构差异

```
Electron                     Tauri                        Flutter
┌──────────────┐            ┌──────────────┐            ┌──────────────┐
│  HTML/CSS/JS │            │  HTML/CSS/JS │            │  Dart Widget │
│   (你的 UI)   │            │   (你的 UI)   │            │  (Skia 绘制)  │
├──────────────┤            ├──────────────┤            ├──────────────┤
│  Chromium    │            │  系统 WebView  │            │  Flutter     │
│  (内置完整浏览器)│            │  (操作系统提供) │            │  Engine      │
├──────────────┤            ├──────────────┤            │  (C/C++)     │
│  Node.js     │            │  Rust 桥接     │            ├──────────────┤
│  (后端逻辑)   │            │  (后端逻辑)    │            │  Dart Runtime│
└──────────────┘            └──────────────┘            │  (前后端统一)  │
                                                        └──────────────┘
```

### 全维度对比

| 维度 | Electron | Tauri | Flutter |
|------|------|------|------|
| **渲染引擎** | Chromium（浏览器） | 系统 WebView（浏览器） | **Skia + Impeller**（自绘引擎） |
| **后端语言** | Node.js (JS/TS) | **Rust** | **Dart**（与 UI 同语言） |
| **安装包体积** | 🔴 60-150 MB+ | 🟢 **3-10 MB** | 🟡 15-30 MB |
| **内存占用(空应用)** | 🔴 ~200-300 MB | 🟢 **~20-50 MB** | 🟡 ~50-100 MB |
| **启动速度** | 🔴 慢 (3-10s+) | 🟢 **最快 (<1s)** | 🟡 中 (1-3s) |
| **UI 一致性** | 🟢 统一 Chromium | 🟡 依赖系统 WebView | 🟢 **像素级一致** |
| **原生 UI 体验** | 🔴 Web 感强 | 🔴 Web 感强 | 🟢 **接近原生** |
| **跨平台范围** | 🟡 桌面 | 🟡 桌面 + 移动(实验) | 🟢 **全平台** |
| **系统集成能力** | 🟡 中 | 🟢 **最强 (Rust FFI)** | 🟡 中 |
| **语言统一性** | 🟢 JS/TS 全栈 | 🔴 前端 JS + 后端 Rust | 🟢 **Dart 全栈** |
| **热重载** | 🟢 HMR | 🟢 HMR | 🟢 **Hot Reload (亚秒级)** |
| **学习曲线** | 🟢 低 | 🔴 高 (需 Rust) | 🟡 中 |
| **生态丰富度** | 🟢 npm (200万+ 包) | 🔴 Rust crates (较少) | 🟡 pub.dev (5万+) |
| **桌面端成熟度** | 🟢 **极成熟** | 🟡 快速成长 | 🟡 桌面仍在追赶 |

### 决策矩阵

| 你的需求 | 推荐 |
|------|------|
| 安装包越小越好、内存越低越好 | **Tauri** |
| 需要同时发布移动端 (iOS/Android) | **Flutter** |
| 像素级 UI 一致性 + 复杂动画 | **Flutter** |
| 团队是前端/Web 开发者 | **Electron** |
| 团队是移动端开发者 | **Flutter** |
| 需要深度系统级操作（网络代理、驱动、TUN） | **Tauri** |
| 60fps 列表、自定义绘制、复杂手势 | **Flutter** |
| 社区资源最多、遇到问题最容易搜到答案 | **Electron** |
| 对安全性要求高、面向终端用户 | **Tauri** |
| 快速从 Web 项目迁移为桌面应用 | **Electron / Tauri** |

### 为什么 clash-verge 选 Tauri？

- ❌ **Electron**：安装包大、内存高、代理工具用户对资源占用敏感。
- ❌ **Flutter**：没有移动端需求，系统代理/TUN/网卡操作在 Dart 层表达不便，需要大量 Platform Channel。
- ✅ **Tauri**：安装包小、内存低、Rust 直接操作系统代理和网络层。

---

## 5. 代理体系调用链分析

本项目有两层独立的"模式"：

| 层级 | 控制什么 | 可选值 |
|------|---------|--------|
| **核心部署模式** (RunningMode) | Mihomo 进程以什么权限运行 | `Service`（特权服务）/ `Sidecar`（普通子进程） |
| **流量拦截模式** | 流量如何被引导到 Mihomo 核心 | 系统代理 / PAC / TUN |

TUN 需要创建虚拟网卡，因此**强制要求**核心以 `Service` 模式运行。

### 5.1 系统代理模式

最常用的模式：让操作系统把所有 HTTP/HTTPS/SOCKS 流量指向 Mihomo 的监听端口。

#### 调用链

```
 用户点击 [系统代理] 开关
         │
    ┌────┴────┐
    │  前端层   │
    └────┬────┘
         │ ProxyControlSwitches.tsx          SwitchRow onToggle → toggleSystemProxy(value)
         │ use-system-proxy-state.ts         乐观UI更新 + patchVerge({ enable_system_proxy: target })
         │ use-verge.ts                      patchVerge → patchVergeConfig(value)
         │ cmds.ts                           invoke('patch_verge_config', { payload })
         │
  ═══════╪═══════ Tauri IPC 桥 ═══════════════════════════════════════════
         │
    ┌────┴────┐
    │  Rust层  │
    └────┬────┘
         │ feat/config.rs: patch_verge()
         │   ├─ determine_update_flags() → SYS_PROXY 标志
         │   └─ process_terminated_flags()
         │        └─ Sysopt::global().update_sysproxy()
         │
         │ core/sysopt.rs: update_sysproxy()
         │   1. 读取配置: enable_system_proxy, proxy_auto_config, proxy_host, port, bypass
         │   2. 确定子模式: 关闭 | PAC模式 | 全局代理(默认)
         │   3. proxy_apply_steps() 按顺序执行
         │      (Windows先清PAC再设全局, 解决WinINET冲突)
         │   4. tokio::spawn_blocking → 调用OS API
         │
         │ sysproxy crate (OS原生API)
         │   ├─ Windows:  WinHTTP / WinINET
         │   ├─ macOS:    SCDynamicStore
         │   └─ Linux:    gsettings (GNOME) / kwriteconfig (KDE)
         │
         ▼
    操作系统代理已设置: 127.0.0.1:7897
```

#### 代理守卫

如果 `enable_proxy_guard = true`，后台定时器会每隔 N 秒重新调用 `set_system_proxy()`，防止其他软件篡改代理设置。

### 5.2 PAC 模式

PAC 是系统代理的**子模式** — 在 `enable_system_proxy = true` 的前提下，用 PAC URL 代替固定的代理地址。

```
 系统代理已开启 + proxy_auto_config = true
         │
         │ 应用内置 PAC 服务器 (warp) 监听 127.0.0.1:33331
         │ 端点: /commands/pac → 返回 PAC 文件内容
         │
         │ PAC 文件模板:
         │   function FindProxyForURL(url, host) {
         │     return "PROXY 127.0.0.1:7897; SOCKS5 127.0.0.1:7897; DIRECT;";
         │   }
         │
         │ sysopt.rs: update_sysproxy()
         │   auto.enable = true
         │   auto.url = "http://127.0.0.1:33331/commands/pac"
         │   ↓
         │ sysproxy::Autoproxy::set_auto_proxy()
         │   ├─ Windows: 注册表设置 AutoConfigURL
         │   ├─ macOS:   网络偏好设置 PAC URL
         │   └─ Linux:   gsettings set org.gnome.system.proxy autoconfig-url
```

PAC 的优势：浏览器/应用可以按 URL 规则决定走代理还是直连，而不是全局全走代理。

### 5.3 TUN 模式

TUN 模式在 OS 网络栈层面创建一个**虚拟网卡**，所有系统流量（包括不遵循系统代理的应用）都会被捕获并路由到 Mihomo。

#### 调用链

```
 用户点击 [TUN模式] 开关
         │
    ┌────┴────┐
    │  前端层   │
    └────┬────┘
         │ ProxyControlSwitches.tsx          handleTunToggle(value)
         │   ├─ isTunModeAvailable?         需要 isAdmin || isServiceOk
         │   └─ patchVerge({ enable_tun_mode: value })
         │ cmds.ts                           invoke('patch_verge_config', { payload })
         │
  ═══════╪═══════ Tauri IPC 桥 ═══════════════════════════════════════════
         │
    ┌────┴────┐
    │  Rust层  │ (两部分: 配置标志处理 + 配置生成管道)
    └────┬────┘
         │
         │ feat/config.rs: patch_verge()
         │   ├─ determine_update_flags()
         │   │    tun_mode 变化 → CLASH_CONFIG | GROUP_SYS_TRAY
         │   │    (Linux: 额外加 RESTART_CORE)
         │   │
         │   └─ process_terminated_flags()
         │        CLASH_CONFIG → CoreManager::update_config_checked()
         │        GROUP_SYS_TRAY → 更新托盘图标/菜单
         │
         │ CoreManager::update_config_checked()
         │   └─ perform_config_update()
         │        └─ Config::generate()  ←── 完整的配置生成管道
         │
         │ enhance/mod.rs: enhance() 管道:
         │   profile config
         │     → global merge + script
         │     → profile rules/proxies/groups/merge/script
         │     → merge_default_config()    ← 合并 clash.yaml 端口/tun
         │     → apply_builtin_scripts()
         │     → cleanup_proxy_groups()
         │     → use_tun(config, enable_tun) ★ 关键步骤
         │     → use_sort()
         │     → apply_dns_settings()
         │
         │ enhance/tun.rs: use_tun(config, enable)
         │   tun.enable = true 时:
         │     ├─ 从运行时配置中提取 tun 块 (stack/mtu/dns-hijack/...)
         │     ├─ 强制开启 DNS:  dns.enable = true
         │     ├─ 设置 fake-ip:  enhanced-mode: fake-ip, fake-ip-range: 198.18.0.1/16
         │     ├─ macOS: 系统DNS → 114.114.114.114
         │     └─ tun.enable = true
         │
         │ CoreManager::apply_config(path)
         │   ├─ 写入 runtime YAML 文件
         │   └─ Handle::mihomo().reload_config(path)
         │        └─ HTTP PUT /configs → Mihomo API
         │
         │ (若需重启核心)
         │ CoreManager::restart_core()
         │   ├─ lifecycle.rs: start_core()
         │   │     └─ 检测 enable_tun_mode → 等待 Service 就绪
         │   └─ 以 sidecar 子进程或 service 方式启动 mihomo
         │
         ▼
    Mihomo 核心创建 TUN 虚拟网卡，接管系统所有流量
```

#### 安全机制

`use-system-state.ts` 持续监控 — 如果 TUN 处于开启状态但 `isTunModeAvailable` 变为 false（例如服务崩溃），会**自动禁用 TUN**，防止用户失去网络连接。

#### 默认 TUN 配置

```yaml
tun:
  enable: false
  stack: gvisor          # gvisor / mixed / system
  auto-route: true
  strict-route: false
  auto-detect-interface: true
  dns-hijack: ["any:53"]
```

### 5.4 Mihomo 路由模式

与流量拦截模式**正交** — 控制流量到达 Mihomo 后，Mihomo **内部如何路由**：

```
 代理页面 ButtonGroup: [Rule] [Global] [Direct]
         │
         │ onChangeMode(mode)
         │ patchClashMode(mode) → invoke('patch_clash_mode', { payload })
         │
  ═══════╪═══════ IPC ═══════
         │
         │ feat/clash.rs: change_clash_mode(mode)
         │   ├─ PUT /configs { mode: "rule"|"global"|"direct" } → Mihomo API
         │   ├─ 更新持久化的 clash 配置文件
         │   ├─ handle::Handle::refresh_clash() → 刷新前端
         │   └─ 若 auto_close_connection → 关闭所有现有连接(强制重路由)
```

| 模式 | 行为 |
|------|------|
| **Rule** | 按 rules 列表逐条匹配，命中则走对应 proxy-group，不命中走默认 |
| **Global** | 所有流量走 GLOBAL 代理组选中的节点 |
| **Direct** | 所有流量直连，绕过所有代理 |

---

## 6. 全局架构总图

```
┌─────────────────────────────────────────────────────────────┐
│                     用户界面 (React)                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ 系统代理开关   │  │  TUN 开关     │  │ Rule/Global/     │  │
│  │ + PAC子模式   │  │  + TUN设置    │  │ Direct 路由模式   │  │
│  └──────┬───────┘  └──────┬───────┘  └───────┬──────────┘  │
│         │                 │                   │              │
│   ┌─────┴────────┬────────┴──────────┬────────┴─────────┐   │
│   │              │  Tauri IPC        │                   │   │
│   │ patch_verge  │  patch_verge      │ patch_clash_mode  │   │
│   │ _config      │  _config          │                   │   │
│   └─────┬────────┴────────┬──────────┴────────┬─────────┘   │
├─────────┼─────────────────┼───────────────────┼─────────────┤
│         │        Rust 后端                  │                │
│         │                                  │                │
│   ┌─────▼──────────┐   ┌──────────────┐   ┌▼────────────┐  │
│   │ feat/config.rs │   │ feat/config.rs│   │feat/clash.rs│  │
│   │ determine_     │   │ determine_    │   │ change_     │  │
│   │ update_flags() │   │ update_flags()│   │ clash_mode()│  │
│   │ SYS_PROXY      │   │ CLASH_CONFIG  │   │             │  │
│   └─────┬──────────┘   └──────┬───────┘   └─────┬───────┘  │
│         │                      │                  │          │
│   ┌─────▼──────────┐   ┌──────▼──────────┐       │          │
│   │ core/sysopt.rs │   │ enhance/mod.rs  │       │          │
│   │ update_        │   │ enhance()管道   │       │          │
│   │ sysproxy()     │   │  → use_tun()   │       │          │
│   └─────┬──────────┘   └──────┬──────────┘       │          │
│         │                      │                  │          │
│   ┌─────▼──────────┐   ┌──────▼──────────┐       │          │
│   │ sysproxy crate │   │ CoreManager     │       │          │
│   │ (OS 原生 API)   │   │ apply_config()  │       │          │
│   │ WinHTTP/       │   │ → PUT /configs  │       │          │
│   │ SCDynamicStore/│   │                 │       │          │
│   │ gsettings      │   └──────┬──────────┘       │          │
│   └───────────────┘          │                   │          │
│                              ▼                   │          │
│                       ┌──────────┐               │          │
│                       │ Mihomo   │◄──────────────┘          │
│                       │ 核心进程  │                           │
│                       │ (sidecar │                           │
│                       │  或      │                           │
│                       │  service)│                           │
│                       └──────────┘                           │
└─────────────────────────────────────────────────────────────┘
```

### 三种代理方式本质区别

| | 系统代理 | PAC 模式 | TUN 模式 |
|------|------|------|------|
| **实现层级** | 应用层 (OS 代理设置) | 应用层 (PAC URL) | **网络栈层 (虚拟网卡)** |
| **是否需要管理员** | 否 | 否 | **是** (需要 Service 模式) |
| **覆盖范围** | 遵循系统代理的应用 | 遵循系统代理的应用 | **所有流量** |
| **核心机制** | `sysproxy` crate 调 OS API | 内置 warp HTTP 服务器提供 PAC 文件 | Mihomo 内核创建 TUN 虚拟设备 |
| **DNS 处理** | 不干预 | 不干预 | 强制 fake-ip (198.18.0.1/16) |
| **调用链长度** | 短 (UI→Rust→OS API) | 短 (UI→Rust→OS API + PAC Server) | 长 (UI→Rust→配置管道→重启核心→Mihomo) |

---

## 7. 关键文件索引

### 前端核心文件 (TypeScript/React)

| 文件 | 用途 |
|------|------|
| `src/hooks/use-system-proxy-state.ts` | 系统代理状态管理与防抖切换 |
| `src/hooks/use-system-state.ts` | TUN 可用性监控与自动禁用 |
| `src/components/shared/proxy-control-switches.tsx` | 系统代理/TUN 统一切换组件 |
| `src/components/home/proxy-tun-card.tsx` | 主页代理/TUN 标签卡片 |
| `src/components/setting/mods/sysproxy-viewer.tsx` | 系统代理高级设置(PAC/绕过/守卫) |
| `src/components/setting/mods/tun-viewer.tsx` | TUN 参数设置(stack/MTU/DNS劫持) |
| `src/pages/proxies.tsx` | Rule/Global/Direct 路由模式切换 |
| `src/services/cmds.ts` | 前端 invoke 桥接层 |
| `src/hooks/use-verge.ts` | Verge 配置存取 Hook |
| `src/hooks/use-clash.ts` | Clash 运行时配置存取 Hook |
| `src/providers/app-data-provider.tsx` | 全局上下文提供者 |
| `src/providers/app-data-context.ts` | 上下文类型定义 |

### Rust 后端核心文件

| 文件 | 用途 |
|------|------|
| `src-tauri/src/feat/config.rs` | `patch_verge()`、`determine_update_flags()`、标志副作用执行 |
| `src-tauri/src/core/sysopt.rs` | `update_sysproxy()`、`reset_sysproxy()`、代理守卫 |
| `src-tauri/src/enhance/mod.rs` | 完整 Mihomo 配置生成管道 |
| `src-tauri/src/enhance/tun.rs` | `use_tun()` — TUN 配置注入 + DNS 自动配置 |
| `src-tauri/src/feat/clash.rs` | `change_clash_mode()` Rule/Global/Direct 切换 |
| `src-tauri/src/feat/proxy.rs` | `toggle_system_proxy()`、`toggle_tun_mode()` |
| `src-tauri/src/core/manager/config.rs` | 配置应用、Mihomo API 通信 |
| `src-tauri/src/core/manager/lifecycle.rs` | 核心启动/停止/Service等待 |
| `src-tauri/src/core/manager/mod.rs` | RunningMode 枚举定义 |
| `src-tauri/src/core/service.rs` | 系统服务管理(安装/卸载/状态) |
| `src-tauri/src/config/verge.rs` | `IVerge` 配置结构定义 |
| `src-tauri/src/config/clash.rs` | `IClashTemp` 模板(默认TUN配置等) |
| `src-tauri/src/config/runtime.rs` | `IRuntime` 运行时配置补丁 |
| `src-tauri/src/feat/window.rs` | 退出清理(重置代理、禁用TUN) |
| `src-tauri/src/core/tray/mod.rs` | 系统托盘菜单系统代理/TUN切换 |
| `src-tauri/src/core/hotkey.rs` | 全局热键(切换系统代理/TUN) |
| `src-tauri/src/cmd/network.rs` | `get_sys_proxy`、`get_auto_proxy` 命令 |
| `src-tauri/src/cmd/verge.rs` | `get_verge_config`、`patch_verge_config` 命令 |
| `src-tauri/src/cmd/clash.rs` | `patch_clash_mode`、`patch_clash_config` 命令 |
| `src-tauri/src/cmd/system.rs` | `get_running_mode` 命令 |
| `src-tauri/src/lib.rs` | Tauri 命令注册 |

### 核心依赖 Crates

| Crate | 用途 |
|-------|------|
| `sysproxy` (git: clash-verge-rev) | 跨平台系统代理/PAC 设置 |
| `tauri-plugin-mihomo` (git: clash-verge-rev) | Mihomo 核心 IPC 通信 |
| `clash_verge_service_ipc` (git) | 系统服务模式 IPC 通信 |
| `warp` | 内置 HTTP 服务器 (PAC 文件等) |
| `boa_engine` | JavaScript 引擎 (运行规则脚本) |
| `reqwest_dav` | WebDAV 远程备份 |

---

> 本文档由 Claude Code 自动生成，基于 2026-06-27 会话内容整理。
