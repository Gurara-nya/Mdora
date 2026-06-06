# Mdora

[![Release](https://img.shields.io/github/v/release/Gurara-nya/Mdora?label=Latest)](https://github.com/Gurara-nya/Mdora/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-blue.svg)](https://www.apple.com/macos)

**Current public version:** `1.0.0` · **Default language:** English / 中文

<div align="center">

Mdora is a native macOS Markdown workspace: distraction-free, local-first, and designed for live-write + live-preview workflows.

Mdora 是一款原生 macOS Markdown 编辑器：本地优先、无干扰、支持“边写边看”。

</div>

---

## Quick Links / 快速入口

- [Download latest release](https://github.com/Gurara-nya/Mdora/releases/latest)
- [Release notes / 发布说明](CHANGELOG.md)
- [Source repository / 源码仓库](https://github.com/Gurara-nya/Mdora)

---

## English

### What is Mdora?

Mdora is a Typora-inspired Markdown editor for macOS, currently focused on a fast and reliable local-first editing experience. It supports rich block-level parsing, precise syntax behavior, synchronized preview, and practical document tooling without requiring cloud accounts.

### Highlights

- Native macOS app using SwiftUI + `DocumentGroup`
- Editor / Split / Preview modes
- Deep Markdown syntax and live inline/block parsing
- Inspector panel for metadata, tags, front matter, links, references, diagnostics
- Native task list interaction (including extended task states)
- Local-first file workflow for `.md`, `.markdown`, `.mdown`
- HTML export
- Lightweight diagram preview (Mermaid/Graphviz/PlantUML/sequence/flowchart)
- Theme support for writing and reading comfort
- Local image rendering and path-aware wiki image embedding

### Features (1.0.0)

- CommonMark and GFM-compatible block parsing
- CommonMark headings, lists, tasks, tables, links, front matter
- Markdown Extra support: definitions, callouts, diagrams, math, footnotes
- Shared parser pipeline for preview and export
- Smart list handling and editing behaviors (indentation, continuation, return, tab)
- Source-map based preview sync and error diagnostics
- Bounded parsing cache for smoother large-document performance
- Built-in status bar for doc metrics and editor states

### Run / Build

```sh
swift run Mdora
swift build
```

### Download this release package (1.0.0)

To download the packaged app directly:

- **Mac app bundle (zip):** https://github.com/Gurara-nya/Mdora/releases/download/v1.0.0/Mdora-1.0.0-macOS.zip

---

## 中文

### 什么是 Mdora？

Mdora 是一款类 Typora 风格的 macOS Markdown 编辑器，当前版本聚焦于本地优先、稳定可用的写作体验。它支持丰富的块级解析、严格的语法行为、同步预览和实用文档能力，不依赖任何云账号。

### 亮点

- 原生 macOS 实现（SwiftUI + `DocumentGroup`）
- 编辑 / 分屏 / 预览三种模式
- 深度 Markdown 语法与实时解析
- 右侧侧边栏（Inspector）展示元数据、标签、Front Matter、链接、引用与诊断信息
- 本地任务列表交互，支持扩展状态
- 本地优先文件协作：支持 `.md`、`.markdown`、`.mdown`
- HTML 导出
- 内建 Mermaid / Graphviz / PlantUML / Sequence / Flowchart 轻量图形预览
- 提供多套阅读/书写主题
- 本地图片路径解析与 wiki 图片内嵌展示

### 1.0.0 功能

- 支持 CommonMark / GFM 兼容块解析
- 标题、列表、任务、表格、链接、Front Matter 全链路处理
- Markdown Extra 能力：定义列表、callout、图表、数学公式、脚注
- 解析器共享输出用于预览与导出
- 智能列表编辑（缩进、续行、回车、Tab）
- 基于源码映射的预览联动与错误诊断
- 大文档下限幅缓存以保证性能稳定
- 内建状态栏显示字数、字符、行数、光标与诊断计数

### 运行与构建

```sh
swift run Mdora
swift build
```

### 下载当前发布包（1.0.0）

直接下载可运行 app 包：

- **Mac 应用压缩包（zip）：** https://github.com/Gurara-nya/Mdora/releases/download/v1.0.0/Mdora-1.0.0-macOS.zip

---

## Release 1.0.0 Notes

- Public beta release with native document workflow, live preview, syntax-rich parser, inspector insights, and app packaging.
- Version: `1.0.0`
- Public release date: `2026-06-07`
- Full changelog: [CHANGELOG.md](CHANGELOG.md)

## License

MIT
