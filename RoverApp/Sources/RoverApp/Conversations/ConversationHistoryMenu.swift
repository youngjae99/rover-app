import SwiftUI
import AppKit

/// XP / Luna era flat menu (`Menu with Decorators` template). 184pt wide,
/// white background, 1px #ACA899 border, drop shadow, Tahoma 11. Selection
/// row paints solid #316AC5 with white text on hover.
struct ConversationHistoryMenu: View {
    let conversations: [Conversation]
    var onNew: () -> Void
    var onSelect: (Conversation) -> Void

    private static let xpBorder = Color(red: 172.0/255.0, green: 168.0/255.0, blue: 153.0/255.0)
    private static let xpSelection = Color(red: 49.0/255.0, green: 106.0/255.0, blue: 197.0/255.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HistoryRow(
                label: "New conversation",
                leadingSymbol: "plus",
                action: onNew
            )

            HistoryRowSeparator()

            if conversations.isEmpty {
                HistoryRow(
                    label: "(No past conversations)",
                    leadingSymbol: nil,
                    disabled: true,
                    action: {}
                )
            } else {
                ForEach(conversations) { conv in
                    HistoryRow(
                        label: conv.title.isEmpty ? "(empty)" : conv.title,
                        leadingSymbol: nil,
                        trailingLabel: relativeDateLabel(conv.updatedAt),
                        action: { onSelect(conv) }
                    )
                }
            }
        }
        .padding(3)
        .frame(width: 184, alignment: .topLeading)
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(Self.xpBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 1.5, x: 2, y: 2)
    }

    private func relativeDateLabel(_ date: Date) -> String {
        let s = Date().timeIntervalSince(date)
        if s < 60 { return "now" }
        if s < 3600 { return "\(Int(s / 60))m" }
        if s < 86_400 { return "\(Int(s / 3600))h" }
        let days = Int(s / 86_400)
        return "\(days)d"
    }
}

private struct HistoryRow: View {
    let label: String
    let leadingSymbol: String?
    var trailingLabel: String? = nil
    var disabled: Bool = false
    let action: () -> Void

    @State private var hovered = false

    private static let xpSelection = Color(red: 49.0/255.0, green: 106.0/255.0, blue: 197.0/255.0)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                // Leading decorator slot — fixed 16x16 even when empty so
                // labels align across rows with and without icons.
                ZStack {
                    if let sym = leadingSymbol {
                        Image(systemName: sym)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(rowText)
                    }
                }
                .frame(width: 16, height: 16)

                Text(label)
                    .font(Font.custom("Tahoma", size: 11))
                    .foregroundStyle(rowText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let trailing = trailingLabel {
                    Text(trailing)
                        .font(Font.custom("Tahoma", size: 10))
                        .foregroundStyle(rowText.opacity(0.7))
                }

                // Trailing decorator slot.
                Color.clear.frame(width: 16, height: 16)
            }
            .padding(2)
            .frame(height: 17)
            .background(hovered && !disabled ? Self.xpSelection : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovered = $0 }
        .cursor(disabled ? .arrow : .pointingHand)
    }

    private var rowText: Color {
        if disabled { return Color.gray }
        return hovered ? .white : .black
    }
}

private struct HistoryRowSeparator: View {
    private static let xpBorder = Color(red: 172.0/255.0, green: 168.0/255.0, blue: 153.0/255.0)
    var body: some View {
        Rectangle()
            .fill(Self.xpBorder)
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}
