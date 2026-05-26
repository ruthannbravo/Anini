import SwiftUI

struct TypingIndicator: View {
    @State private var active: Int = 0
    private let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.primary.opacity(active == i ? 0.6 : 0.22))
                    .frame(width: 7, height: 7)
                    .offset(y: active == i ? -4 : 0)
                    .animation(.easeInOut(duration: 0.22), value: active)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onReceive(timer) { _ in
            active = (active + 1) % 3
        }
    }
}

struct MessageBubble: View {
    let message: Message
    @ObservedObject private var config = WorkspaceConfig.shared

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                if let path = message.imagePath, let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                        .onTapGesture {
                            NSWorkspace.shared.open(URL(fileURLWithPath: path))
                        }
                        .help("Click to open full size")
                }
                if !message.content.isEmpty {
                    Text(linkedText(message.content))
                        .font(.system(size: 14))
                        .foregroundStyle(message.role == .user ? .white : .primary)
                        .tint(message.role == .user ? .white.opacity(0.85) : config.accentColor)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            message.role == .user
                                ? AnyShapeStyle(config.accentColor.opacity(0.85))
                                : AnyShapeStyle(Color.primary.opacity(0.06))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if message.isStreaming {
                    TypingIndicator()
                }
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private func linkedText(_ string: String) -> AttributedString {
        var attributed = AttributedString(string)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return attributed
        }
        let matches = detector.matches(in: string, range: NSRange(string.startIndex..., in: string))
        for match in matches.reversed() {
            guard let url = match.url,
                  let strRange = Range(match.range, in: string),
                  let attrRange = Range(strRange, in: attributed) else { continue }
            attributed[attrRange].link = url
            attributed[attrRange].underlineStyle = .single
        }
        return attributed
    }
}
