import SwiftUI
import UIKit

/// "Share your plan": a fitted bottom sheet with Save as PDF (to Files) and
/// Send or share (the system share sheet with the same PDF), then Cancel.
struct SharePlanSheet: View {
    let plan: Plan
    let workouts: [Workout]
    let units: Units

    @Environment(\.dismiss) private var dismiss
    @State private var pdf: URL?
    @State private var saving: URL?
    @State private var height: CGFloat = 320

    private var runs: Int { workouts.filter { !$0.isRest }.count }
    private var weeks: Int { Set(workouts.map(\.week)).count }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Share your plan")
                    .font(.heroTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("\(plan.displayName) · \(weeks) weeks · \(runs) runs")
                    .font(.detail)
                    .foregroundStyle(.muted)
            }

            VStack(spacing: 0) {
                Button {
                    // Moving hands the file over, so save a fresh copy.
                    saving = PlanPDF.make(plan: plan, workouts: workouts, units: units)
                    Analytics.track("plan_shared", ["method": "pdf"])
                } label: {
                    row("doc.text", "Save as PDF", "A printable, week-by-week copy")
                }
                .buttonStyle(.haptic)

                Divider().padding(.leading, RowMetrics.horizontalPadding + 32 + RowMetrics.spacing)

                if let pdf {
                    ShareLink(item: pdf) {
                        row("square.and.arrow.up", "Send or share…", "Email, Messages, AirDrop and more")
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        Haptics.tap()
                        Analytics.track("plan_shared", ["method": "share"])
                    })
                } else {
                    row("square.and.arrow.up", "Send or share…", "Email, Messages, AirDrop and more")
                        .opacity(0.4)
                }
            }
            .background(Color.wash, in: .rect(cornerRadius: Radius.control))

            SecondaryButton("Cancel") { dismiss() }
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.top, Spacing.xxxl)
        .padding(.bottom, Spacing.l)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.surface)
        .fileMover(isPresented: Binding(get: { saving != nil }, set: { if !$0 { saving = nil } }), file: saving) { result in
            if case .success = result {
                Haptics.success()
                dismiss()
            }
        }
        .task { pdf = PlanPDF.make(plan: plan, workouts: workouts, units: units) }
        .onAppear { Analytics.screen("Share Plan") }
    }

    private func row(_ icon: String, _ title: LocalizedStringKey, _ subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: RowMetrics.spacing) {
            Image(systemName: icon)
                .font(.footnote.weight(.bold))
                .frame(width: 32, height: 32)
                .background(Color.surface, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(.rowTitle)
                Text(subtitle).font(.detail).foregroundStyle(.muted)
            }
            Spacer(minLength: Spacing.s)
        }
        .foregroundStyle(.ink)
        .padding(.horizontal, RowMetrics.horizontalPadding)
        .padding(.vertical, Spacing.m)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// Draws the plan as a printable, week-by-week PDF (US Letter): the goal
/// and dates up top, then each week's days with workout, amount and what
/// to do. Weeks never split across pages.
enum PlanPDF {
    static func make(plan: Plan, workouts: [Workout], units: Units) -> URL? {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 48
        let width = page.width - margin * 2
        let rowHeight: CGFloat = 18

        let weeks = Dictionary(grouping: workouts, by: \.week).sorted { $0.key < $1.key }
        let ink = UIColor(red: 0x15 / 255, green: 0x18 / 255, blue: 0x1D / 255, alpha: 1)
        let muted = UIColor(red: 0x66 / 255, green: 0x69 / 255, blue: 0x70 / 255, alpha: 1)
        func attrs(_ size: CGFloat, _ weight: UIFont.Weight, _ color: UIColor = ink, italic: Bool = false) -> [NSAttributedString.Key: Any] {
            var font = UIFont.systemFont(ofSize: size, weight: weight)
            if italic, let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
                font = UIFont(descriptor: descriptor, size: size)
            }
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byTruncatingTail
            return [.font: font, .foregroundColor: color, .paragraphStyle: style]
        }

        let name = plan.displayName.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("Kiki plan - \(name).pdf")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let renderer = UIGraphicsPDFRenderer(bounds: page)
        do {
            try renderer.writePDF(to: url) { context in
                var y: CGFloat = 0
                func newPage() {
                    context.beginPage()
                    y = margin
                    ("Kiki" as NSString).draw(at: CGPoint(x: margin, y: page.height - margin + 12), withAttributes: attrs(9, .black, muted, italic: true))
                    ("kikirunning.com" as NSString).draw(at: CGPoint(x: page.width - margin - 70, y: page.height - margin + 12), withAttributes: attrs(9, .regular, muted))
                }

                newPage()
                (plan.displayName as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(24, .bold))
                y += 32
                let runs = workouts.filter { !$0.isRest }.count
                let subtitle = "\(Format.shortDate(plan.startDate)) – \(plan.raceDate.date.formatted(.dateTime.month(.abbreviated).day().year())) · \(weeks.count) weeks · \(runs) runs"
                (subtitle as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(11, .regular, muted))
                y += 32

                for (week, days) in weeks {
                    let sorted = days.sorted { $0.date < $1.date }
                    let blockHeight = 22 + CGFloat(sorted.count) * rowHeight + 16
                    if y + blockHeight > page.height - margin { newPage() }

                    let meters = sorted.filter { !$0.isRest }.compactMap(\.distanceM).reduce(0, +)
                    let range = sorted.first.map { weekRange($0.date, sorted.last?.date ?? $0.date) } ?? ""
                    ("Week \(week)" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(13, .bold))
                    let detail = meters > 0 ? "\(range) · \(Format.distance(Double(meters), units))" : range
                    (detail as NSString).draw(at: CGPoint(x: margin + 70, y: y + 1.5), withAttributes: attrs(10, .regular, muted))
                    y += 20
                    context.cgContext.setFillColor(muted.withAlphaComponent(0.25).cgColor)
                    context.cgContext.fill(CGRect(x: margin, y: y, width: width, height: 0.5))
                    y += 4

                    for workout in sorted {
                        let day = workout.date.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        (day as NSString).draw(in: CGRect(x: margin, y: y, width: 80, height: rowHeight), withAttributes: attrs(10, .regular, muted))
                        let title = workout.isRest ? "Rest" : workout.title + (workout.status == .completed ? "  ✓" : "")
                        (title as NSString).draw(in: CGRect(x: margin + 84, y: y, width: 130, height: rowHeight),
                                                 withAttributes: attrs(10, workout.isRest ? .regular : .semibold, workout.isRest ? muted : ink))
                        let amount = workout.distanceM.map { Format.distance(Double($0), units) }
                            ?? workout.durationS.map { Format.minutes($0) } ?? ""
                        (amount as NSString).draw(in: CGRect(x: margin + 218, y: y, width: 60, height: rowHeight), withAttributes: attrs(10, .regular))
                        if !workout.isRest {
                            (workout.description as NSString).draw(in: CGRect(x: margin + 282, y: y, width: width - 282, height: rowHeight),
                                                                   withAttributes: attrs(9, .regular, muted))
                        }
                        y += rowHeight
                    }
                    y += 16
                }
            }
            return url
        } catch {
            Analytics.captureError(error, context: ["step": "plan_pdf"])
            return nil
        }
    }

    /// "Oct 5 – 11", or "Sep 29 – Oct 5" across months.
    static func weekRange(_ start: Day, _ end: Day) -> String {
        let first = Format.shortDate(start)
        let last = start.month == end.month ? "\(end.day)" : Format.shortDate(end)
        return "\(first) – \(last)"
    }
}
