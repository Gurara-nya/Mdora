# Mdora

[![Release](https://img.shields.io/github/v/release/Gurara-nya/Mdora?label=Latest)](https://github.com/Gurara-nya/Mdora/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-blue.svg)](https://www.apple.com/macos)

**Current public version:** `1.0.2` · **Channel:** Public · **Default language:** English / 中文

<div align="center">

Mdora is a native macOS Markdown workspace: distraction-free, local-first, with live edit + live preview.

Mdora 是一款原生 macOS Markdown 编辑器：本地优先、无干扰、边写边看。

</div>

---

## Quick Links / 快速入口

- [Download latest release](https://github.com/Gurara-nya/Mdora/releases/latest)
- [Release note (v1.0.2)](release-notes/v1.0.2.md)
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

- **v1.0.2（Public） Mac app bundle (zip):**
  https://github.com/Gurara-nya/Mdora/releases/download/v1.0.2/Mdora-1.0.2-macOS.zip

### Build from Source / 源码构建

```sh
swift build
swift run Mdora
```

---

## Release 1.0.2 / 发布说明

### English

- Release channel: public
- Main focus: release-readiness consistency and task-state compatibility
- Key improvements:
  - Extended task state and token marker compatibility
  - Consistent parsing behavior for parser/analyzer/editor paths
  - Updated release metadata and README references

### 中文

- 发布通道：公开发布（Public）
- 核心目标：发布准备一致性和任务状态兼容性
- 关键更新：
  - 扩展任务状态和任务标记兼容性增强
  - 解析器 / 分析器 / 编辑器任务处理行为保持一致
  - 同步更新 README、发布文案与仓库信息

---

## License / 许可证

MIT
