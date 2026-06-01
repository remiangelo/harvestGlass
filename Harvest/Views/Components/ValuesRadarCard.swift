import SwiftUI

struct ValuesRadarCard: View {
    let primary: AxisScores
    let primaryLabel: String
    let secondary: AxisScores?
    let secondaryLabel: String?
    let onEmptyTap: (() -> Void)?

    init(
        primary: AxisScores,
        primaryLabel: String,
        secondary: AxisScores? = nil,
        secondaryLabel: String? = nil,
        onEmptyTap: (() -> Void)? = nil
    ) {
        self.primary = primary
        self.primaryLabel = primaryLabel
        self.secondary = secondary
        self.secondaryLabel = secondaryLabel
        self.onEmptyTap = onEmptyTap
    }

    private let axes: [ValueAxis] = [
        .emotionalIntelligence,
        .stability,
        .integrity,
        .connection,
        .growth
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: HarvestTheme.Spacing.md) {
                Text("Your Values Map")
                    .font(HarvestTheme.Typography.h4)
                    .foregroundStyle(HarvestTheme.Colors.textPrimary)

                if primary.isZero && (secondary?.isZero ?? true) {
                    emptyState
                } else {
                    chart
                    legend
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: HarvestTheme.Spacing.sm) {
            Image(systemName: "chart.dots.scatter")
                .font(.system(size: 32))
                .foregroundStyle(HarvestTheme.Colors.accent)
            Text("Answer a few questions to map your values.")
                .font(HarvestTheme.Typography.bodyRegular)
                .multilineTextAlignment(.center)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
            if let onEmptyTap {
                Button(action: onEmptyTap) {
                    Text("Start")
                }
                .buttonStyle(.harvestGlass(.primary))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private var chart: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: size / 2)
            let radius = (size / 2) - 32

            Canvas { context, _ in
                drawGrid(context: context, center: center, radius: radius)
                drawAxisLabels(context: context, center: center, radius: radius)
                if let secondary, !secondary.isZero {
                    drawPolygon(
                        context: context,
                        center: center,
                        radius: radius,
                        scores: secondary,
                        stroke: HarvestTheme.Colors.accent,
                        fill: HarvestTheme.Colors.accent.opacity(0.3)
                    )
                }
                if !primary.isZero {
                    drawPolygon(
                        context: context,
                        center: center,
                        radius: radius,
                        scores: primary,
                        stroke: HarvestTheme.Colors.primary,
                        fill: HarvestTheme.Colors.primary.opacity(0.3)
                    )
                }
            }
        }
        .frame(height: 280)
    }

    @ViewBuilder
    private var legend: some View {
        if let secondary, !secondary.isZero, let secondaryLabel {
            HStack(spacing: HarvestTheme.Spacing.lg) {
                legendDot(color: HarvestTheme.Colors.primary, label: primaryLabel)
                legendDot(color: HarvestTheme.Colors.accent, label: secondaryLabel)
            }
            .frame(maxWidth: .infinity)
        } else {
            HStack(spacing: HarvestTheme.Spacing.lg) {
                legendDot(color: HarvestTheme.Colors.primary, label: primaryLabel)
            }
            .frame(maxWidth: .infinity)
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

    // MARK: - Geometry

    private func axisPoint(center: CGPoint, radius: Double, index: Int, magnitude: Double) -> CGPoint {
        let angle = (2 * .pi * Double(index) / Double(axes.count)) - .pi / 2
        // primary/secondary are normalized to sum ~1.0; clamp the radial range to [0, 1].
        let clamped = min(max(magnitude, 0), 1)
        let r = radius * clamped
        return CGPoint(
            x: center.x + CGFloat(r * cos(angle)),
            y: center.y + CGFloat(r * sin(angle))
        )
    }

    private func drawGrid(context: GraphicsContext, center: CGPoint, radius: Double) {
        let gridColor = HarvestTheme.Colors.textSecondary.opacity(0.25)
        let rings = [0.2, 0.4, 0.6, 0.8, 1.0]
        for ring in rings {
            var path = Path()
            for i in 0..<axes.count {
                let p = axisPoint(center: center, radius: radius, index: i, magnitude: ring)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }
        for i in 0..<axes.count {
            var path = Path()
            path.move(to: center)
            path.addLine(to: axisPoint(center: center, radius: radius, index: i, magnitude: 1.0))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }
    }

    private func drawAxisLabels(context: GraphicsContext, center: CGPoint, radius: Double) {
        for (i, axis) in axes.enumerated() {
            let labelPoint = axisPoint(center: center, radius: radius + 22, index: i, magnitude: 1.0)
            let text = Text(axis.displayName)
                .font(HarvestTheme.Typography.caption)
                .foregroundStyle(HarvestTheme.Colors.textSecondary)
            context.draw(text, at: labelPoint, anchor: .center)
        }
    }

    private func drawPolygon(
        context: GraphicsContext,
        center: CGPoint,
        radius: Double,
        scores: AxisScores,
        stroke: Color,
        fill: Color
    ) {
        var path = Path()
        for (i, axis) in axes.enumerated() {
            let p = axisPoint(
                center: center,
                radius: radius,
                index: i,
                magnitude: scores.value(for: axis)
            )
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        context.fill(path, with: .color(fill))
        context.stroke(path, with: .color(stroke), lineWidth: 1.5)
    }
}

#Preview("Radar — needle on connection") {
    var s = AxisScores(); s.connection = 1.0
    return ValuesRadarCard(primary: s, primaryLabel: "I Need")
        .padding()
        .background(HarvestTheme.Colors.background)
}

#Preview("Radar — balanced") {
    var s = AxisScores()
    s.emotionalIntelligence = 0.2; s.stability = 0.2; s.integrity = 0.2
    s.connection = 0.2; s.growth = 0.2
    return ValuesRadarCard(primary: s, primaryLabel: "I Bring")
        .padding()
        .background(HarvestTheme.Colors.background)
}

#Preview("Radar — empty with action") {
    ValuesRadarCard(
        primary: AxisScores(),
        primaryLabel: "I Need",
        onEmptyTap: { print("start tapped") }
    )
    .padding()
    .background(HarvestTheme.Colors.background)
}
