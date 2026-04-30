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
                .onChange(of: viewModel.responseText) { _, _ in
                    proxy.scrollTo("bubbleBottom", anchor: .bottom)
                }
                .onChange(of: viewModel.bubbleMode) { _, newMode in
                    if newMode == .input {
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
        switch viewModel.bubbleMode {
        case .hidden:
            EmptyView()
        case .input:
            inputContent
        case .streaming, .showing:
            responseContent
        case .error(let text):
            errorContent(text)
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

    // MARK: - response mode

    private var responseContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if case .streaming = viewModel.bubbleMode {
                    ProgressView()
                        .controlSize(.mini)
                }
                Text(headerText)
                    .font(XP.font(size: 12, bold: true))
                    .foregroundStyle(XP.textSecondary)
                Spacer()
                if case .streaming = viewModel.bubbleMode {
                    Button {
                        viewModel.cancelStream()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red.opacity(0.85))
                    .cursor(.pointingHand)
                } else {
                    Button {
                        viewModel.bubbleMode = .input
                        viewModel.responseText = ""
                    } label: {
                        Image(systemName: "arrow.uturn.left")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(XP.textSecondary)
                    .cursor(.pointingHand)
                }
            }

            if !viewModel.responseText.isEmpty {
                Text(viewModel.responseText)
                    .font(XP.font(size: 13))
                    .foregroundStyle(XP.textBody)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
