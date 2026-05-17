import SwiftUI

struct ValuesRadarCard: View {
    let brought: [Value]
    let sought: [Value]

    private var axes: [String] {
        let union = Set(brought.map(\.category)).union(sought.map(\.category))
        return union.sorted()
    }

    private func count(in values: [Value], category: String) -> Int {
        values.filter { $0.category == category }.count
    }

    private let maxPerAxis: Double = 5

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                Text("Your Values Map")
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)

                if axes.isEmpty {
                    Text("Pick a few values to see your map.")
                        .font(HarvestTheme.Typography.bodySmall)
                        .foregroundStyle(HarvestTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    GeometryReader { geo in
                        let size = min(geo.size.width, geo.size.height)
                        let center = CGPoint(x: geo.size.width / 2, y: size / 2)
                        let radius = (size / 2) - 32

                        Canvas { context, _ in
                            drawGrid(context: context, center: center, radius: radius)
                            drawAxisLabels(context: context, center: center, radius: radius)
                            drawPolygon(
                                context: context,
                                center: center,
                                radius: radius,
                                counts: axes.map { count(in: sought, category: $0) },
                                stroke: HarvestTheme.Colors.accent,
                                fill: HarvestTheme.Colors.accent.opacity(0.3)
                            )
                            drawPolygon(
                                context: context,
                                center: center,
                                radius: radius,
                                counts: axes.map { count(in: brought, category: $0) },
                                stroke: HarvestTheme.Colors.primary,
                                fill: HarvestTheme.Colors.primary.opacity(0.3)
                            )
                        }
                    }
                    .frame(height: 280)

                    HStack(spacing: HarvestTheme.Spacing.lg) {
                        legendDot(color: HarvestTheme.Colors.primary, label: "I Bring")
                        legendDot(color: HarvestTheme.Colors.accent, label: "I Seek")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
                .font(HarvestTheme.Typography.caption)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
        }
    }

    private func axisPoint(center: CGPoint, radius: Double, index: Int, magnitude: Double) -> CGPoint {
        let angle = (2 * .pi * Double(index) / Double(axes.count)) - .pi / 2
        let r = radius * (magnitude / maxPerAxis)
        return CGPoint(
            x: center.x + CGFloat(r * cos(angle)),
            y: center.y + CGFloat(r * sin(angle))
        )
    }

    private func drawGrid(context: GraphicsContext, center: CGPoint, radius: Double) {
        let gridColor = HarvestTheme.Colors.textSecondary.opacity(0.25)

        for step in 1...5 {
            var path = Path()
            for i in 0..<axes.count {
                let p = axisPoint(center: center, radius: radius, index: i, magnitude: Double(step))
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }

        for i in 0..<axes.count {
            var path = Path()
            path.move(to: center)
            path.addLine(to: axisPoint(center: center, radius: radius, index: i, magnitude: maxPerAxis))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }
    }

    private func drawAxisLabels(context: GraphicsContext, center: CGPoint, radius: Double) {
        for (i, axis) in axes.enumerated() {
            let labelPoint = axisPoint(center: center, radius: radius + 18, index: i, magnitude: maxPerAxis)
            let text = Text(axis.capitalized)
                .font(HarvestTheme.Typography.caption)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
            context.draw(text, at: labelPoint, anchor: .center)
        }
    }

    private func drawPolygon(
        context: GraphicsContext,
        center: CGPoint,
        radius: Double,
        counts: [Int],
        stroke: Color,
        fill: Color
    ) {
        guard !counts.isEmpty else { return }
        var path = Path()
        for (i, count) in counts.enumerated() {
            let p = axisPoint(center: center, radius: radius, index: i, magnitude: Double(count))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        context.fill(path, with: .color(fill))
        context.stroke(path, with: .color(stroke), lineWidth: 1.5)
    }
}

#Preview("Values Radar - mixed") {
    ValuesRadarCard(
        brought: [
            Value(id: "1", name: "Honesty", category: "communication", displayOrder: 0),
            Value(id: "2", name: "Adventure", category: "lifestyle", displayOrder: 0),
            Value(id: "3", name: "Family", category: "social", displayOrder: 0)
        ],
        sought: [
            Value(id: "4", name: "Empathy", category: "communication", displayOrder: 0),
            Value(id: "5", name: "Ambition", category: "lifestyle", displayOrder: 0)
        ]
    )
    .padding()
    .background(HarvestTheme.Colors.background)
}

#Preview("Values Radar - empty") {
    ValuesRadarCard(brought: [], sought: [])
        .padding()
        .background(HarvestTheme.Colors.background)
}
