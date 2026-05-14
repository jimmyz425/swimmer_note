import CoreText
import SwiftUI
import UIKit

// MARK: - Share sheet

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Identifiable URL for sheets

struct ShareableFile: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - PDF export

enum WeeklyTrainingPlanPDFExporter {
    private static let pageSize = CGSize(width: 612, height: 792)
    private static let margin: CGFloat = 48

    static func pdfData(for plan: WeeklyTrainingPlan) -> Data {
        let attributed = Self.attributedDocument(for: plan)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "SwimNote Training Plan",
            kCGPDFContextCreator as String: "SwimNote",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        return renderer.pdfData { context in
            let textRect = CGRect(
                x: Self.margin,
                y: Self.margin,
                width: Self.pageSize.width - Self.margin * 2,
                height: Self.pageSize.height - Self.margin * 2
            )
            let path = CGPath(rect: textRect, transform: nil)
            let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
            var location = 0

            while location < attributed.length {
                context.beginPage()
                let cg = context.cgContext
                cg.saveGState()
                cg.textMatrix = .identity
                cg.translateBy(x: 0, y: Self.pageSize.height)
                cg.scaleBy(x: 1, y: -1)

                let range = CFRange(location: location, length: 0)
                let frame = CTFramesetterCreateFrame(framesetter, range, path, nil)
                CTFrameDraw(frame, cg)

                let visible = CTFrameGetVisibleStringRange(frame)
                if visible.length == 0 {
                    cg.restoreGState()
                    break
                }
                location += visible.length
                cg.restoreGState()
            }
        }
    }

    static func suggestedFileURL(for plan: WeeklyTrainingPlan) -> URL {
        let week = plan.weekStartingDate.map { SwimNoteDateFormatting.shortDateString(from: $0) } ?? "week"
        let sanitized = week.replacingOccurrences(of: "/", with: "-")
        return FileManager.default.temporaryDirectory.appendingPathComponent("SwimNote-Plan-\(sanitized).pdf")
    }

    // MARK: - Attributed text

    private static func attributedDocument(for plan: WeeklyTrainingPlan) -> NSAttributedString {
        let body = UIFont.systemFont(ofSize: 11, weight: .regular)
        let bodyBold = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
        let headingFont = UIFont.systemFont(ofSize: 14, weight: .bold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 6
        paragraph.lineSpacing = 2

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: body,
            .paragraphStyle: paragraph,
        ]
        let boldAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyBold,
            .paragraphStyle: paragraph,
        ]

        let out = NSMutableAttributedString()

        func appendTitle(_ text: String) {
            let p = NSMutableParagraphStyle()
            p.paragraphSpacing = 10
            out.append(NSAttributedString(string: text + "\n", attributes: [.font: titleFont, .paragraphStyle: p]))
        }

        func appendHeading(_ text: String) {
            let p = NSMutableParagraphStyle()
            p.paragraphSpacingBefore = 10
            p.paragraphSpacing = 4
            out.append(NSAttributedString(string: text + "\n", attributes: [.font: headingFont, .paragraphStyle: p]))
        }

        func appendBody(_ text: String) {
            out.append(NSAttributedString(string: text + "\n", attributes: bodyAttrs))
        }

        func appendBulletList(_ items: [String], prefix: String = "• ") {
            for item in items where !item.isEmpty {
                out.append(NSAttributedString(string: "\(prefix)\(item)\n", attributes: bodyAttrs))
            }
        }

        func appendSegment(title: String, segment: SessionSegment) {
            out.append(NSAttributedString(string: "\(title) (\(segment.distance))\n", attributes: boldAttrs))
            if let sets = segment.sets, !sets.isEmpty {
                for s in sets {
                    out.append(NSAttributedString(string: "  \(s.formatted)\n", attributes: bodyAttrs))
                }
            } else {
                out.append(NSAttributedString(string: "  \(segment.description)\n", attributes: bodyAttrs))
                if let drills = segment.drills, !drills.isEmpty {
                    for d in drills {
                        out.append(NSAttributedString(string: "  • \(d)\n", attributes: bodyAttrs))
                    }
                }
            }
        }

        appendTitle("Weekly Training Plan")
        appendBody("Week: \(weekRangeLabel(for: plan))")
        if let pool = plan.overview.poolType ?? plan.poolTypeRaw {
            appendBody("Pool: \(pool)")
        }
        appendBody("Sessions: \(plan.detailedSessions.count)")
        if let dist = plan.overview.totalDistance, !dist.isEmpty {
            appendBody("Planned distance (overview): \(dist)")
        }
        appendBody("")

        if let summary = plan.overview.swimmerSummary, !summary.isEmpty {
            appendHeading("Swimmer summary")
            appendBody(summary)
        }

        appendHeading("Week focus")
        appendBody(plan.overview.weekFocus)

        if let past = plan.overview.pastMonthAnalysis, !past.isEmpty {
            appendHeading("Past month")
            appendBody(past)
        }

        if let t = plan.overview.technicalObjective, !t.isEmpty {
            appendHeading("Technical objective")
            appendBody(t)
        }
        if let p = plan.overview.physicalObjective, !p.isEmpty {
            appendHeading("Physical objective")
            appendBody(p)
        }

        if let tp = plan.techniqueProgressPlan {
            appendHeading("Technique progress")
            if !tp.continueGoals.isEmpty {
                out.append(NSAttributedString(string: "Continuing\n", attributes: boldAttrs))
                appendBulletList(tp.continueGoals)
            }
            if !tp.achievedGoalsNextLevel.isEmpty {
                out.append(NSAttributedString(string: "Achieved → next level\n", attributes: boldAttrs))
                appendBulletList(tp.achievedGoalsNextLevel)
            }
            if !tp.revisitGoals.isEmpty {
                out.append(NSAttributedString(string: "Revisit\n", attributes: boldAttrs))
                appendBulletList(tp.revisitGoals)
            }
            if !tp.newGoals.isEmpty {
                out.append(NSAttributedString(string: "New\n", attributes: boldAttrs))
                appendBulletList(tp.newGoals)
            }
            if let fund = tp.fundamentalRevisitGoals, !fund.isEmpty {
                out.append(NSAttributedString(string: "Fundamentals\n", attributes: boldAttrs))
                appendBulletList(fund)
            }
        }

        if let goals = plan.weeklyGoals, !goals.isEmpty {
            appendHeading("Weekly goals")
            for g in goals {
                var line = "\(g.metric): \(g.target)"
                if let m = g.measurementMethod, !m.isEmpty { line += " (\(m))" }
                appendBody(line)
            }
        }

        if !plan.schedule.isEmpty {
            appendHeading("Schedule overview")
            for day in plan.schedule.sorted(by: { $0.sessionNumber < $1.sessionNumber }) {
                var line = "Session \(day.sessionNumber): \(day.poolSession) — \(day.focus)"
                if let d = day.duration, !d.isEmpty { line += " (\(d))" }
                appendBody(line)
            }
        }

        for session in plan.detailedSessions.sorted(by: { $0.sessionNumber < $1.sessionNumber }) {
            appendHeading("Session \(session.sessionNumber): \(session.focus)")
            if let date = session.scheduledDate {
                appendBody("Date: \(SwimNoteDateFormatting.shortDateString(from: date))")
            }
            if let tod = session.timeOfDay {
                appendBody("Time: \(tod.displayName)")
            }
            if !session.techniqueFocus.isEmpty {
                appendBody("Technique: \(session.techniqueFocus)")
            }
            if let g = session.addressesGoal, !g.isEmpty {
                appendBody("Goal link: \(g)")
            }
            appendSegment(title: "Warm-up", segment: session.warmUp)
            appendSegment(title: "Drills", segment: session.drillSet)
            if let sec = session.secondarySet {
                appendSegment(title: "Secondary", segment: sec)
            }
            appendSegment(title: "Main set", segment: session.mainSet)
            appendSegment(title: "Cool-down", segment: session.coolDown)
            if let r = session.progressionRationale, !r.isEmpty {
                out.append(NSAttributedString(string: "Progression\n", attributes: boldAttrs))
                appendBody(r)
            }
            if let n = session.sessionNotes, !n.isEmpty {
                out.append(NSAttributedString(string: "Session notes\n", attributes: boldAttrs))
                appendBody(n)
            }
            appendBody("")
        }

        if let dry = plan.dryLandProgram, !dry.isEmpty {
            appendHeading("Dry land")
            for ex in dry {
                var line = "\(ex.exercise) — \(ex.setsReps)"
                if let f = ex.focus, !f.isEmpty { line += " — \(f)" }
                appendBody(line)
                if let t = ex.techniqueSupport, !t.isEmpty {
                    appendBody("  \(t)")
                }
            }
        }

        if !plan.notes.isEmpty {
            appendHeading("Coach notes")
            appendBody(plan.notes)
        }

        return out
    }

    private static func weekRangeLabel(for plan: WeeklyTrainingPlan) -> String {
        guard let startDate = plan.weekStartingDate else { return "Unknown week" }
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 6, to: startDate) ?? startDate
        return "\(DateFormatter.shortMonthDay.string(from: startDate)) – \(DateFormatter.shortMonthDay.string(from: endDate))"
    }
}
