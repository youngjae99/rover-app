import SwiftUI
import AppKit

struct SpeechBubbleView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var settings: RoverSettings

    /// Distance from the bubble's trailing edge to the center of its tail.
    var tailOffsetFromTrailing: CGFloat = 100

    var body: some View {
        VStack(spacing: 0) {
            box
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                BubbleTail()
                    .fill(XP.bubbleFill)
                    .overlay(
                        BubbleTail()
                            .stroke(XP.bubbleBorder, lineWidth: 1)
                    )
                    .frame(width: 18, height: 10)
                    .padding(.trailing, max(tailOffsetFromTrailing - 9, 8))
            }
        }
        .frame(width: 320)
        .shadow(color: XP.bubbleShadow, radius: 10, x: 0, y: 6)
    }

    private var s: AppStrings { settings.s }

    private var box: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    scrollableContent
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("bubbleTop")
                    Color.clear.frame(height: 1).id("bubbleBottom")
                }
                .frame(maxHeight: viewModel.maxBubbleScrollHeight)
                .onChange(of: viewModel.transcript.last?.text) { _, _ in
                    proxy.scrollTo("bubbleBottom", anchor: .bottom)
                }
                .onChange(of: viewModel.transcript.count) { _, _ in
                    proxy.scrollTo("bubbleBottom", anchor: .bottom)
                }
                .onChange(of: viewModel.bubbleMode) { _, newMode in
                    if newMode == .input, !viewModel.hasTranscript {
                        proxy.scrollTo("bubbleTop", anchor: .top)
                    }
                }
            }

            Rectangle()
                .fill(XP.divider)
                .frame(height: 1)

            promptField
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .background(bubbleBackground)
    }

    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(XP.bubbleFill)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(XP.bubbleBorder, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var scrollableContent: some View {
        // Pending permission (if any) always sits at the top so the user
        // can answer it without scrolling past streaming text.
        if let req = viewModel.pendingPermission {
            PermissionCard(request: req,
                           strings: s,
                           onAllow: { viewModel.respondToPermission(.allow) },
                           onDeny: { viewModel.respondToPermission(.deny) },
                           onAsk: { viewModel.respondToPermission(.ask) })
                .padding(.bottom, viewModel.hasTranscript || viewModel.bubbleMode == .input ? 10 : 0)
        }
        // The bubble shows the transcript whenever there is one, regardless
        // of mode. Starters only appear when the conversation is empty AND
        // the bubble is in input mode (i.e. fresh state, never asked).
        if viewModel.hasTranscript {
            transcriptContent
        } else if viewModel.bubbleMode == .input {
            inputContent
        } else if case .error(let text) = viewModel.bubbleMode {
            errorContent(text)
        } else if viewModel.pendingPermission == nil {
            EmptyView()
        }
    }

    // MARK: - input mode

    private var inputContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(s.bubbleInputHeader)
                .font(XP.font(size: 13, bold: true))
                .foregroundStyle(XP.textHeader)
                .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(settings.primaryStarters) { starter in
                    StarterButton(starter: starter, kind: .greenArrow) {
                        viewModel.runStarter(starter)
                    }
                }
            }

            xpDivider
                .padding(.vertical, 2)

            Text(s.bubbleOtherSection)
                .font(XP.font(size: 12))
                .foregroundStyle(XP.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(settings.secondaryStarters) { starter in
                    StarterButton(starter: starter, kind: .blueIcon) {
                        viewModel.runStarter(starter)
                    }
                }
            }
        }
    }

    // MARK: - transcript

    private var transcriptContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if case .streaming = viewModel.bubbleMode {
                    ProgressView()
                        .controlSize(.mini)
                }
                Text(headerText)
                    .font(XP.font(size: 12, bold: true))
                    .foregroundStyle(XP.textSecondary)
                Spacer()
                // While streaming the header shows only the status. The
                // stop affordance lives inside the prompt field below, where
                // the user's eye already is.
                if case .streaming = viewModel.bubbleMode {
                    EmptyView()
                } else {
                    headerButton(
                        symbol: "arrow.counterclockwise",
                        label: s.bubbleNewConvButton,
                        tint: XP.textSecondary,
                        action: { viewModel.newConversation() }
                    )
                }
            }

            ForEach(viewModel.transcript) { item in
                TranscriptRow(item: item)
            }
        }
    }

    /// Pill button used in the bubble header: icon + short label, plain
    /// style so our `.cursor` modifier actually wins over the button's
    /// own tracking area, and a soft tinted background so it's visible.
    private func headerButton(symbol: String, label: String,
                              tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(XP.font(size: 11, bold: true))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tint.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(tint.opacity(0.25), lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .cursor(.pointingHand)
    }

    private var headerText: String {
        if case .streaming = viewModel.bubbleMode {
            return viewModel.statusText.isEmpty ? s.bubbleStreamingThinking : viewModel.statusText
        }
        return s.bubbleResponseHeader
    }

    // MARK: - error

    private func errorContent(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(s.bubbleErrorTitle)
                .font(XP.font(size: 12, bold: true))
                .foregroundStyle(.red)
            Text(text)
                .font(XP.font(size: 13))
                .foregroundStyle(XP.textBody.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - shared subviews

    private var xpDivider: some View {
        Rectangle()
            .fill(XP.divider)
            .frame(height: 1)
    }

    private var promptField: some View {
        HStack(spacing: 8) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 11))
                .foregroundStyle(XP.accent)
            BubbleTextField(
                text: $viewModel.inputText,
                placeholder: viewModel.isStreaming
                    ? s.bubblePromptBusyPlaceholder
                    : s.bubblePromptPlaceholder,
                isEnabled: !viewModel.isStreaming,
                onSubmit: { viewModel.send() },
                onCancel: { viewModel.dismissBubble() }
            )
            .frame(maxWidth: .infinity)
            if viewModel.isStreaming {
                stopButton
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(XP.promptFieldFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(XP.promptFieldBorder, lineWidth: 1)
                )
        )
    }

    /// Compact red stop affordance pinned to the trailing edge of the
    /// prompt field while a turn is streaming. The user's eye is already on
    /// the input area, so this is where they expect a "kill the agent"
    /// control.
    private var stopButton: some View {
        Button { viewModel.cancelStream() } label: {
            Image(systemName: "stop.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(
                    Circle()
                        .fill(Color.red.opacity(0.85))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(s.bubbleStopButton)
        .cursor(.pointingHand)
    }
}

// MARK: - StarterButton

private struct StarterButton: View {
    enum Kind {
        case greenArrow
        case blueIcon
    }

    let starter: LocalizedStarter
    let kind: Kind
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                icon
                    .padding(.top, 1)
                Text(starter.label)
                    .font(XP.font(size: 13))
                    .foregroundStyle(hovered ? XP.textLinkHover : XP.textBody)
                    .underline(hovered)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .cursor(.pointingHand)
    }

    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .greenArrow:
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(LinearGradient(
                        colors: [XP.arrowGreenStart, XP.arrowGreenEnd],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 18, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color.black.opacity(0.18), lineWidth: 0.5)
                    )
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 0.5, x: 0, y: 1)
            }
        case .blueIcon:
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [XP.helpBlueStart, XP.helpBlueEnd],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle().stroke(Color.black.opacity(0.18), lineWidth: 0.5)
                    )
                Image(systemName: starter.symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - BubbleTail

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.closeSubpath()
        return p
    }
}

// MARK: - BubbleTextField

private struct BubbleTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isEnabled: Bool
    var onSubmit: () -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = ResponderField()
        field.font = XP.nsTahoma
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submitted(_:))
        field.textColor = NSColor.black
        field.placeholderAttributedString = Self.placeholderString(placeholder)
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
        field.placeholderAttributedString = Self.placeholderString(placeholder)
        field.textColor = NSColor.black
        field.isEditable = isEnabled
        if isEnabled, field.window?.firstResponder !== field.currentEditor() {
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
            }
        }
    }

    private static func placeholderString(_ placeholder: String) -> NSAttributedString {
        NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: NSColor.black.withAlphaComponent(0.35),
            .font: XP.nsTahoma
        ])
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: BubbleTextField
        init(_ parent: BubbleTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        @objc func submitted(_ sender: NSTextField) {
            parent.text = sender.stringValue
            parent.onSubmit()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            return false
        }
    }
}

private final class ResponderField: NSTextField {
    override var acceptsFirstResponder: Bool { true }
}

// MARK: - TranscriptRow

private struct TranscriptRow: View {
    let item: TranscriptItem

    var body: some View {
        switch item.kind {
        case .user:
            HStack(alignment: .top, spacing: 6) {
                Text("you")
                    .font(XP.font(size: 10, bold: true))
                    .foregroundStyle(XP.accent)
                    .padding(.top, 2)
                Text(item.text)
                    .font(XP.font(size: 13))
                    .foregroundStyle(XP.textBody)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

        case .assistant:
            AssistantMarkdownView(text: item.text, streaming: item.streaming)

        case .reasoning:
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "ellipsis.bubble")
                    .font(.system(size: 9))
                    .foregroundStyle(XP.textSecondary.opacity(0.7))
                    .padding(.top, 3)
                Text(item.text + (item.streaming ? "▌" : ""))
                    .font(XP.font(size: 12).italic())
                    .foregroundStyle(XP.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.04))
            )

        case .toolCall:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(XP.accent)
                Text(item.text)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(XP.accent)
                if let meta = item.meta, !meta.isEmpty {
                    Text(meta)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(XP.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }

        case .toolError:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                Text(item.text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.orange)
                Spacer(minLength: 0)
            }

        case .status:
            Text(item.text)
                .font(XP.font(size: 12))
                .foregroundStyle(XP.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .error:
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                Text(item.text)
                    .font(XP.font(size: 12))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - AssistantMarkdownView

/// Render an assistant message with inline markdown (bold, italic,
/// links, inline `code`) plus fenced ```code blocks as monospaced
/// callouts. Streaming text skips parsing to avoid flicker on partial
/// `*foo` / `**bar` tokens, and renders a cursor caret instead.
private struct AssistantMarkdownView: View {
    let text: String
    let streaming: Bool

    var body: some View {
        if streaming {
            // Don't try to parse half-complete markdown mid-stream — it
            // flickers on every token boundary. Render plain with a
            // cursor and re-parse once the turn finalizes.
            Text(text + "▌")
                .font(XP.font(size: 13))
                .foregroundStyle(XP.textBody)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .markdown(let s):
                        Text(Self.attributed(from: s))
                            .font(XP.font(size: 13))
                            .foregroundStyle(XP.textBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    case .code(let s):
                        Text(s)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(XP.textBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.black.opacity(0.06))
                            )
                    }
                }
            }
        }
    }

    private enum Segment {
        case markdown(String)
        case code(String)
    }

    /// Split `text` into alternating prose / fenced-code segments. We
    /// look for ``` fences at the start of a line; everything between a
    /// matched pair becomes a code segment, language tag (if any) is
    /// dropped from the rendered body.
    private var segments: [Segment] {
        var out: [Segment] = []
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var buffer: [String] = []
        var inCode = false
        var codeBuffer: [String] = []
        while !lines.isEmpty {
            let line = lines.removeFirst()
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inCode {
                    out.append(.code(codeBuffer.joined(separator: "\n")))
                    codeBuffer.removeAll()
                    inCode = false
                } else {
                    if !buffer.isEmpty {
                        out.append(.markdown(buffer.joined(separator: "\n")))
                        buffer.removeAll()
                    }
                    inCode = true
                }
                continue
            }
            if inCode {
                codeBuffer.append(line)
            } else {
                buffer.append(line)
            }
        }
        // Trailing unmatched fence — treat the rest as code anyway so the
        // user still sees something sensible mid-stream.
        if inCode, !codeBuffer.isEmpty {
            out.append(.code(codeBuffer.joined(separator: "\n")))
        }
        if !buffer.isEmpty {
            out.append(.markdown(buffer.joined(separator: "\n")))
        }
        return out
    }

    /// Parse a chunk as inline markdown via Foundation's
    /// AttributedString init. Falls back to a plain AttributedString on
    /// parse failure (rare — Foundation accepts almost everything).
    private static func attributed(from text: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        if let s = try? AttributedString(markdown: text, options: options) {
            return s
        }
        return AttributedString(text)
    }
}

// MARK: - PermissionCard

/// In-bubble Allow / Deny / Ask card shown while a Claude Code
/// PreToolUse hook is waiting on a decision. Folds out a "Show full
/// input" detail row on demand.
private struct PermissionCard: View {
    let request: PermissionRequest
    let strings: AppStrings
    let onAllow: () -> Void
    let onDeny: () -> Void
    let onAsk: () -> Void

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.orange)
                Text(strings.permBubbleHeader)
                    .font(XP.font(size: 11, bold: true))
                    .foregroundStyle(.orange)
                Spacer()
                Text(request.toolName)
                    .font(XP.font(size: 11, bold: true))
                    .foregroundStyle(XP.textHeader)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.orange.opacity(0.10))
                    )
            }

            if let summary = request.summary, !summary.isEmpty {
                Text(summary)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(XP.textBody)
                    .lineLimit(expanded ? nil : 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if expanded, let detail = request.inputDetail, !detail.isEmpty {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(detail)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(XP.textBody.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(6)
                }
                .frame(maxHeight: 160)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                )
            }

            HStack(spacing: 6) {
                if request.inputDetail != nil {
                    Button(expanded ? strings.permBubbleHideDetail : strings.permBubbleShowDetail) {
                        expanded.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(XP.font(size: 11))
                    .foregroundStyle(XP.textSecondary)
                    .underline()
                    .cursor(.pointingHand)
                }
                Spacer()
                pillButton(symbol: "questionmark.circle",
                           label: strings.permBubbleAsk,
                           tint: XP.textSecondary,
                           action: onAsk)
                pillButton(symbol: "xmark",
                           label: strings.permBubbleDeny,
                           tint: Color.red.opacity(0.85),
                           action: onDeny)
                pillButton(symbol: "checkmark",
                           label: strings.permBubbleAllow,
                           tint: Color.green.opacity(0.85),
                           action: onAllow)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.orange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.orange.opacity(0.40), lineWidth: 1)
                )
        )
    }

    private func pillButton(symbol: String,
                            label: String,
                            tint: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
                Text(label).font(XP.font(size: 11, bold: true))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(tint.opacity(0.30), lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .cursor(.pointingHand)
    }
}
