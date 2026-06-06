import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isHoveringLogo = false
    @State private var animateCredits = false

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

    private func openURLOrFallback(_ value: String) {
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
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
