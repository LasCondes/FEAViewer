import SwiftUI

// MARK: - Graph Data

/// Represents data to be plotted on a graph
struct GraphData: Sendable {
    let points: [(x: Double, y: Double)]
    let color: Color
    let showPoints: Bool
    let lineWidth: CGFloat

    init(points: [(x: Double, y: Double)], color: Color = .blue, showPoints: Bool = false, lineWidth: CGFloat = 2) {
        self.points = points
        self.color = color
        self.showPoints = showPoints
        self.lineWidth = lineWidth
    }
}

// MARK: - Base Graph View

/// Reusable graph view component with automatic axis scaling and labeling
struct BaseGraphView: View {
    let data: GraphData
    let xAxisLabel: String
    let yAxisLabel: String
    let yFormat: String

    private let padding: CGFloat = 40

    init(data: GraphData, xAxisLabel: String, yAxisLabel: String, yFormat: String = "%.1f") {
        self.data = data
        self.xAxisLabel = xAxisLabel
        self.yAxisLabel = yAxisLabel
        self.yFormat = yFormat
    }

    var body: some View {
        Canvas { context, size in
            let graphWidth = size.width - 2 * padding
            let graphHeight = size.height - 2 * padding

            guard !data.points.isEmpty else { return }

            // Sort data by x position
            let sortedData = data.points.sorted { $0.x < $1.x }

            // Find bounds
            let minX = sortedData.map { $0.x }.min() ?? 0
            let maxX = sortedData.map { $0.x }.max() ?? 1
            let minY = min(0, sortedData.map { $0.y }.min() ?? 0)
            let maxY = max(0, sortedData.map { $0.y }.max() ?? 1)
            let yRange = max(abs(maxY - minY), 1e-10)

            // Draw axes
            drawAxes(context: context, size: size)

            // Draw zero line if range includes both positive and negative
            if minY < 0 && maxY > 0 {
                drawZeroLine(context: context, size: size, minY: minY, yRange: yRange, graphHeight: graphHeight)
            }

            // Draw data line
            drawDataLine(
                context: context,
                data: sortedData,
                minX: minX,
                maxX: maxX,
                minY: minY,
                yRange: yRange,
                graphWidth: graphWidth,
                graphHeight: graphHeight,
                size: size
            )

            // Draw labels
            drawLabels(context: context, size: size, minY: minY, maxY: maxY)
        }
    }

    private func drawAxes(context: GraphicsContext, size: CGSize) {
        var axesPath = Path()
        axesPath.move(to: CGPoint(x: padding, y: padding))
        axesPath.addLine(to: CGPoint(x: padding, y: size.height - padding))
        axesPath.addLine(to: CGPoint(x: size.width - padding, y: size.height - padding))
        context.stroke(axesPath, with: .color(.gray), lineWidth: 1)
    }

    private func drawZeroLine(context: GraphicsContext, size: CGSize, minY: Double, yRange: Double, graphHeight: CGFloat) {
        let zeroY = size.height - padding - CGFloat(-minY / yRange) * graphHeight
        var zeroLine = Path()
        zeroLine.move(to: CGPoint(x: padding, y: zeroY))
        zeroLine.addLine(to: CGPoint(x: size.width - padding, y: zeroY))
        context.stroke(zeroLine, with: .color(.gray.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
    }

    private func drawDataLine(
        context: GraphicsContext,
        data: [(x: Double, y: Double)],
        minX: Double,
        maxX: Double,
        minY: Double,
        yRange: Double,
        graphWidth: CGFloat,
        graphHeight: CGFloat,
        size: CGSize
    ) {
        var dataPath = Path()

        for (index, point) in data.enumerated() {
            let normalizedX = maxX > minX ? (point.x - minX) / (maxX - minX) : 0.5
            let normalizedY = (point.y - minY) / yRange

            let screenX = padding + CGFloat(normalizedX) * graphWidth
            let screenY = size.height - padding - CGFloat(normalizedY) * graphHeight

            if index == 0 {
                dataPath.move(to: CGPoint(x: screenX, y: screenY))
            } else {
                dataPath.addLine(to: CGPoint(x: screenX, y: screenY))
            }

            // Draw point markers if enabled
            if self.data.showPoints {
                let pointCircle = Path(ellipseIn: CGRect(x: screenX - 3, y: screenY - 3, width: 6, height: 6))
                context.fill(pointCircle, with: .color(self.data.color))
            }
        }

        context.stroke(dataPath, with: .color(self.data.color), lineWidth: self.data.lineWidth)
    }

    private func drawLabels(context: GraphicsContext, size: CGSize, minY: Double, maxY: Double) {
        // X-axis label
        context.draw(
            Text(xAxisLabel).font(.caption),
            at: CGPoint(x: size.width / 2, y: size.height - 10)
        )

        // Y-axis label
        context.draw(
            Text(yAxisLabel).font(.caption),
            at: CGPoint(x: 10, y: 10),
            anchor: .topLeading
        )

        // Y-axis value labels
        let maxLabel = String(format: yFormat, maxY)
        context.draw(
            Text(maxLabel).font(.caption2),
            at: CGPoint(x: padding - 5, y: padding),
            anchor: .trailing
        )

        let minLabel = String(format: yFormat, minY)
        context.draw(
            Text(minLabel).font(.caption2),
            at: CGPoint(x: padding - 5, y: size.height - padding),
            anchor: .trailing
        )
    }
}
