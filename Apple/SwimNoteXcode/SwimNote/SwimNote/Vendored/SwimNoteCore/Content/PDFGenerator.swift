import SwiftUI
import PDFKit
import UIKit

/// Generates PDF documents from markdown content with proper formatting
public struct PDFGenerator: Sendable {
    public init() {}

    /// Generate a PDF from parsed technique content
    /// Returns URL to temporary PDF file, or nil if generation failed
    public func generatePDF(from content: ParsedTechniqueContent) -> URL? {
        generatePDFFromMarkdown(filename: content.filename, markdown: content.rawContent, title: content.title)
    }

    /// Generate PDF from raw markdown content with proper formatting
    public func generatePDFFromMarkdown(filename: String, markdown: String, title: String) -> URL? {
        // Generate unique filename
        let baseName = filename
            .replacingOccurrences(of: ".md", with: "")
            .replacingOccurrences(of: "swimming-strokes/", with: "")
        let pdfURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName).pdf")

        // Remove existing file if present
        try? FileManager.default.removeItem(at: pdfURL)

        // Create PDF using markdown to attributed string conversion
        let pdfMetaData: [String: Any] = [
            kCGPDFContextCreator as String: "SwimNote",
            kCGPDFContextTitle as String: title
        ]

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let pageMargins = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
        let maxWidth = pageRect.width - pageMargins.left - pageMargins.right

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: UIGraphicsPDFRendererFormat())

        // Parse markdown into sections for rendering
        let sections = parseMarkdownSections(markdown)

        let data = renderer.pdfData { context in
            var yPosition = pageRect.height - pageMargins.top
            var pageNumber = 1

            context.beginPage(withBounds: pageRect, pageInfo: pdfMetaData)

            for section in sections {
                // Check if we need a new page
                let estimatedHeight = estimateSectionHeight(section, maxWidth: maxWidth)
                if yPosition - estimatedHeight < pageMargins.bottom {
                    pageNumber += 1
                    context.beginPage(withBounds: pageRect, pageInfo: pdfMetaData)
                    yPosition = pageRect.height - pageMargins.top

                    // Add page header
                    drawPageHeader(title: title, pageNumber: pageNumber, yPosition: yPosition, pageRect: pageRect, margins: pageMargins)
                    yPosition -= 30
                }

                yPosition = drawSection(section, yPosition: yPosition, pageRect: pageRect, margins: pageMargins, maxWidth: maxWidth)
            }
        }

        do {
            try data.write(to: pdfURL)
            return pdfURL
        } catch {
            return nil
        }
    }

    /// Parse markdown into structured sections
    private func parseMarkdownSections(_ markdown: String) -> [MarkdownSection] {
        var sections: [MarkdownSection] = []
        var currentSection: MarkdownSection?
        var currentContent: [String] = []

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)

            // Skip navigation lines
            if trimmed.hasPrefix("> ← Prev:") || trimmed.hasPrefix("> Part of") || trimmed.hasPrefix("> Stroke guide:") {
                continue
            }

            // Skip horizontal rules
            if trimmed == "---" {
                if let section = currentSection, !currentContent.isEmpty {
                    section.content = currentContent.joined(separator: "\n")
                    sections.append(section)
                }
                currentContent = []
                continue
            }

            // Detect section headers
            if trimmed.hasPrefix("# ") {
                // Title header - save previous and start new
                if let section = currentSection, !currentContent.isEmpty {
                    section.content = currentContent.joined(separator: "\n")
                    sections.append(section)
                }
                let title = String(trimmed.dropFirst(2))
                currentSection = MarkdownSection(type: .title, header: title)
                currentContent = []
            } else if trimmed.hasPrefix("## ") {
                // Section header
                if let section = currentSection, !currentContent.isEmpty {
                    section.content = currentContent.joined(separator: "\n")
                    sections.append(section)
                }
                let header = String(trimmed.dropFirst(3))
                let sectionType = MarkdownSectionType.fromHeader(header)
                currentSection = MarkdownSection(type: sectionType, header: header)
                currentContent = []
            } else if trimmed.hasPrefix("#### ") {
                // Sub-section header (drill name)
                let header = String(trimmed.dropFirst(5))
                currentContent.append("### \(header)")
            } else if !trimmed.isEmpty {
                currentContent.append(String(line))
            }
        }

        // Add final section
        if let section = currentSection {
            section.content = currentContent.joined(separator: "\n")
            sections.append(section)
        }

        return sections
    }

    /// Estimate height needed for a section
    private func estimateSectionHeight(_ section: MarkdownSection, maxWidth: CGFloat) -> CGFloat {
        let headerHeight: CGFloat = 30
        let lineHeight: CGFloat = 18
        let bulletHeight: CGFloat = 22

        let lines = section.content.split(separator: "\n")
        var height = headerHeight

        for line in lines {
            if line.hasPrefix("- ") {
                height += bulletHeight
            } else if line.hasPrefix("|") {
                height += 30 // Table row
            } else if line.hasPrefix(">") {
                height += 25 // Callout
            } else {
                height += lineHeight
            }
        }

        return min(height, 600) // Cap at reasonable max
    }

    /// Draw a section to the PDF context
    private func drawSection(_ section: MarkdownSection, yPosition: CGFloat, pageRect: CGRect, margins: UIEdgeInsets, maxWidth: CGFloat) -> CGFloat {
        var y = yPosition

        switch section.type {
        case .title:
            y = drawTitle(section.header, yPosition: y, margins: margins)
            if !section.content.isEmpty {
                y -= 10
                y = drawContent(section.content, yPosition: y, pageRect: pageRect, margins: margins, maxWidth: maxWidth)
            }

        case .overview:
            y = drawSectionHeader("Overview", yPosition: y, margins: margins)
            y -= 5
            y = drawContent(section.content, yPosition: y, pageRect: pageRect, margins: margins, maxWidth: maxWidth)
            y -= 15

        case .keyPoints:
            y = drawSectionHeader("Key Points to Remember", yPosition: y, margins: margins)
            y -= 5
            y = drawBulletList(section.content, yPosition: y, pageRect: pageRect, margins: margins, bullet: "✓", color: UIColor.systemBlue)
            y -= 15

        case .mistakes:
            y = drawSectionHeader("Common Mistakes to Avoid", yPosition: y, margins: margins)
            y -= 5
            y = drawBulletList(section.content, yPosition: y, pageRect: pageRect, margins: margins, bullet: "✗", color: UIColor.systemRed)
            y -= 15

        case .drills:
            y = drawSectionHeader("Specific Drills", yPosition: y, margins: margins)
            y -= 5
            y = drawTable(section.content, yPosition: y, pageRect: pageRect, margins: margins)
            y -= 15

        case .competitive:
            y = drawSectionHeader("Competitive Metrics", yPosition: y, margins: margins)
            y -= 5
            y = drawCompetitiveMetrics(section.content, yPosition: y, pageRect: pageRect, margins: margins)
            y -= 15

        case .related:
            y = drawSectionHeader("Related Techniques", yPosition: y, margins: margins)
            y -= 5
            y = drawBulletList(section.content, yPosition: y, pageRect: pageRect, margins: margins, bullet: "→", color: UIColor.systemTeal)
            y -= 15

        default:
            y = drawSectionHeader(section.header, yPosition: y, margins: margins)
            y -= 5
            y = drawContent(section.content, yPosition: y, pageRect: pageRect, margins: margins, maxWidth: maxWidth)
            y -= 15
        }

        return y
    }

    /// Draw page header for continuation pages
    private func drawPageHeader(title: String, pageNumber: Int, yPosition: CGFloat, pageRect: CGRect, margins: UIEdgeInsets) {
        let font = UIFont.systemFont(ofSize: 10, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.secondaryLabel]
        let text = "\(title) — Page \(pageNumber)"
        NSAttributedString(string: text, attributes: attrs).draw(at: CGPoint(x: margins.left, y: yPosition))
    }

    /// Draw title section
    private func drawTitle(_ title: String, yPosition: CGFloat, margins: UIEdgeInsets) -> CGFloat {
        var y = yPosition

        // Main title
        let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.systemBlue]
        NSAttributedString(string: title, attributes: titleAttrs).draw(at: CGPoint(x: margins.left, y: y))
        y -= 35

        // Underline
        let underlinePath = UIBezierPath()
        underlinePath.move(to: CGPoint(x: margins.left, y: y))
        underlinePath.addLine(to: CGPoint(x: margins.left + 200, y: y))
        UIColor.systemBlue.setStroke()
        underlinePath.lineWidth = 2
        underlinePath.stroke()
        y -= 15

        return y
    }

    /// Draw section header
    private func drawSectionHeader(_ header: String, yPosition: CGFloat, margins: UIEdgeInsets) -> CGFloat {
        var y = yPosition

        let font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label]
        NSAttributedString(string: header, attributes: attrs).draw(at: CGPoint(x: margins.left, y: y))
        y -= 8

        // Light underline
        let underlinePath = UIBezierPath()
        underlinePath.move(to: CGPoint(x: margins.left, y: y))
        underlinePath.addLine(to: CGPoint(x: margins.left + 150, y: y))
        UIColor.systemGray4.setStroke()
        underlinePath.lineWidth = 1
        underlinePath.stroke()
        y -= 12

        return y
    }

    /// Draw general content text with markdown formatting
    private func drawContent(_ content: String, yPosition: CGFloat, pageRect: CGRect, margins: UIEdgeInsets, maxWidth: CGFloat) -> CGFloat {
        var y = yPosition

        // Clean and format content
        var text = content
        // Remove wiki link brackets but keep content
        text = text.replacingOccurrences(of: "\\[\\[([^\\]]+)\\]\\]", with: "$1", options: .regularExpression)
        // Handle bold: **text**
        text = text.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)

        // Split into paragraphs
        let paragraphs = text.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        let font = UIFont.systemFont(ofSize: 13, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label]

        for paragraph in paragraphs {
            if y < margins.bottom + 20 { break }

            let attrString = NSAttributedString(string: paragraph, attributes: attrs)
            let textSize = attrString.boundingRect(
                with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size

            attrString.draw(in: CGRect(x: margins.left, y: y - textSize.height, width: maxWidth, height: textSize.height + 5))
            y -= textSize.height + 12
        }

        return y
    }

    /// Draw bullet list with custom bullet character
    private func drawBulletList(_ content: String, yPosition: CGFloat, pageRect: CGRect, margins: UIEdgeInsets, bullet: String, color: UIColor) -> CGFloat {
        var y = yPosition

        let lines = content.split(separator: "\n")
        let bulletItems = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("- ") }

        let bulletFont = UIFont.systemFont(ofSize: 14, weight: .regular)

        for item in bulletItems {
            if y < margins.bottom + 30 { break }

            let text = String(item).trimmingCharacters(in: .whitespaces).dropFirst(2)

            // Parse bold text at beginning: **text** rest
            var displayText = String(text)
            displayText = displayText.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)

            // Draw bullet
            let bulletAttrs: [NSAttributedString.Key: Any] = [.font: bulletFont, .foregroundColor: color]
            NSAttributedString(string: bullet, attributes: bulletAttrs).draw(at: CGPoint(x: margins.left + 10, y: y - 5))
            y -= 5

            // Draw text
            let textAttrs: [NSAttributedString.Key: Any] = [.font: bulletFont, .foregroundColor: UIColor.label]
            let attrString = NSAttributedString(string: displayText, attributes: textAttrs)
            let textSize = attrString.boundingRect(
                with: CGSize(width: pageRect.width - margins.left - margins.right - 40, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).size

            attrString.draw(in: CGRect(x: margins.left + 35, y: y - textSize.height, width: textSize.width + 5, height: textSize.height + 5))
            y -= textSize.height + 12
        }

        return y
    }

    /// Draw markdown table
    private func drawTable(_ content: String, yPosition: CGFloat, pageRect: CGRect, margins: UIEdgeInsets) -> CGFloat {
        var y = yPosition

        let lines = content.split(separator: "\n")
        let tableRows = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("|") && !$0.contains("---") }

        guard tableRows.count >= 2 else { return y }

        // Draw table header
        let headerLine = tableRows[0]
        let headers = headerLine.dropFirst(1).dropLast(1).split(separator: "|")

        let headerFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: UIColor.systemBlue]

        // Table dimensions
        let tableWidth = pageRect.width - margins.left - margins.right - 20
        let colWidth = tableWidth / CGFloat(headers.count)
        let rowHeight: CGFloat = 35

        // Draw header row background
        let headerRect = CGRect(x: margins.left, y: y - rowHeight, width: tableWidth, height: rowHeight)
        UIColor.systemGray5.setFill()
        UIRectFill(headerRect)

        for (index, header) in headers.enumerated() {
            let x = margins.left + CGFloat(index) * colWidth + 5
            var headerText = String(header).trimmingCharacters(in: .whitespaces)
            headerText = headerText.replacingOccurrences(of: "\\*\\*", with: "", options: .regularExpression)
            NSAttributedString(string: headerText, attributes: headerAttrs).draw(at: CGPoint(x: x, y: y - 25))
        }
        y -= rowHeight

        // Draw data rows
        let cellFont = UIFont.systemFont(ofSize: 11, weight: .regular)
        let cellAttrs: [NSAttributedString.Key: Any] = [.font: cellFont, .foregroundColor: UIColor.label]

        for rowIndex in 1..<tableRows.count {
            if y < margins.bottom + 50 { break }

            let row = tableRows[rowIndex]
            let cells = row.dropFirst(1).dropLast(1).split(separator: "|")

            // Draw row background (alternating)
            if rowIndex % 2 == 0 {
                let rowRect = CGRect(x: margins.left, y: y - rowHeight, width: tableWidth, height: rowHeight)
                UIColor.systemGray6.setFill()
                UIRectFill(rowRect)
            }

            for (index, cell) in cells.enumerated() {
                let x = margins.left + CGFloat(index) * colWidth + 5
                var cellText = String(cell).trimmingCharacters(in: .whitespaces)
                cellText = cellText.replacingOccurrences(of: "\\*\\*", with: "", options: .regularExpression)
                cellText = cellText.replacingOccurrences(of: "\\[\\[([^\\]]+)\\]\\]", with: "$1", options: .regularExpression)

                let attrString = NSAttributedString(string: cellText, attributes: cellAttrs)
                attrString.draw(in: CGRect(x: x, y: y - rowHeight + 5, width: colWidth - 10, height: rowHeight - 10))
            }

            y -= rowHeight
        }

        return y
    }

    /// Draw competitive metrics with tiered targets
    private func drawCompetitiveMetrics(_ content: String, yPosition: CGFloat, pageRect: CGRect, margins: UIEdgeInsets) -> CGFloat {
        var y = yPosition

        // Split by drill headers (#### Drill)
        let drillSections = content.split(separator: "####").map { String($0) }.filter { !$0.isEmpty }

        let drillNameFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let drillNameAttrs: [NSAttributedString.Key: Any] = [.font: drillNameFont, .foregroundColor: UIColor.systemBlue]

        let tierFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        let tierAttrs: [NSAttributedString.Key: Any] = [.font: tierFont, .foregroundColor: UIColor.label]

        let noteFont = UIFont.systemFont(ofSize: 10, weight: .regular)
        let noteAttrs: [NSAttributedString.Key: Any] = [.font: noteFont, .foregroundColor: UIColor.secondaryLabel]

        for drillSection in drillSections {
            if y < margins.bottom + 100 { break }

            let lines = drillSection.split(separator: "\n")

            // Drill name (first line)
            if let firstLine = lines.first {
                let drillName = String(firstLine).trimmingCharacters(in: .whitespaces)
                // Extract drill name from " Drill N: Name"
                let name = drillName.replacingOccurrences(of: "^[\\s]*Drill [\\d]+:\\s*", with: "", options: .regularExpression)
                NSAttributedString(string: name, attributes: drillNameAttrs).draw(at: CGPoint(x: margins.left, y: y))
                y -= 20
            }

            // Self-check
            for line in lines {
                let trimmed = String(line).trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("**Self-Check:**") {
                    let checkText = trimmed.replacingOccurrences(of: "\\*\\*Self-Check:\\*\\*\\s*", with: "Self-check: ", options: .regularExpression)
                    NSAttributedString(string: checkText, attributes: noteAttrs).draw(at: CGPoint(x: margins.left + 10, y: y))
                    y -= 15
                }
            }

            // Tiered targets (look for > [!note] Tiered Targets block)
            var inTierBlock = false
            for line in lines {
                let trimmed = String(line).trimmingCharacters(in: .whitespaces)

                if trimmed.contains("Tiered Targets") || trimmed.hasPrefix("> -") {
                    inTierBlock = true

                    if trimmed.hasPrefix("> - **") {
                        // Parse tier line: > - **Beginner:** target
                        let tierLineRaw = trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces).dropFirst(2)
                        let tierLine = String(tierLineRaw).replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)

                        NSAttributedString(string: "  \(tierLine)", attributes: tierAttrs).draw(at: CGPoint(x: margins.left + 10, y: y))
                        y -= 14
                    }
                } else if inTierBlock && !trimmed.hasPrefix(">") {
                    inTierBlock = false
                }
            }

            // Competitive impact
            for line in lines {
                let trimmed = String(line).trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("**Competitive Impact:**") {
                    let impactText = trimmed.replacingOccurrences(of: "\\*\\*Competitive Impact:\\*\\*\\s*", with: "Impact: ", options: .regularExpression)
                    let attrString = NSAttributedString(string: impactText, attributes: noteAttrs)
                    let textSize = attrString.boundingRect(
                        with: CGSize(width: pageRect.width - margins.left - margins.right - 20, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin],
                        context: nil
                    ).size
                    attrString.draw(in: CGRect(x: margins.left + 10, y: y - textSize.height, width: textSize.width + 10, height: textSize.height + 5))
                    y -= textSize.height + 10
                }
            }

            y -= 15
        }

        return y
    }
}

/// Markdown section types
enum MarkdownSectionType {
    case title
    case overview
    case keyPoints
    case mistakes
    case drills
    case competitive
    case related
    case other

    static func fromHeader(_ header: String) -> MarkdownSectionType {
        let lowercased = header.lowercased()
        if lowercased.contains("overview") { return .overview }
        if lowercased.contains("key points") { return .keyPoints }
        if lowercased.contains("mistakes") { return .mistakes }
        if lowercased.contains("specific drills") { return .drills }
        if lowercased.contains("competitive metrics") { return .competitive }
        if lowercased.contains("related") { return .related }
        return .other
    }
}

/// Represents a parsed markdown section
class MarkdownSection {
    var type: MarkdownSectionType
    var header: String
    var content: String

    init(type: MarkdownSectionType, header: String, content: String = "") {
        self.type = type
        self.header = header
        self.content = content
    }
}