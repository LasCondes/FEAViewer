import SwiftUI
import AxiSymFEA
import PulleyCore

@main
struct PulleyViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = FEAViewModel()

    var body: some View {
        HSplitView {
            // Left panel: Model visualization
            VStack(spacing: 0) {
                // Title bar
                HStack {
                    Text("Cantilever Beam Model")
                        .font(.headline)
                    Spacer()
                    Button("Run Analysis") {
                        viewModel.runAnalysis()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isRunning)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                // Model view
                GeometryView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.textBackgroundColor))
            }
            .frame(minWidth: 400)

            // Right panel: Results
            VStack(spacing: 0) {
                // Title bar
                HStack {
                    Text("Results")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                // Results view
                ResultsView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 300)
        }
    }
}

// View Model
class FEAViewModel: ObservableObject {
    @Published var isRunning = false
    @Published var errorMessage: String?

    // FEA Model
    private var feaModel: CantileverBeamModel

    // Published results
    @Published var results: FEAResults?

    // Computed properties for UI binding
    var parameters: CantileverBeamParameters {
        feaModel.parameters
    }

    var hasResults: Bool {
        results != nil
    }

    // Convenience accessors for results
    var endDeflection: Double {
        results?.endDeflection ?? 0.0
    }

    var endRotation: Double {
        results?.endRotation ?? 0.0
    }

    var analyticalDeflection: Double {
        results?.analyticalDeflection ?? 0.0
    }

    var error: Double {
        results?.errorPercentage ?? 0.0
    }

    // Material properties (exposed for display)
    var youngsModulus: Double {
        parameters.youngsModulus
    }

    var poissonsRatio: Double {
        parameters.poissonsRatio
    }

    var length: Double {
        parameters.length
    }

    var diameter: Double {
        parameters.diameter
    }

    var load: Double {
        parameters.load
    }

    init() {
        self.feaModel = CantileverBeamModel()
    }

    func runAnalysis() {
        isRunning = true
        errorMessage = nil

        // Run FEA in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let results = try self.feaModel.solve()

                // Update UI on main thread
                DispatchQueue.main.async {
                    self.results = results
                    self.isRunning = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isRunning = false
                }
            }
        }
    }

    // MARK: - Parameter Updates

    func updateLength(_ length: Double) {
        feaModel.updateLength(length)
        results = nil
    }

    func updateDiameter(_ diameter: Double) {
        feaModel.updateDiameter(diameter)
        results = nil
    }

    func updateLoad(_ load: Double) {
        feaModel.updateLoad(load)
        results = nil
    }
}

// Geometry visualization view
struct GeometryView: View {
    @ObservedObject var viewModel: FEAViewModel

    var body: some View {
        Canvas { context, size in
            let padding: CGFloat = 80
            let drawWidth = size.width - 2 * padding
            let drawHeight = size.height - 2 * padding

            // Scale factor for beam length
            let scale = drawWidth * 0.8 / viewModel.length

            // Beam position
            let beamY = size.height / 2
            let beamStartX = padding + drawWidth * 0.1
            let beamLength = viewModel.length * scale

            // Draw coordinate system
            drawCoordinateSystem(context: context, origin: CGPoint(x: padding, y: size.height - padding))

            // Draw fixed support at left end
            drawFixedSupport(context: context, at: CGPoint(x: beamStartX, y: beamY))

            // Draw beam (undeformed)
            let beamPath = Path { path in
                path.move(to: CGPoint(x: beamStartX, y: beamY - 5))
                path.addLine(to: CGPoint(x: beamStartX + beamLength, y: beamY - 5))
                path.addLine(to: CGPoint(x: beamStartX + beamLength, y: beamY + 5))
                path.addLine(to: CGPoint(x: beamStartX, y: beamY + 5))
                path.closeSubpath()
            }

            context.stroke(beamPath, with: .color(.gray), lineWidth: 2)
            context.fill(beamPath, with: .color(.gray.opacity(0.3)))

            // Draw deformed shape if results available
            if viewModel.hasResults {
                // Convert physical deflection to screen coordinates
                // Physical: negative = downward, Screen: positive y = downward
                // So we negate to flip the sign
                let screenDeflection = -viewModel.endDeflection * scale * 10  // Amplify for visibility
                drawDeformedShape(
                    context: context,
                    startX: beamStartX,
                    y: beamY,
                    length: beamLength,
                    deflection: screenDeflection
                )
            }

            // Draw load arrow
            drawLoadArrow(
                context: context,
                at: CGPoint(x: beamStartX + beamLength, y: beamY),
                magnitude: abs(viewModel.load)
            )

            // Draw dimensions
            drawDimensions(
                context: context,
                startX: beamStartX,
                y: beamY,
                length: beamLength,
                actualLength: viewModel.length
            )
        }
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Model Parameters")
                    .font(.headline)
                Divider()
                Text("Length: \(String(format: "%.0f", viewModel.length)) mm")
                Text("Diameter: \(String(format: "%.1f", viewModel.diameter)) mm")
                Text("Load: \(String(format: "%.0f", viewModel.load)) N")
                Text("Material: Steel")
                Text("E: \(String(format: "%.0f", viewModel.youngsModulus)) MPa")
                Text("ν: \(String(format: "%.2f", viewModel.poissonsRatio))")
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(8)
            .padding()
        }
    }

    func drawCoordinateSystem(context: GraphicsContext, origin: CGPoint) {
        let arrowLength: CGFloat = 40

        // X axis (red)
        var xPath = Path()
        xPath.move(to: origin)
        xPath.addLine(to: CGPoint(x: origin.x + arrowLength, y: origin.y))
        context.stroke(xPath, with: .color(.red), lineWidth: 2)

        // Y axis (green)
        var yPath = Path()
        yPath.move(to: origin)
        yPath.addLine(to: CGPoint(x: origin.x, y: origin.y - arrowLength))
        context.stroke(yPath, with: .color(.green), lineWidth: 2)

        // Labels
        context.draw(Text("x").foregroundColor(.red), at: CGPoint(x: origin.x + arrowLength + 10, y: origin.y))
        context.draw(Text("y").foregroundColor(.green), at: CGPoint(x: origin.x, y: origin.y - arrowLength - 10))
    }

    func drawFixedSupport(context: GraphicsContext, at point: CGPoint) {
        // Draw wall
        var wallPath = Path()
        for i in 0..<5 {
            let y = point.y - 20 + CGFloat(i) * 10
            wallPath.move(to: CGPoint(x: point.x - 10, y: y))
            wallPath.addLine(to: CGPoint(x: point.x - 15, y: y + 5))
        }
        context.stroke(wallPath, with: .color(.black), lineWidth: 2)

        // Draw connection
        var connectionPath = Path()
        connectionPath.move(to: CGPoint(x: point.x - 10, y: point.y - 20))
        connectionPath.addLine(to: CGPoint(x: point.x - 10, y: point.y + 20))
        context.stroke(connectionPath, with: .color(.black), lineWidth: 3)
    }

    func drawDeformedShape(context: GraphicsContext, startX: CGFloat, y: CGFloat, length: CGFloat, deflection: CGFloat) {
        // Cubic deflection curve for cantilever
        // deflection is in screen coordinates (positive = downward)
        var deformedPath = Path()
        deformedPath.move(to: CGPoint(x: startX, y: y))

        let steps = 50
        for i in 0...steps {
            let x = startX + (CGFloat(i) / CGFloat(steps)) * length
            let t = CGFloat(i) / CGFloat(steps)
            // Cubic deflection: w = (F*L^3)/(3*EI) * (x/L)^2 * (3 - x/L)
            let w = deflection * t * t * (3.0 - t)
            deformedPath.addLine(to: CGPoint(x: x, y: y + w))
        }

        context.stroke(deformedPath, with: .color(.blue), style: StrokeStyle(lineWidth: 3, dash: [5, 3]))

        // Add legend (position based on deflection direction)
        let labelY = deflection > 0 ? y + deflection + 20 : y + deflection - 20
        context.draw(
            Text("Deformed (10x)").foregroundColor(.blue).font(.caption),
            at: CGPoint(x: startX + length / 2, y: labelY)
        )
    }

    func drawLoadArrow(context: GraphicsContext, at point: CGPoint, magnitude: Double) {
        let arrowLength: CGFloat = 40

        // Arrow shaft
        var arrowPath = Path()
        arrowPath.move(to: CGPoint(x: point.x, y: point.y - 30))
        arrowPath.addLine(to: CGPoint(x: point.x, y: point.y))

        // Arrow head
        arrowPath.move(to: CGPoint(x: point.x, y: point.y))
        arrowPath.addLine(to: CGPoint(x: point.x - 5, y: point.y - 10))
        arrowPath.move(to: CGPoint(x: point.x, y: point.y))
        arrowPath.addLine(to: CGPoint(x: point.x + 5, y: point.y - 10))

        context.stroke(arrowPath, with: .color(.red), lineWidth: 2)

        // Label
        context.draw(
            Text("\(String(format: "%.0f", magnitude)) N").foregroundColor(.red).font(.caption),
            at: CGPoint(x: point.x + 20, y: point.y - 20)
        )
    }

    func drawDimensions(context: GraphicsContext, startX: CGFloat, y: CGFloat, length: CGFloat, actualLength: Double) {
        let dimY = y + 40

        // Dimension line
        var dimPath = Path()
        dimPath.move(to: CGPoint(x: startX, y: dimY))
        dimPath.addLine(to: CGPoint(x: startX + length, y: dimY))

        // End marks
        dimPath.move(to: CGPoint(x: startX, y: dimY - 5))
        dimPath.addLine(to: CGPoint(x: startX, y: dimY + 5))
        dimPath.move(to: CGPoint(x: startX + length, y: dimY - 5))
        dimPath.addLine(to: CGPoint(x: startX + length, y: dimY + 5))

        context.stroke(dimPath, with: .color(.gray), lineWidth: 1)

        // Label
        context.draw(
            Text("\(String(format: "%.0f", actualLength)) mm").font(.caption),
            at: CGPoint(x: startX + length / 2, y: dimY + 15)
        )
    }
}

// Results view
struct ResultsView: View {
    @ObservedObject var viewModel: FEAViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isRunning {
                    HStack {
                        ProgressView()
                        Text("Running analysis...")
                    }
                    .padding()
                } else if viewModel.hasResults {
                    // Displacements
                    GroupBox("Displacements") {
                        VStack(alignment: .leading, spacing: 8) {
                            ResultRow(
                                label: "End deflection (w)",
                                value: viewModel.endDeflection,
                                unit: "mm",
                                format: "%.6f"
                            )
                            ResultRow(
                                label: "End rotation (γ)",
                                value: viewModel.endRotation,
                                unit: "rad",
                                format: "%.6e"
                            )
                        }
                    }

                    // Comparison
                    GroupBox("Validation") {
                        VStack(alignment: .leading, spacing: 8) {
                            ResultRow(
                                label: "FEA solution",
                                value: abs(viewModel.endDeflection),
                                unit: "mm",
                                format: "%.6f"
                            )
                            ResultRow(
                                label: "Analytical (Euler-Bernoulli)",
                                value: viewModel.analyticalDeflection,
                                unit: "mm",
                                format: "%.6f"
                            )
                            Divider()
                            HStack {
                                Text("Error:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.2f%%", viewModel.error))
                                    .foregroundColor(viewModel.error < 1.0 ? .green : .orange)
                                    .bold()
                            }
                        }
                    }

                    // Theory
                    GroupBox("Theory") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cantilever Beam")
                                .font(.headline)
                            Text("Fixed at left end, loaded at right end")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Divider()
                            Text("Analytical deflection:")
                            Text("δ = FL³/(3EI)")
                                .font(.system(.body, design: .monospaced))
                                .padding(.leading)
                            Text("where:")
                                .padding(.top, 4)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("F = applied load")
                                Text("L = beam length")
                                Text("E = Young's modulus")
                                Text("I = moment of inertia")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading)
                        }
                    }

                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No results yet")
                            .font(.headline)
                        Text("Click 'Run Analysis' to solve the FEA model")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
        }
    }
}

struct ResultRow: View {
    let label: String
    let value: Double
    let unit: String
    let format: String

    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: format, value))
                .font(.system(.body, design: .monospaced))
            Text(unit)
                .foregroundColor(.secondary)
        }
    }
}
