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

                        Text("版本 1.1 (Build 2026.0528)")
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
                    LinkButton(title: "开源许可证 (MIT)", systemImage: "doc.text") {
                        if let url = URL(string: "https://opensource.org/licenses/MIT") {
                            NSWorkspace.shared.open(url)
                        }
                    }

                    LinkButton(title: "GitHub 开源仓库", systemImage: "network") {
                        if let url = URL(string: "https://github.com") {
                            NSWorkspace.shared.open(url)
                        }
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
