# Mdora

[![Release](https://img.shields.io/github/v/release/Gurara-nya/Mdora?label=Latest)](https://github.com/Gurara-nya/Mdora/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-blue.svg)](https://www.apple.com/macos)

**Current public version:** `1.0.6` · **Channel:** Public · **Default language:** English / 中文

<div align="center">

Mdora is a native macOS Markdown workspace: distraction-free, local-first, with live edit + live preview.

Mdora 是一款原生 macOS Markdown 编辑器：本地优先、无干扰、边写边看。

</div>

---

## Quick Links / 快速入口

- [Download latest release](https://github.com/Gurara-nya/Mdora/releases/latest)
- [Release note (v1.0.6)](release-notes/v1.0.6.md)
- [Release notes / 发布说明](CHANGELOG.md)
- [Source repository / 源码仓库](https://github.com/Gurara-nya/Mdora)
- [Issues / 反馈](https://github.com/Gurara-nya/Mdora/issues)

---

## Showcase / 展示

### What to try now / 可以先体验的功能
- Typora-like editor + split preview sync.
- Extended task marker support in editor and parser.
- Inspector, diagnostics, and metadata panels.
- Lightweight diagram / math / table rendering pipeline.
- Local image and wiki-link resolving.

### 现在可体验的亮点
- 编辑器与预览分栏联动。
- 任务列表支持扩展状态（warning/blocked/review/idea/success 等）。
- Inspector 面板、诊断信息、元数据/Front Matter 支持。
- Mermaid/PlantUML/Flowchart 等图表与数学块的本地预览。
- 本地图片、wiki 链接和导出链路支持。

---

## Features / 核心特性

### English

- Native macOS app using SwiftUI + `DocumentGroup`
- Editor / Split / Preview modes
- Accurate block/inline markdown parsing
- Source-map sync between editor and preview
- Shared pipeline for preview, export, diagnostics
- Shared syntax model for task lists and task token aliases
- Performance controls for large documents
- HTML export and local-first file workflow for `.md`, `.markdown`, `.mdown`

### 中文

- 原生 macOS 实现（SwiftUI + `DocumentGroup`）
- 编辑 / 分屏 / 预览模式
- 完整的块级与内联解析
- 源码映射驱动的编辑器与预览联动
- 解析链路统一用于预览、导出、诊断
- 扩展任务标记模型与识别支持
- 大文档下性能控制项
- 本地优先文件工作流，支持 `.md`、`.markdown`、`.mdown`

---

## Download / 下载

### From GitHub Release / 从 GitHub 下载

- **v1.0.6（Public） Mac app bundle (zip):**
  https://github.com/Gurara-nya/Mdora/releases/download/v1.0.6/Mdora-1.0.6-macOS.zip

### Build from Source / 源码构建

```sh
swift build
swift run Mdora
```

---

## Release 1.0.6 / 发布说明

### English

- Release channel: public
- Main focus: compatibility robustness and UI motion/performance control for public usage.
- Key improvements:
  - Added `Reduce Motion` and adaptive fallback toggles in Settings/About for more stable interaction on large documents.
  - Improved editor highlighting schedule and preview pulse throttling to avoid repeated expensive work on large files.
  - Expanded task token compatibility aliases (hyphens, underscores, and locale-friendly variants) for broader task-state recognition.
- Added public-facing performance status feedback for large-document degradation mode and kept compatibility/publish metadata in sync.

### 中文

- 发布通道：公开发布（Public）
- 核心目标：公开可用版的兼容性补齐与长文档下动画/渲染性能控制
- 关键更新：
  - 新增“减少动画”与性能降级联动设置，提升超大文档交互顺滑性
  - 改进编辑器高亮调度与预览脉冲刷新策略，减少长文档下的卡顿与重复计算
  - 扩展任务标记兼容别名（连字符、下划线与本地化语义变体），提高任务状态识别兼容率
  - 增加长文档性能降级场景的公开提示信息，并对齐发布素材与打包版本数据。

---

## License / 许可证

MIT
