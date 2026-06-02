import SwiftUI

struct ValuesRadarCard: View {
    let title: String
    let subtitle: String?
    let primary: AxisScores
    let primaryLabel: String
    let primaryColor: Color
    let secondary: AxisScores?
    let secondaryLabel: String?
    let secondaryColor: Color
    let onEmptyTap: (() -> Void)?

    init(
        title: String = "Your Values Map",
        subtitle: String? = nil,
        primary: AxisScores,
        primaryLabel: String,
        primaryColor: Color = HarvestTheme.Colors.primary,
        secondary: AxisScores? = nil,
        secondaryLabel: String? = nil,
        secondaryColor: Color = HarvestTheme.Colors.accent,
        onEmptyTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.primary = primary
        self.primaryLabel = primaryLabel
        self.primaryColor = primaryColor
        self.secondary = secondary
        self.secondaryLabel = secondaryLabel
        self.secondaryColor = secondaryColor
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(HarvestTheme.Typography.h4)
                        .foregroundStyle(HarvestTheme.Colors.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(HarvestTheme.Typography.bodySmall)
                            .foregroundStyle(HarvestTheme.Colors.textSecondary)
                    }
                }

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
                        stroke: secondaryColor,
                        fill: secondaryColor.opacity(0.3)
                    )
                }
                if !primary.isZero {
                    drawPolygon(
                        context: context,
                        center: center,
                        radius: radius,
                        scores: primary,
                        stroke: primaryColor,
                        fill: primaryColor.opacity(0.3)
                    )
                }
                // Drawn last so the tier numbers stay legible over the polygons.
                drawRingNumbers(context: context, center: center, radius: radius)
            }
        }
        .frame(height: 280)
    }

    @ViewBuilder
    private var legend: some View {
        if let secondary, !secondary.isZero, let secondaryLabel {
            HStack(spacing: HarvestTheme.Spacing.lg) {
                legendDot(color: primaryColor, label: primaryLabel)
                legendDot(color: secondaryColor, label: secondaryLabel)
            }
            .frame(maxWidth: .infinity)
        } else {
            HStack(spacing: HarvestTheme.Spacing.lg) {
                legendDot(color: primaryColor, label: primaryLabel)
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
        // `magnitude` is already a radius fraction in [0, 1] (a tier ring position); clamp defensively.
        let clamped = min(max(magnitude, 0), 1)
        let r = radius * clamped
        return CGPoint(
            x: center.x + CGFloat(r * cos(angle)),
            y: center.y + CGFloat(r * sin(angle))
        )
    }

    private func drawGrid(context: GraphicsContext, center: CGPoint, radius: Double) {
        let gridColor = HarvestTheme.Colors.textSecondary.opacity(0.25)
        // Four rings, one per ValuesTier (1st → outer).
        let rings = [0.25, 0.5, 0.75, 1.0]
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

    private func drawRingNumbers(context: GraphicsContext, center: CGPoint, radius: Double) {
        // Tier numbers (1…4) stacked up the centre line, just left of the top spoke.
        for tier in ValuesTier.allCases {
            let y = center.y - radius * tier.radiusFraction
            let point = CGPoint(x: center.x - 12, y: y)
            let text = Text("\(tier.rawValue)")
                .font(HarvestTheme.Typography.caption)
                .foregroundStyle(HarvestTheme.Colors.textTertiary)
            context.draw(text, at: point, anchor: .center)
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
            // Translate the raw category score into its visual tier ring position.
            let tierMagnitude = ValuesTier(rawScore: scores.value(for: axis)).radiusFraction
            let p = axisPoint(
                center: center,
                radius: radius,
                index: i,
                magnitude: tierMagnitude
            )
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        context.fill(path, with: .color(fill))
        context.stroke(path, with: .color(stroke), lineWidth: 1.5)
    }
}

#Preview("Radar — connection is a core value") {
    // Raw scores (0–28). connection 22 → Core Value (outer ring), the rest land lower.
    var s = AxisScores()
    s.emotionalIntelligence = 8; s.stability = 3; s.integrity = 14
    s.connection = 22; s.growth = 12
    return ValuesRadarCard(primary: s, primaryLabel: "I Need")
        .padding()
        .background(HarvestTheme.Colors.background)
}

#Preview("Radar — balanced (raw scores)") {
    var s = AxisScores()
    s.emotionalIntelligence = 12; s.stability = 12; s.integrity = 12
    s.connection = 12; s.growth = 12
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
