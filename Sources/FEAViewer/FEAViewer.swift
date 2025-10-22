import SwiftUI
import AxiSymFEA

@main
struct FEAViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1400, height: 900)
    }
}

struct ContentView: View {
    @StateObject private var feaModel = FEAModel()
    @StateObject private var viewModel = FEAViewModel()

    var body: some View {
        HSplitView {
            // Left: Model definition
            VStack(spacing: 0) {
                // Title bar
                HStack {
                    Text("FEA Model")
                        .font(.headline)
                    Spacer()
                    Button("Clear All") {
                        feaModel.clear()
                    }
                    .buttonStyle(.bordered)
                    Button("Run Analysis") {
                        viewModel.runAnalysis(model: feaModel)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isRunning)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                // Model builder
                ModelBuilderView(model: feaModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 350)

            // Middle: Visualization
            VStack(spacing: 0) {
                HStack {
                    Text("Visualization")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                VisualizationView(model: feaModel, results: viewModel.results)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.textBackgroundColor))
            }
            .frame(minWidth: 400)

            // Right: Results
            VStack(spacing: 0) {
                HStack {
                    Text("Results")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                ResultsView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 300)
        }
    }
}

// MARK: - Model Builder View

struct ModelBuilderView: View {
    @ObservedObject var model: FEAModel
    @State private var showingAddConstraint = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Material properties
                GroupBox("Material") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Young's Modulus:")
                                .frame(width: 140, alignment: .leading)
                            TextField("", value: $model.material.youngsModulus, format: .number)
                                .textFieldStyle(.roundedBorder)
                            Text("MPa")
                        }
                        HStack {
                            Text("Poisson's Ratio:")
                                .frame(width: 140, alignment: .leading)
                            TextField("", value: $model.material.poissonsRatio, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                // Shaft elements
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Shaft Elements")
                                .font(.headline)
                            Spacer()
                            Button(action: { model.addShaftElement() }) {
                                Label("Add", systemImage: "plus.circle")
                            }
                        }

                        ForEach(model.shaftElements) { element in
                            ShaftElementRow(model: model, element: element)
                        }
                    }
                }

                // Disk elements
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Disk Elements")
                                .font(.headline)
                            Spacer()
                            Button(action: { model.addDiskElement() }) {
                                Label("Add", systemImage: "plus.circle")
                            }
                        }

                        ForEach(model.diskElements) { element in
                            DiskElementRow(model: model, element: element)
                        }
                    }
                }

                // Shell elements
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Shell Elements")
                                .font(.headline)
                            Spacer()
                            Button(action: { model.addShellElement() }) {
                                Label("Add", systemImage: "plus.circle")
                            }
                        }

                        ForEach(model.shellElements) { element in
                            ShellElementRow(model: model, element: element)
                        }
                    }
                }

                // Constraints
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Constraints")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                showingAddConstraint = true
                            }) {
                                Label("Add", systemImage: "plus.circle")
                            }
                        }

                        ForEach(model.constraints) { constraint in
                            ConstraintRow(model: model, constraint: constraint)
                        }

                        if model.constraints.isEmpty {
                            Text("No constraints defined")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingAddConstraint) {
            AddConstraintSheet(model: model, isPresented: $showingAddConstraint)
        }
    }
}

// MARK: - Add Constraint Sheet

struct AddConstraintSheet: View {
    @ObservedObject var model: FEAModel
    @Binding var isPresented: Bool

    @State private var selectedElementIndex = 0
    @State private var selectedLocation: ConstraintLocation = .shaftStart
    @State private var selectedDOF: DOFType = .w
    @State private var selectedType: ConstraintType = .fixed
    @State private var prescribedValue: Double = 0.0

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Constraint")
                .font(.title2)
                .bold()

            Form {
                Section("Location") {
                    Picker("Element Type", selection: $selectedLocation) {
                        if !model.shaftElements.isEmpty {
                            Text("Shaft Start").tag(ConstraintLocation.shaftStart)
                            Text("Shaft End").tag(ConstraintLocation.shaftEnd)
                        }
                        if !model.diskElements.isEmpty {
                            Text("Disk Inner").tag(ConstraintLocation.diskInner)
                            Text("Disk Outer").tag(ConstraintLocation.diskOuter)
                        }
                        if !model.shellElements.isEmpty {
                            Text("Shell Start").tag(ConstraintLocation.shellStart)
                            Text("Shell End").tag(ConstraintLocation.shellEnd)
                        }
                    }

                    Picker("Element Index", selection: $selectedElementIndex) {
                        ForEach(0..<maxElementCount, id: \.self) { index in
                            Text("#\(index)").tag(index)
                        }
                    }
                }

                Section("DOF") {
                    Picker("Degree of Freedom", selection: $selectedDOF) {
                        ForEach(model.getAvailableDOFs(for: selectedLocation), id: \.self) { dof in
                            Text(dof.displayName).tag(dof)
                        }
                    }
                }

                Section("Constraint Type") {
                    Picker("Type", selection: $selectedType) {
                        Text("Fixed (= 0)").tag(ConstraintType.fixed)
                        Text("Prescribed").tag(ConstraintType.prescribed)
                    }

                    if selectedType == .prescribed {
                        HStack {
                            Text("Value:")
                            TextField("", value: $prescribedValue, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    let constraint = Constraint(
                        elementIndex: selectedElementIndex,
                        location: selectedLocation,
                        dofType: selectedDOF,
                        constraintType: selectedType,
                        value: prescribedValue
                    )
                    model.addConstraint(constraint)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .padding()
        .frame(width: 400, height: 500)
    }

    private var maxElementCount: Int {
        switch selectedLocation {
        case .shaftStart, .shaftEnd:
            return model.shaftElements.count
        case .diskInner, .diskOuter:
            return model.diskElements.count
        case .shellStart, .shellEnd:
            return model.shellElements.count
        }
    }
}

// MARK: - Element Rows

struct ShaftElementRow: View {
    @ObservedObject var model: FEAModel
    let element: ShaftConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Shaft").font(.caption).bold()
                Spacer()
                Button(action: { model.deleteShaftElement(element) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            if let index = model.shaftElements.firstIndex(where: { $0.id == element.id }) {
                HStack {
                    Text("Diameter:")
                        .font(.caption)
                        .frame(width: 80, alignment: .leading)
                    TextField("", value: $model.shaftElements[index].diameter, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Text("mm")
                        .font(.caption)
                }

                HStack {
                    Text("Start Z:")
                        .font(.caption)
                        .frame(width: 80, alignment: .leading)
                    TextField("", value: $model.shaftElements[index].startPosition, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Text("mm")
                        .font(.caption)
                }

                HStack {
                    Text("End Z:")
                        .font(.caption)
                        .frame(width: 80, alignment: .leading)
                    TextField("", value: $model.shaftElements[index].endPosition, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Text("mm")
                        .font(.caption)
                }
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(4)
    }
}

struct DiskElementRow: View {
    @ObservedObject var model: FEAModel
    let element: DiskConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Disk").font(.caption).bold()
                Spacer()
                Button(action: { model.deleteDiskElement(element) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            if let index = model.diskElements.firstIndex(where: { $0.id == element.id }) {
                HStack {
                    Text("Inner R:")
                        .font(.caption)
                        .frame(width: 80, alignment: .leading)
                    TextField("", value: $model.diskElements[index].innerRadius, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Text("mm")
                        .font(.caption)
                }

                HStack {
                    Text("Outer R:")
                        .font(.caption)
                        .frame(width: 80, alignment: .leading)
                    TextField("", value: $model.diskElements[index].outerRadius, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Text("mm")
                        .font(.caption)
                }
            }
        }
        .padding(8)
        .background(Color.green.opacity(0.1))
        .cornerRadius(4)
    }
}

struct ShellElementRow: View {
    @ObservedObject var model: FEAModel
    let element: ShellConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Shell").font(.caption).bold()
                Spacer()
                Button(action: { model.deleteShellElement(element) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            if let index = model.shellElements.firstIndex(where: { $0.id == element.id }) {
                HStack {
                    Text("Radius:")
                        .font(.caption)
                        .frame(width: 80, alignment: .leading)
                    TextField("", value: $model.shellElements[index].radius, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Text("mm")
                        .font(.caption)
                }

                HStack {
                    Text("Thickness:")
                        .font(.caption)
                        .frame(width: 80, alignment: .leading)
                    TextField("", value: $model.shellElements[index].thickness, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Text("mm")
                        .font(.caption)
                }
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(4)
    }
}

struct ConstraintRow: View {
    @ObservedObject var model: FEAModel
    let constraint: Constraint

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "pin.fill")
                    .foregroundColor(.purple)
                    .font(.caption)
                Text(constraint.description)
                    .font(.caption)
                Spacer()
                Button(action: { model.deleteConstraint(constraint) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Visualization View

struct VisualizationView: View {
    @ObservedObject var model: FEAModel
    let results: FEAResults?

    var body: some View {
        Canvas { context, size in
            let padding: CGFloat = 40

            // Draw coordinate system
            drawCoordinateSystem(context: context, origin: CGPoint(x: padding, y: size.height - padding))

            // Draw shaft elements
            for shaft in model.shaftElements {
                drawShaft(context: context, config: shaft, size: size, padding: padding)
            }

            // Draw disk elements
            for disk in model.diskElements {
                drawDisk(context: context, config: disk, size: size, padding: padding)
            }

            // Draw shell elements
            for shell in model.shellElements {
                drawShell(context: context, config: shell, size: size, padding: padding)
            }
        }
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Legend").font(.caption).bold()
                HStack {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 20, height: 12)
                    Text("Shaft").font(.caption)
                }
                HStack {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 12, height: 12)
                    Text("Disk").font(.caption)
                }
                HStack {
                    Rectangle()
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 20, height: 12)
                    Text("Shell").font(.caption)
                }
            }
            .padding(8)
            .background(.regularMaterial)
            .cornerRadius(8)
            .padding()
        }
    }

    func drawCoordinateSystem(context: GraphicsContext, origin: CGPoint) {
        let arrowLength: CGFloat = 30

        // X axis (red)
        var xPath = Path()
        xPath.move(to: origin)
        xPath.addLine(to: CGPoint(x: origin.x + arrowLength, y: origin.y))
        context.stroke(xPath, with: .color(.red), lineWidth: 2)
        context.draw(Text("x").foregroundColor(.red).font(.caption), at: CGPoint(x: origin.x + arrowLength + 10, y: origin.y))

        // Y axis (green)
        var yPath = Path()
        yPath.move(to: origin)
        yPath.addLine(to: CGPoint(x: origin.x, y: origin.y - arrowLength))
        context.stroke(yPath, with: .color(.green), lineWidth: 2)
        context.draw(Text("y").foregroundColor(.green).font(.caption), at: CGPoint(x: origin.x, y: origin.y - arrowLength - 10))
    }

    func drawShaft(context: GraphicsContext, config: ShaftConfig, size: CGSize, padding: CGFloat) {
        let scale: CGFloat = 0.5
        let centerY = size.height / 2
        let startX = padding + config.startPosition * scale
        let endX = padding + config.endPosition * scale
        let halfDiameter = config.diameter * scale / 2

        let path = Path { p in
            p.move(to: CGPoint(x: startX, y: centerY - halfDiameter))
            p.addLine(to: CGPoint(x: endX, y: centerY - halfDiameter))
            p.addLine(to: CGPoint(x: endX, y: centerY + halfDiameter))
            p.addLine(to: CGPoint(x: startX, y: centerY + halfDiameter))
            p.closeSubpath()
        }

        context.fill(path, with: .color(.blue.opacity(0.3)))
        context.stroke(path, with: .color(.blue), lineWidth: 1.5)
    }

    func drawDisk(context: GraphicsContext, config: DiskConfig, size: CGSize, padding: CGFloat) {
        let scale: CGFloat = 0.5
        let centerX = size.width / 2
        let centerY = size.height / 2
        let innerR = config.innerRadius * scale
        let outerR = config.outerRadius * scale

        // Draw as concentric circles
        let outerCircle = Path(ellipseIn: CGRect(
            x: centerX - outerR,
            y: centerY - outerR,
            width: outerR * 2,
            height: outerR * 2
        ))

        context.fill(outerCircle, with: .color(.green.opacity(0.2)))
        context.stroke(outerCircle, with: .color(.green), lineWidth: 1.5)

        let innerCircle = Path(ellipseIn: CGRect(
            x: centerX - innerR,
            y: centerY - innerR,
            width: innerR * 2,
            height: innerR * 2
        ))

        context.stroke(innerCircle, with: .color(.green), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
    }

    func drawShell(context: GraphicsContext, config: ShellConfig, size: CGSize, padding: CGFloat) {
        let scale: CGFloat = 0.5
        let centerY = size.height / 2
        let startX = padding + config.startPosition * scale
        let endX = padding + config.endPosition * scale
        let radius = config.radius * scale

        let path = Path { p in
            p.move(to: CGPoint(x: startX, y: centerY - radius))
            p.addLine(to: CGPoint(x: endX, y: centerY - radius))
            p.addLine(to: CGPoint(x: endX, y: centerY + radius))
            p.addLine(to: CGPoint(x: startX, y: centerY + radius))
            p.closeSubpath()
        }

        context.fill(path, with: .color(.orange.opacity(0.2)))
        context.stroke(path, with: .color(.orange), lineWidth: 1.5)
    }
}

// MARK: - Results View

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
                } else if let results = viewModel.results {
                    GroupBox("Analysis Summary") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Status:")
                                Spacer()
                                Text(results.success ? "✓ Success" : "✗ Failed")
                                    .foregroundColor(results.success ? .green : .red)
                                    .bold()
                            }
                            HStack {
                                Text("Total DOFs:")
                                Spacer()
                                Text("\(results.totalDOFs)")
                            }
                            HStack {
                                Text("Solve Time:")
                                Spacer()
                                Text(String(format: "%.3f s", results.solveTime))
                            }
                        }
                    }

                    if let error = viewModel.errorMessage {
                        GroupBox("Error") {
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "gearshape.2")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No results yet")
                            .font(.headline)
                        Text("Build a model and click 'Run Analysis'")
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

// MARK: - View Model

class FEAViewModel: ObservableObject {
    @Published var isRunning = false
    @Published var errorMessage: String?
    @Published var results: FEAResults?

    func runAnalysis(model: FEAModel) {
        isRunning = true
        errorMessage = nil
        results = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let results = try model.solve()

                DispatchQueue.main.async {
                    self.results = results
                    self.isRunning = false

                    if !results.success {
                        self.errorMessage = "Solver failed to converge"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isRunning = false
                }
            }
        }
    }
}
