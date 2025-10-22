import SwiftUI
import PulleyFEA
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
    @Published var hasResults = false

    // Model properties
    @Published var length: Double = 1000.0  // mm
    @Published var diameter: Double = 50.0  // mm
    @Published var load: Double = -1000.0  // N

    // Results
    @Published var endDeflection: Double = 0.0
    @Published var endRotation: Double = 0.0
    @Published var analyticalDeflection: Double = 0.0
    @Published var error: Double = 0.0

    // Material properties
    let youngsModulus: Double = 210000.0  // MPa
    let poissonsRatio: Double = 0.3

    func runAnalysis() {
        isRunning = true
        hasResults = false

        // Run FEA in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Create and run FEA model
            let assembly = FEAssembly()

            let element = ShaftElement(
                diameter: self.diameter,
                axialPositionStart: 0.0,
                axialPositionEnd: self.length,
                youngsModulus: self.youngsModulus,
                poissonsRatio: self.poissonsRatio,
                mode: 0,
                model: .timoshenko
            )

            assembly.addElement(element)
            assembly.assemble(mode: 0)

            let node0 = element.nodes[0]
            let node1 = element.nodes[1]

            let node0DOFs = assembly.getDOFIndices(forNode: node0)
            let node1DOFs = assembly.getDOFIndices(forNode: node1)

            // Boundary conditions
            assembly.fixDOF(node0DOFs[0])
            assembly.fixDOF(node0DOFs[1])
            assembly.fixDOF(node0DOFs[2])
            assembly.fixDOF(node0DOFs[3])

            // Apply load
            assembly.applyForce(self.load, atDOF: node1DOFs[0])

            // Solve
            let success = assembly.solve()

            if success {
                let w1 = assembly.getDisplacement(atDOF: node1DOFs[0]) ?? 0.0
                let gamma1 = assembly.getDisplacement(atDOF: node1DOFs[1]) ?? 0.0

                // Calculate analytical solution
                let I = Double.pi * pow(self.diameter, 4) / 64.0
                let analytical = abs(self.load) * pow(self.length, 3) / (3.0 * self.youngsModulus * I)

                // Update UI on main thread
                DispatchQueue.main.async {
                    self.endDeflection = w1
                    self.endRotation = gamma1
                    self.analyticalDeflection = analytical
                    self.error = abs(abs(w1) - analytical) / analytical * 100.0
                    self.hasResults = true
                    self.isRunning = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
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
                drawDeformedShape(
                    context: context,
                    startX: beamStartX,
                    y: beamY,
                    length: beamLength,
                    deflection: viewModel.endDeflection * scale * 10  // Amplify for visibility
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
        // deflection is negative (downward), so we use it directly
        var deformedPath = Path()
        deformedPath.move(to: CGPoint(x: startX, y: y))

        let steps = 50
        for i in 0...steps {
            let x = startX + (CGFloat(i) / CGFloat(steps)) * length
            let t = CGFloat(i) / CGFloat(steps)
            // Cubic deflection: w = (F*L^3)/(3*EI) * (x/L)^2 * (3 - x/L)
            // Use deflection directly (it's already negative for downward)
            let w = deflection * t * t * (3.0 - t)
            deformedPath.addLine(to: CGPoint(x: x, y: y + w))
        }

        context.stroke(deformedPath, with: .color(.blue), style: StrokeStyle(lineWidth: 3, dash: [5, 3]))

        // Add legend (position below the beam for downward deflection)
        let labelY = deflection < 0 ? y + abs(deflection) + 20 : y - 20
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
