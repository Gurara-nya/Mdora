import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringLogo = false
    @State private var animateCredits = false
    @AppStorage("mdoraTheme") private var themeName = MdoraTheme.system.rawValue
    @AppStorage("mdoraPerformanceMode") private var performanceMode = false
    @AppStorage("previewAnimations") private var previewAnimations = true
    @AppStorage("mdoraReduceMotion") private var reduceMotion = false

    private var selectedTheme: MdoraTheme {
        MdoraTheme(rawValue: themeName) ?? .system
    }

    var body: some View {
        VStack(spacing: 0) {
            // Glassmorphic / Gradient Top Header
            ZStack {
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.18),
                        Color.purple.opacity(0.12),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 16) {
                    // Geometric App Logo with premium gradients
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.cyan, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.blue.opacity(0.4), radius: 10, x: 0, y: 6)
                            .scaleEffect(isHoveringLogo ? 1.08 : 1.0)
                            .rotationEffect(.degrees(isHoveringLogo ? 12 : 0))
                            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isHoveringLogo)

                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 2)
                    }
                    .onHover { hovering in
                        isHoveringLogo = hovering
                    }
                    .padding(.top, 28)

                    VStack(spacing: 4) {
                        Text("Mdora")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("版本 \(appVersionText)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 180)

            // Description & Credits
            VStack(spacing: 20) {
                Text("Mdora 是一款受 Typora 启发的 Markdown 写作空间：本地优先、清爽无干扰，致力于打造“所见即所得”的极简实时预览编辑体验。")
                    .font(.subheadline)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary.opacity(0.85))
                    .padding(.horizontal, 24)

                Text("当前支持 macOS 原生文档、分屏编辑、实时预览和多语法兼容识别（任务标记、Wiki 链接、图表、数学、审阅标记）。")
                    .font(.caption)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text("2.0 特性快照")
                        .font(.headline)
                    AboutBadgeRow(
                        title: "版本与主题",
                        detail: "\(appVersionText) · 当前主题 \(selectedTheme.title)"
                    )
                    AboutBadgeRow(
                        title: "兼容语法",
                        detail: "\(TaskState.allCases.count) 种任务状态 · \(TaskTokenKind.allCases.count) 种令牌类型 · 任务/图表/公式"
                    )
                    AboutBadgeRow(
                        title: "性能策略",
                        detail: "\(performanceMode ? "高性能模式" : "标准模式")，\(reduceMotion ? "低动画" : "平滑动画")"
                    )
                    AboutBadgeRow(
                        title: "发布状态",
                        detail: "公开发布版本，可在 Releases 获取安装包与更新说明。"
                    )
                }
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 6) {
                    Label("2.0 路线：性能优先、兼容增强、体验打磨", systemImage: "sparkles")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Text("已开启大文档性能模式：动画阈值、表格和图片资源会按阈值降级，图谱与长公式在超大规模场景下支持折叠与按需渲染。")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("标识兼容升级：任务状态支持 todo / warning / blocked / review / idea / success / inProgress / done 等多种写法，解析、编辑高亮与导出链路保持一致。")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                CompatibilityBadgeRow(
                    performanceEnabled: performanceMode,
                    animationsEnabled: previewAnimations,
                    statusText: statusText
                )
                .padding(.horizontal, 24)

                Divider()
                    .padding(.horizontal, 40)

                // Credit Section with premium hover effect
                VStack(spacing: 8) {
                    Text("Antigravity AI 倾心设计与制作 ❤️")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .scaleEffect(animateCredits ? 1.05 : 1.0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                                    animateCredits = true
                            }
                        }

                    Text("基于原生 SwiftUI 与 AppKit 框架精心构建。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Link buttons
                HStack(spacing: 16) {
                    LinkButton(title: "开源许可", systemImage: "doc.text") {
                        openURLOrFallback("https://github.com/Gurara-nya/Mdora/blob/main/LICENSE")
                    }

                    LinkButton(title: "GitHub 仓库", systemImage: "network") {
                        openURLOrFallback("https://github.com/Gurara-nya/Mdora")
                    }

                    LinkButton(title: "最新发布", systemImage: "tag.fill") {
                        openURLOrFallback("https://github.com/Gurara-nya/Mdora/releases/latest")
                    }

                    LinkButton(title: "问题反馈", systemImage: "bubble.left.and.exclamationmark.bubble.right") {
                        openURLOrFallback("https://github.com/Gurara-nya/Mdora/issues")
                    }

                    LinkButton(title: "兼容说明", systemImage: "checklist") {
                        openURLOrFallback("https://github.com/Gurara-nya/Mdora/blob/main/CHANGELOG.md")
                    }
                }
                .padding(.top, 8)

                Spacer()

                // Bottom Close button
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.regular)
                .padding(.bottom, 20)
            }
            .padding(.top, 10)
        }
        .frame(width: 420, height: 460)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "dev"
        return "\(version) (Build \(build))"
    }

    private var statusText: String {
        let mode = performanceMode ? "高性能预览（自动降级）" : "标准模式"
        return "\(mode)，动画 \(previewAnimations ? "已开启" : "已关闭")"
    }

    private func openURLOrFallback(_ value: String) {
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct CompatibilityBadgeRow: View {
    let performanceEnabled: Bool
    let animationsEnabled: Bool
    let statusText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("兼容运行状态")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(statusText)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("解析栈：Markdown 标准 + Mdora 2.0 扩展标识（任务标记 / Wiki / 图表 / 数学 / 审阅块）")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct AboutBadgeRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.primary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// Glassmorphic helper view
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Link button style helper
struct LinkButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovering ? Color.blue.opacity(0.12) : Color.clear)
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovering ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
