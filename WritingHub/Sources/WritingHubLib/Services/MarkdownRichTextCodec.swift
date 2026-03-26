import Foundation

struct MarkdownDocumentEnvelope: Equatable {
    let frontMatterBlock: String?
    let bodyMarkdown: String
    let protectedSuffix: String?

    static func parse(from text: String) -> MarkdownDocumentEnvelope {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        var frontMatterBlock: String?
        var contentStartIndex = 0

        if lines.first?.trimmingCharacters(in: .whitespaces) == "---",
           let closingIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
            frontMatterBlock = lines[0...closingIndex].joined(separator: "\n")
            contentStartIndex = closingIndex + 1
        }

        let remainingLines = contentStartIndex < lines.count ? Array(lines[contentStartIndex...]) : []
        let markerIndex = remainingLines.firstIndex { $0.trimmingCharacters(in: .whitespaces) == "## Platform Versions" }

        let bodyLines: [String]
        let suffixLines: [String]
        if let markerIndex {
            bodyLines = Array(remainingLines[..<markerIndex])
            suffixLines = Array(remainingLines[markerIndex...])
        } else {
            bodyLines = remainingLines
            suffixLines = []
        }

        return MarkdownDocumentEnvelope(
            frontMatterBlock: frontMatterBlock,
            bodyMarkdown: bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
            protectedSuffix: suffixLines.isEmpty ? nil : suffixLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func rebuild(withBodyMarkdown bodyMarkdown: String) -> String {
        let body = bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        let sections: [String] = [
            frontMatterBlock?.trimmingCharacters(in: .newlines),
            body.isEmpty ? nil : body,
            protectedSuffix?.trimmingCharacters(in: .newlines)
        ].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        guard !sections.isEmpty else { return "" }
        return sections.joined(separator: "\n\n") + "\n"
    }
}

enum MarkdownRichTextCodec {
    static func html(fromMarkdown markdown: String) -> String {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var htmlBlocks: [String] = []
        var index = 0

        func closeParagraph(_ buffer: inout [String]) {
            guard !buffer.isEmpty else { return }
            let paragraph = buffer
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !paragraph.isEmpty {
                htmlBlocks.append("<p>\(renderInlineMarkdown(paragraph))</p>")
            }
            buffer.removeAll()
        }

        var paragraphBuffer: [String] = []

        while index < lines.count {
            let rawLine = lines[index]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                closeParagraph(&paragraphBuffer)
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                closeParagraph(&paragraphBuffer)
                var codeLines: [String] = []
                index += 1
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                htmlBlocks.append("<pre><code>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
                if index < lines.count { index += 1 }
                continue
            }

            if let heading = parseHeading(trimmed) {
                closeParagraph(&paragraphBuffer)
                htmlBlocks.append("<h\(heading.level)>\(renderInlineMarkdown(heading.content))</h\(heading.level)>")
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                closeParagraph(&paragraphBuffer)
                var quoteLines: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    guard current.hasPrefix(">") else { break }
                    quoteLines.append(String(current.drop { $0 == ">" || $0 == " " }))
                    index += 1
                }
                let nestedMarkdown = quoteLines.joined(separator: "\n")
                htmlBlocks.append("<blockquote>\(html(fromMarkdown: nestedMarkdown))</blockquote>")
                continue
            }

            if let list = parseList(from: lines, index: index) {
                closeParagraph(&paragraphBuffer)
                htmlBlocks.append(list.html)
                index = list.nextIndex
                continue
            }

            paragraphBuffer.append(rawLine)
            index += 1
        }

        closeParagraph(&paragraphBuffer)
        return htmlBlocks.joined()
    }

    static func markdown(fromHTML html: String) -> String {
        let wrapped = "<root>\(sanitizeHTMLFragment(html))</root>"
        guard let document = try? XMLDocument(xmlString: wrapped, options: .nodePreserveAll),
              let root = document.rootElement() else {
            return ""
        }

        let blocks = root.children?
            .compactMap { renderBlock(node: $0, indent: 0) }
            .flatMap { $0 }
            .filter { !$0.isEmpty } ?? []

        return blocks
            .joined(separator: "\n\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseHeading(_ line: String) -> (level: Int, content: String)? {
        let headingHashes = line.prefix { $0 == "#" }
        guard (1...3).contains(headingHashes.count) else { return nil }
        let remainder = line.dropFirst(headingHashes.count)
        guard remainder.first == " " else { return nil }
        return (headingHashes.count, remainder.trimmingCharacters(in: .whitespaces))
    }

    private static func parseList(from lines: [String], index: Int) -> (html: String, nextIndex: Int)? {
        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        let orderedRange = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression)
        let unorderedRange = trimmed.range(of: #"^[-*+]\s+"#, options: .regularExpression)
        guard orderedRange != nil || unorderedRange != nil else { return nil }

        let isOrdered = orderedRange != nil
        let tag = isOrdered ? "ol" : "ul"
        var items: [String] = []
        var cursor = index

        while cursor < lines.count {
            let current = lines[cursor].trimmingCharacters(in: .whitespaces)
            let range = isOrdered
                ? current.range(of: #"^\d+\.\s+"#, options: .regularExpression)
                : current.range(of: #"^[-*+]\s+"#, options: .regularExpression)
            guard let range else { break }
            let content = String(current[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            items.append("<li><p>\(renderInlineMarkdown(content))</p></li>")
            cursor += 1
        }

        return ("<\(tag)>\(items.joined())</\(tag)>", cursor)
    }

    private static func renderInlineMarkdown(_ text: String) -> String {
        var html = escapeHTML(text)
        html = html.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(([^)]+)\)"#,
            with: #"<img alt="$1" src="$2"/>"#,
            options: .regularExpression
        )
        html = html.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#,
            with: #"<a href="$2">$1</a>"#,
            options: .regularExpression
        )
        html = html.replacingOccurrences(
            of: #"`([^`\n]+)`"#,
            with: #"<code>$1</code>"#,
            options: .regularExpression
        )
        html = html.replacingOccurrences(
            of: #"\*\*([^*\n]+)\*\*"#,
            with: #"<strong>$1</strong>"#,
            options: .regularExpression
        )
        html = html.replacingOccurrences(
            of: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#,
            with: #"<em>$1</em>"#,
            options: .regularExpression
        )
        return html
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func sanitizeHTMLFragment(_ html: String) -> String {
        var sanitized = html
            .replacingOccurrences(of: "&nbsp;", with: "&#160;")
            .replacingOccurrences(of: "<br>", with: "<br/>")
            .replacingOccurrences(of: "<br />", with: "<br/>")
        sanitized = sanitized.replacingOccurrences(
            of: #"<img([^>]*?)(?<!/)> "#,
            with: #"<img$1/> "#,
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"<img([^>]*?)(?<!/)>$"#,
            with: #"<img$1/>"#,
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"<img([^>]*?)(?<!/)> "#,
            with: #"<img$1/> "#,
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"<img([^>]*?)(?<!/)>"#,
            with: #"<img$1/>"#,
            options: .regularExpression
        )
        return sanitized
    }

    private static func renderBlock(node: XMLNode, indent: Int) -> [String]? {
        guard let element = node as? XMLElement else {
            let text = node.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? nil : [text]
        }

        switch element.name?.lowercased() {
        case "p":
            let inline = renderInline(nodes: element.children ?? []).trimmingCharacters(in: .whitespacesAndNewlines)
            return inline.isEmpty ? nil : [inline]
        case "h1":
            return renderHeading(level: 1, element: element)
        case "h2":
            return renderHeading(level: 2, element: element)
        case "h3":
            return renderHeading(level: 3, element: element)
        case "blockquote":
            let content = (element.children ?? [])
                .compactMap { renderBlock(node: $0, indent: indent) }
                .flatMap { $0 }
                .joined(separator: "\n\n")
            guard !content.isEmpty else { return nil }
            return [content
                .components(separatedBy: "\n")
                .map { $0.isEmpty ? ">" : "> \($0)" }
                .joined(separator: "\n")]
        case "ul":
            return renderList(element: element, ordered: false, indent: indent)
        case "ol":
            return renderList(element: element, ordered: true, indent: indent)
        case "pre":
            let code = element.stringValue ?? ""
            return ["```\n\(code.trimmingCharacters(in: .newlines))\n```"]
        case "div", "body", "root":
            return (element.children ?? [])
                .compactMap { renderBlock(node: $0, indent: indent) }
                .flatMap { $0 }
        case "br":
            return [""]
        default:
            let inline = renderInline(nodes: element.children ?? []).trimmingCharacters(in: .whitespacesAndNewlines)
            return inline.isEmpty ? nil : [inline]
        }
    }

    private static func renderHeading(level: Int, element: XMLElement) -> [String] {
        let content = renderInline(nodes: element.children ?? []).trimmingCharacters(in: .whitespacesAndNewlines)
        return [String(repeating: "#", count: level) + " " + content]
    }

    private static func renderList(element: XMLElement, ordered: Bool, indent: Int) -> [String] {
        var lines: [String] = []
        let children = element.children?.compactMap { $0 as? XMLElement }.filter { $0.name?.lowercased() == "li" } ?? []
        for (index, item) in children.enumerated() {
            let prefix = ordered ? "\(index + 1)." : "-"
            let nestedLists = item.children?.compactMap { child -> XMLElement? in
                guard let child = child as? XMLElement else { return nil }
                let name = child.name?.lowercased() ?? ""
                return (name == "ul" || name == "ol") ? child : nil
            } ?? []

            let directChildren = item.children?.filter { child in
                guard let child = child as? XMLElement else { return true }
                let name = child.name?.lowercased() ?? ""
                return name != "ul" && name != "ol"
            } ?? []

            let content = renderInline(nodes: directChildren).trimmingCharacters(in: .whitespacesAndNewlines)
            let line = String(repeating: " ", count: indent) + prefix + " " + content
            lines.append(line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(repeating: " ", count: indent) + prefix : line)

            for nested in nestedLists {
                lines.append(contentsOf: renderList(element: nested, ordered: nested.name?.lowercased() == "ol", indent: indent + 2))
            }
        }
        return lines
    }

    private static func renderInline(nodes: [XMLNode]) -> String {
        nodes.map { node in
            if let element = node as? XMLElement {
                let content = renderInline(nodes: element.children ?? [])
                switch element.name?.lowercased() {
                case "strong", "b":
                    return content.isEmpty ? "" : "**\(content)**"
                case "em", "i":
                    return content.isEmpty ? "" : "*\(content)*"
                case "code":
                    return content.isEmpty ? "" : "`\(content)`"
                case "a":
                    let href = element.attribute(forName: "href")?.stringValue ?? ""
                    return href.isEmpty ? content : "[\(content)](\(href))"
                case "img":
                    let src = element.attribute(forName: "src")?.stringValue ?? ""
                    let alt = element.attribute(forName: "alt")?.stringValue ?? ""
                    return src.isEmpty ? "" : "![\(alt)](\(src))"
                case "br":
                    return "\n"
                case "p":
                    return content
                default:
                    return content
                }
            }
            return node.stringValue ?? ""
        }
        .joined()
        .replacingOccurrences(of: "\u{00A0}", with: " ")
    }
}
