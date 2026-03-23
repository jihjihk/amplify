import SwiftUI
import AppKit

@MainActor
final class MarkdownTextEditorController: ObservableObject {
    weak var textView: NSTextView?

    func attach(_ textView: NSTextView) {
        self.textView = textView
    }

    func findText(_ query: String, forward: Bool = true) {
        guard !query.isEmpty, let textView else { return }

        let text = textView.string as NSString
        let selectedRange = textView.selectedRange()
        let options: NSString.CompareOptions = [.caseInsensitive]

        if forward {
            let start = min(selectedRange.upperBound, text.length)
            let forwardRange = NSRange(location: start, length: text.length - start)
            let wrappedRange = NSRange(location: 0, length: start)
            let match = text.range(of: query, options: options, range: forwardRange).location != NSNotFound
                ? text.range(of: query, options: options, range: forwardRange)
                : text.range(of: query, options: options, range: wrappedRange)
            select(match, in: textView)
        } else {
            let end = max(selectedRange.location, 0)
            let backwardRange = NSRange(location: 0, length: end)
            let wrappedRange = NSRange(location: end, length: text.length - end)
            let match = text.range(of: query, options: options.union(.backwards), range: backwardRange).location != NSNotFound
                ? text.range(of: query, options: options.union(.backwards), range: backwardRange)
                : text.range(of: query, options: options.union(.backwards), range: wrappedRange)
            select(match, in: textView)
        }
    }

    func toggleBold() {
        wrapSelection(prefix: "**", suffix: "**")
    }

    func toggleItalic() {
        wrapSelection(prefix: "*", suffix: "*")
    }

    func toggleCode() {
        wrapSelection(prefix: "`", suffix: "`")
    }

    func setHeading(level: Int) {
        guard level >= 1 && level <= 3 else { return }
        replaceLinePrefixes { line in
            let stripped = line.replacingOccurrences(of: #"^\s{0,3}#{1,6}\s+"#, with: "", options: .regularExpression)
            return String(repeating: "#", count: level) + " " + stripped
        }
    }

    func toggleQuote() {
        toggleLinePrefix("> ")
    }

    func toggleBulletList() {
        toggleLinePrefix("- ")
    }

    private func wrapSelection(prefix: String, suffix: String) {
        guard let textView else { return }
        let selectedRange = textView.selectedRange()
        let nsText = textView.string as NSString
        let selectedText = nsText.substring(with: selectedRange)

        let replacement: String
        let newSelection: NSRange

        if selectedRange.length == 0 {
            replacement = prefix + suffix
            newSelection = NSRange(location: selectedRange.location + prefix.count, length: 0)
        } else {
            replacement = prefix + selectedText + suffix
            newSelection = NSRange(location: selectedRange.location + prefix.count, length: selectedRange.length)
        }

        applyReplacement(in: selectedRange, replacement: replacement, selectedRange: newSelection)
    }

    private func toggleLinePrefix(_ prefix: String) {
        replaceLinePrefixes { line in
            let trimmedLeading = line.replacingOccurrences(of: #"^\s*"#, with: "", options: .regularExpression)
            if trimmedLeading.hasPrefix(prefix) {
                guard let range = line.range(of: prefix) else { return line }
                var updated = line
                updated.removeSubrange(range)
                return updated
            }
            return prefix + line
        }
    }

    private func replaceLinePrefixes(transform: (String) -> String) {
        guard let textView else { return }
        let nsText = textView.string as NSString
        let selectedRange = textView.selectedRange()
        let lineRange = nsText.lineRange(for: selectedRange)
        let original = nsText.substring(with: lineRange)
        let transformed = original
            .components(separatedBy: .newlines)
            .map(transform)
            .joined(separator: "\n")

        applyReplacement(
            in: lineRange,
            replacement: transformed,
            selectedRange: NSRange(location: lineRange.location, length: transformed.count)
        )
    }

    private func applyReplacement(in range: NSRange, replacement: String, selectedRange: NSRange) {
        guard let textView else { return }
        textView.textStorage?.replaceCharacters(in: range, with: replacement)
        textView.didChangeText()
        textView.setSelectedRange(selectedRange)
        textView.scrollRangeToVisible(selectedRange)
    }

    private func select(_ range: NSRange, in textView: NSTextView) {
        guard range.location != NSNotFound else { return }
        textView.window?.makeFirstResponder(textView)
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
    }
}

struct MarkdownDocumentEditorPane: View {
    @ObservedObject var session: MarkdownDocumentSession
    @StateObject private var controller = MarkdownTextEditorController()
    @State private var showFind = false
    @State private var findQuery = ""
    @FocusState private var findFieldFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                titleBar
                Divider().overlay(AmplifyColors.barBg.opacity(0.5))
                formattingBar

                if let notice = session.notice {
                    noticeBar(notice)
                }

                MarkdownTextEditor(session: session, controller: controller)
            }

            if showFind {
                FindBar(
                    query: $findQuery,
                    isFocused: $findFieldFocused,
                    onNext: { controller.findText(findQuery, forward: true) },
                    onPrev: { controller.findText(findQuery, forward: false) },
                    onDismiss: {
                        withAnimation { showFind = false }
                        findQuery = ""
                    }
                )
                .padding(.top, 92)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .background(AmplifyColors.surface)
        .background(
            Button("") {
                withAnimation(.easeInOut(duration: 0.15)) { showFind.toggle() }
                if showFind {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        findFieldFocused = true
                    }
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .hidden()
        )
        .onAppear {
            AmplifyFonts.registerIfNeeded()
            session.startIfNeeded()
        }
    }

    private var titleBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(AmplifyFonts.title2)
                    .foregroundStyle(AmplifyColors.inkPrimary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let version = session.version {
                        Label("v\(version)", systemImage: "tag")
                            .font(.caption)
                            .foregroundStyle(AmplifyColors.inkTertiary)
                    }
                    if let edited = session.editedDate {
                        Label(edited, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(AmplifyColors.inkTertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AmplifyColors.barBg)
    }

    private var formattingBar: some View {
        HStack(spacing: 8) {
            toolbarButton("H1") { controller.setHeading(level: 1) }
            toolbarButton("H2") { controller.setHeading(level: 2) }
            toolbarButton("H3") { controller.setHeading(level: 3) }
            Divider().frame(height: 16)
            toolbarButton("B") { controller.toggleBold() }
            toolbarButton("I") { controller.toggleItalic() }
            toolbarButton("{ }") { controller.toggleCode() }
            Divider().frame(height: 16)
            toolbarButton(">") { controller.toggleQuote() }
            toolbarButton("•") { controller.toggleBulletList() }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AmplifyColors.barBg)
    }

    private func toolbarButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AmplifyColors.inkPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AmplifyColors.surface)
                )
        }
        .buttonStyle(.plain)
    }

    private func noticeBar(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(AmplifyColors.inkSecondary)
                .lineLimit(2)

            Spacer()

            Button("Reload") {
                session.reloadFromDisk()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AmplifyColors.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AmplifyColors.barBg)
    }
}

private struct MarkdownTextEditor: NSViewRepresentable {
    @ObservedObject var session: MarkdownDocumentSession
    @ObservedObject var controller: MarkdownTextEditorController

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session, controller: controller)
    }

    func makeNSView(context: Context) -> NSScrollView {
        AmplifyFonts.registerIfNeeded()

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = MarkdownStyler.surfaceColor

        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = true
        textView.allowsUndo = true
        textView.backgroundColor = MarkdownStyler.surfaceColor
        textView.drawsBackground = true
        textView.textColor = MarkdownStyler.primaryColor
        textView.insertionPointColor = MarkdownStyler.primaryColor
        textView.font = MarkdownStyler.bodyFont
        textView.textContainerInset = NSSize(width: 44, height: 32)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        context.coordinator.attach(textView)
        context.coordinator.applyStyledText(session.text, to: textView, preserveSelection: false)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.attach(textView)
        let contentSize = scrollView.contentSize
        textView.frame.size.width = contentSize.width
        textView.minSize.height = contentSize.height
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        if !context.coordinator.isApplyingProgrammaticChange, textView.string != session.text {
            context.coordinator.applyStyledText(session.text, to: textView, preserveSelection: true)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let session: MarkdownDocumentSession
        let controller: MarkdownTextEditorController
        var isApplyingProgrammaticChange = false

        init(session: MarkdownDocumentSession, controller: MarkdownTextEditorController) {
            self.session = session
            self.controller = controller
        }

        func attach(_ textView: NSTextView) {
            controller.attach(textView)
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingProgrammaticChange,
                  let textView = notification.object as? NSTextView else { return }
            session.updateText(textView.string)
            applyStyledText(textView.string, to: textView, preserveSelection: true)
        }

        func applyStyledText(_ text: String, to textView: NSTextView, preserveSelection: Bool) {
            let selectedRange = textView.selectedRange()
            let attributed = MarkdownStyler.makeAttributedString(from: text)
            isApplyingProgrammaticChange = true
            textView.textStorage?.setAttributedString(attributed)
            textView.typingAttributes = MarkdownStyler.typingAttributes
            if preserveSelection {
                let nsText = textView.string as NSString
                let clampedRange = NSRange(
                    location: min(selectedRange.location, nsText.length),
                    length: min(selectedRange.length, max(0, nsText.length - min(selectedRange.location, nsText.length)))
                )
                textView.setSelectedRange(clampedRange)
            }
            isApplyingProgrammaticChange = false
        }
    }
}

@MainActor
enum MarkdownStyler {
    static let primaryColor = AmplifyColors.adaptiveNS(
        light: NSColor(red: 26 / 255, green: 23 / 255, blue: 19 / 255, alpha: 1),
        dark: NSColor(red: 237 / 255, green: 232 / 255, blue: 223 / 255, alpha: 1)
    )
    static let secondaryColor = AmplifyColors.adaptiveNS(
        light: NSColor(red: 107 / 255, green: 97 / 255, blue: 87 / 255, alpha: 1),
        dark: NSColor(red: 156 / 255, green: 145 / 255, blue: 136 / 255, alpha: 1)
    )
    static let tertiaryColor = AmplifyColors.adaptiveNS(
        light: NSColor(red: 156 / 255, green: 145 / 255, blue: 136 / 255, alpha: 1),
        dark: NSColor(red: 107 / 255, green: 97 / 255, blue: 87 / 255, alpha: 1)
    )
    static let surfaceColor = AmplifyColors.adaptiveNS(
        light: NSColor(red: 247 / 255, green: 244 / 255, blue: 239 / 255, alpha: 1),
        dark: NSColor(red: 32 / 255, green: 29 / 255, blue: 25 / 255, alpha: 1)
    )
    static let barColor = AmplifyColors.adaptiveNS(
        light: NSColor(red: 237 / 255, green: 232 / 255, blue: 223 / 255, alpha: 1),
        dark: NSColor(red: 26 / 255, green: 23 / 255, blue: 19 / 255, alpha: 1)
    )

    static let bodyFont = NSFont(name: "Georgia", size: 17) ?? .systemFont(ofSize: 17, weight: .regular)
    static let italicBodyFont = NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask)
    static let monospacedFont = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
    static let title1Font = NSFont(name: "Instrument Serif", size: 32) ?? NSFont.systemFont(ofSize: 30, weight: .regular)
    static let title2Font = NSFont(name: "Instrument Serif", size: 25) ?? NSFont.systemFont(ofSize: 24, weight: .regular)
    static let title3Font = NSFont(name: "Instrument Serif", size: 20) ?? NSFont.systemFont(ofSize: 20, weight: .regular)
    static let boldFont = NSFontManager.shared.convert(bodyFont, toHaveTrait: .boldFontMask)

    static let typingAttributes: [NSAttributedString.Key: Any] = [
        .font: bodyFont,
        .foregroundColor: primaryColor
    ]

    static func makeAttributedString(from text: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: attributed.length)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.28
        paragraphStyle.paragraphSpacing = 10

        attributed.addAttributes([
            .font: bodyFont,
            .foregroundColor: primaryColor,
            .paragraphStyle: paragraphStyle
        ], range: fullRange)

        let nsText = text as NSString
        var isInCodeFence = false
        nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length), options: .byLines) { substring, lineRange, _, _ in
            guard let line = substring else { return }
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                isInCodeFence.toggle()
                attributed.addAttributes([
                    .font: monospacedFont,
                    .foregroundColor: secondaryColor,
                    .backgroundColor: barColor
                ], range: lineRange)
                return
            }

            if isInCodeFence {
                attributed.addAttributes([
                    .font: monospacedFont,
                    .foregroundColor: primaryColor,
                    .backgroundColor: barColor
                ], range: lineRange)
                return
            }

            if let match = line.range(of: #"^(#{1,3})\s+"#, options: .regularExpression) {
                let prefixLength = line.distance(from: line.startIndex, to: match.upperBound)
                let prefixRange = NSRange(location: lineRange.location, length: prefixLength)
                let contentRange = NSRange(location: lineRange.location + prefixLength, length: max(0, lineRange.length - prefixLength))
                let level = line.prefix { $0 == "#" }.count
                let headingFont = level == 1 ? title1Font : (level == 2 ? title2Font : title3Font)

                attributed.addAttribute(.font, value: headingFont, range: contentRange)
                attributed.addAttribute(.foregroundColor, value: tertiaryColor, range: prefixRange)
                return
            }

            if trimmed.hasPrefix("> ") {
                let prefixRange = NSRange(location: lineRange.location, length: min(2, lineRange.length))
                let contentRange = NSRange(location: lineRange.location + min(2, lineRange.length), length: max(0, lineRange.length - 2))
                let blockQuoteStyle = NSMutableParagraphStyle()
                blockQuoteStyle.lineHeightMultiple = 1.28
                blockQuoteStyle.paragraphSpacing = 10
                blockQuoteStyle.headIndent = 18
                blockQuoteStyle.firstLineHeadIndent = 18

                attributed.addAttributes([
                    .font: italicBodyFont,
                    .foregroundColor: secondaryColor,
                    .paragraphStyle: blockQuoteStyle
                ], range: contentRange)
                attributed.addAttribute(.foregroundColor, value: tertiaryColor, range: prefixRange)
                return
            }

            if let match = line.range(of: #"^(\s*[-*+]\s+|\s*\d+\.\s+)"#, options: .regularExpression) {
                let prefixLength = line.distance(from: line.startIndex, to: match.upperBound)
                let prefixRange = NSRange(location: lineRange.location, length: prefixLength)
                let listStyle = NSMutableParagraphStyle()
                listStyle.lineHeightMultiple = 1.28
                listStyle.paragraphSpacing = 10
                listStyle.headIndent = 20
                listStyle.firstLineHeadIndent = 8
                attributed.addAttribute(.paragraphStyle, value: listStyle, range: lineRange)
                attributed.addAttribute(.foregroundColor, value: tertiaryColor, range: prefixRange)
            }
        }

        applyInlinePattern(#"\*\*([^*\n]+)\*\*"#, font: boldFont, to: attributed)
        applyInlinePattern(#"\*([^*\n]+)\*"#, font: italicBodyFont, to: attributed)
        applyCodePattern(to: attributed)
        return attributed
    }

    private static func applyInlinePattern(_ pattern: String, font: NSFont, to attributed: NSMutableAttributedString) {
        let text = attributed.string as NSString
        let regex = try? NSRegularExpression(pattern: pattern)
        regex?.matches(in: attributed.string, range: NSRange(location: 0, length: text.length)).reversed().forEach { match in
            guard match.numberOfRanges >= 2 else { return }
            let outerRange = match.range(at: 0)
            let innerRange = match.range(at: 1)
            let prefixRange = NSRange(location: outerRange.location, length: max(0, innerRange.location - outerRange.location))
            let suffixLocation = innerRange.location + innerRange.length
            let suffixRange = NSRange(location: suffixLocation, length: max(0, outerRange.upperBound - suffixLocation))
            attributed.addAttribute(.font, value: font, range: innerRange)
            attributed.addAttribute(.foregroundColor, value: tertiaryColor, range: prefixRange)
            attributed.addAttribute(.foregroundColor, value: tertiaryColor, range: suffixRange)
        }
    }

    private static func applyCodePattern(to attributed: NSMutableAttributedString) {
        let text = attributed.string as NSString
        let regex = try? NSRegularExpression(pattern: #"`([^`\n]+)`"#)
        regex?.matches(in: attributed.string, range: NSRange(location: 0, length: text.length)).reversed().forEach { match in
            guard match.numberOfRanges >= 2 else { return }
            let outerRange = match.range(at: 0)
            let innerRange = match.range(at: 1)
            let prefixRange = NSRange(location: outerRange.location, length: 1)
            let suffixRange = NSRange(location: outerRange.upperBound - 1, length: 1)
            attributed.addAttributes([
                .font: monospacedFont,
                .backgroundColor: barColor
            ], range: innerRange)
            attributed.addAttribute(.foregroundColor, value: tertiaryColor, range: prefixRange)
            attributed.addAttribute(.foregroundColor, value: tertiaryColor, range: suffixRange)
        }
    }
}

private extension NSRange {
    var upperBound: Int { location + length }
}
