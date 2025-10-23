import SwiftUI
import AxiSymFEA

@main
struct FEAViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1600, height: 900)
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
            .frame(minWidth: 450)

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
    @State private var showingAddNode = false
    @State private var showingAddElement = false
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

                // Nodes
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Nodes")
                                .font(.headline)
                            Spacer()
                            Button(action: { showingAddNode = true }) {
                                Label("Add", systemImage: "plus.circle")
                            }
                        }

                        ForEach(model.nodes) { node in
                            NodeRow(model: model, node: node)
                        }

                        if model.nodes.isEmpty {
                            Text("No nodes defined")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        }
                    }
                }

                // Elements
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Elements")
                                .font(.headline)
                            Spacer()
                            Button(action: { showingAddElement = true }) {
                                Label("Add", systemImage: "plus.circle")
                            }
                        }

                        if !model.shaftElements.isEmpty {
                            Text("Shaft Elements").font(.subheadline).bold()
                            ForEach(model.shaftElements) { element in
                                ShaftElementRow(model: model, element: element)
                            }
                        }

                        if !model.diskElements.isEmpty {
                            Text("Disk Elements").font(.subheadline).bold().padding(.top, 4)
                            ForEach(model.diskElements) { element in
                                DiskElementRow(model: model, element: element)
                            }
                        }

                        if !model.shellElements.isEmpty {
                            Text("Shell Elements").font(.subheadline).bold().padding(.top, 4)
                            ForEach(model.shellElements) { element in
                                ShellElementRow(model: model, element: element)
                            }
                        }

                        if model.shaftElements.isEmpty && model.diskElements.isEmpty && model.shellElements.isEmpty {
                            Text("No elements defined")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
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
                            Button(action: { showingAddConstraint = true }) {
                                Label("Add", systemImage: "plus.circle")
                            }
                            .disabled(model.nodes.isEmpty)
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
        .sheet(isPresented: $showingAddNode) {
            AddNodeSheet(model: model, isPresented: $showingAddNode)
        }
        .sheet(isPresented: $showingAddElement) {
            AddElementSheet(model: model, isPresented: $showingAddElement)
        }
        .sheet(isPresented: $showingAddConstraint) {
            AddConstraintSheet(model: model, isPresented: $showingAddConstraint)
        }
    }
}

// MARK: - Node Row

struct NodeRow: View {
    @ObservedObject var model: FEAModel
    let node: FEANode

    var body: some View {
        HStack {
            Image(systemName: "circle.fill")
                .foregroundColor(.blue)
                .frame(width: 12)
            VStack(alignment: .leading, spacing: 2) {
                if !node.label.isEmpty {
                    Text(node.label)
                        .font(.caption)
                        .bold()
                }
                Text(node.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { model.deleteNode(node) }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Add Node Sheet

struct AddNodeSheet: View {
    @ObservedObject var model: FEAModel
    @Binding var isPresented: Bool

    @State private var x: Double = 0.0
    @State private var r: Double = 0.0
    @State private var label: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Node")
                .font(.title2)
                .bold()

            Form {
                HStack {
                    Text("Axial (x):")
                        .frame(width: 100, alignment: .leading)
                    TextField("", value: $x, format: .number)
                    Text("mm")
                }

                HStack {
                    Text("Radial (r):")
                        .frame(width: 100, alignment: .leading)
                    TextField("", value: $r, format: .number)
                    Text("mm")
                }

                HStack {
                    Text("Label:")
                        .frame(width: 100, alignment: .leading)
                    TextField("optional", text: $label)
                }
            }
            .padding()

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    let node = FEANode(x: x, r: r, label: label)
                    model.addNode(node)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 250)
    }
}

// MARK: - Element Rows

struct ShaftElementRow: View {
    @ObservedObject var model: FEAModel
    let element: ShaftConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "arrow.left.and.right")
                    .foregroundColor(.blue)
                Text("Shaft: \(nodeName(element.startNodeID)) → \(nodeName(element.endNodeID))")
                    .font(.caption)
                Spacer()
                Button(action: { model.deleteShaftElement(element) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            HStack {
                Text("d = \(element.diameter, specifier: "%.1f") mm")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                TextField("", value: Binding(
                    get: { element.diameter },
                    set: { newValue in
                        if let index = model.shaftElements.firstIndex(where: { $0.id == element.id }) {
                            model.shaftElements[index].diameter = newValue
                        }
                    }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            }
        }
        .padding(6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(4)
    }

    func nodeName(_ id: UUID) -> String {
        if let node = model.getNode(id: id) {
            return node.label.isEmpty ? node.description : node.label
        }
        return "???"
    }
}

struct DiskElementRow: View {
    @ObservedObject var model: FEAModel
    let element: DiskConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "circle")
                    .foregroundColor(.green)
                Text("Disk: \(nodeName(element.innerNodeID)) → \(nodeName(element.outerNodeID))")
                    .font(.caption)
                Spacer()
                Button(action: { model.deleteDiskElement(element) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            HStack {
                Text("t: \(element.thicknessBegin, specifier: "%.1f") → \(element.thicknessEnd, specifier: "%.1f") mm")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(6)
        .background(Color.green.opacity(0.1))
        .cornerRadius(4)
    }

    func nodeName(_ id: UUID) -> String {
        if let node = model.getNode(id: id) {
            return node.label.isEmpty ? node.description : node.label
        }
        return "???"
    }
}

struct ShellElementRow: View {
    @ObservedObject var model: FEAModel
    let element: ShellConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "cylinder")
                    .foregroundColor(.orange)
                Text("Shell: \(nodeName(element.startNodeID)) → \(nodeName(element.endNodeID))")
                    .font(.caption)
                Spacer()
                Button(action: { model.deleteShellElement(element) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            HStack {
                Text("r = \(element.radius, specifier: "%.1f") mm, t = \(element.thickness, specifier: "%.1f") mm")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(6)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(4)
    }

    func nodeName(_ id: UUID) -> String {
        if let node = model.getNode(id: id) {
            return node.label.isEmpty ? node.description : node.label
        }
        return "???"
    }
}

// MARK: - Add Element Sheet

struct AddElementSheet: View {
    @ObservedObject var model: FEAModel
    @Binding var isPresented: Bool

    @State private var elementType: FEAElementType = .shaft
    @State private var startNodeID: UUID?
    @State private var endNodeID: UUID?
    @State private var diameter: Double = 50.0
    @State private var radius: Double = 300.0
    @State private var thickness: Double = 10.0
    @State private var thicknessBegin: Double = 20.0
    @State private var thicknessEnd: Double = 10.0

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Element")
                .font(.title2)
                .bold()

            Form {
                Picker("Element Type", selection: $elementType) {
                    Text("Shaft").tag(FEAElementType.shaft)
                    Text("Disk").tag(FEAElementType.disk)
                    Text("Shell").tag(FEAElementType.shell)
                }

                if elementType == .shaft {
                    Picker("Start Node", selection: $startNodeID) {
                        Text("Select...").tag(nil as UUID?)
                        ForEach(model.nodes) { node in
                            Text(nodeLabel(node)).tag(node.id as UUID?)
                        }
                    }

                    Picker("End Node", selection: $endNodeID) {
                        Text("Select...").tag(nil as UUID?)
                        ForEach(model.nodes) { node in
                            Text(nodeLabel(node)).tag(node.id as UUID?)
                        }
                    }

                    HStack {
                        Text("Diameter:")
                        TextField("", value: $diameter, format: .number)
                        Text("mm")
                    }
                }

                if elementType == .disk {
                    Picker("Inner Node", selection: $startNodeID) {
                        Text("Select...").tag(nil as UUID?)
                        ForEach(model.nodes) { node in
                            Text(nodeLabel(node)).tag(node.id as UUID?)
                        }
                    }

                    Picker("Outer Node", selection: $endNodeID) {
                        Text("Select...").tag(nil as UUID?)
                        ForEach(model.nodes) { node in
                            Text(nodeLabel(node)).tag(node.id as UUID?)
                        }
                    }

                    HStack {
                        Text("Thickness (inner):")
                        TextField("", value: $thicknessBegin, format: .number)
                        Text("mm")
                    }

                    HStack {
                        Text("Thickness (outer):")
                        TextField("", value: $thicknessEnd, format: .number)
                        Text("mm")
                    }
                }

                if elementType == .shell {
                    Picker("Start Node", selection: $startNodeID) {
                        Text("Select...").tag(nil as UUID?)
                        ForEach(model.nodes) { node in
                            Text(nodeLabel(node)).tag(node.id as UUID?)
                        }
                    }

                    Picker("End Node", selection: $endNodeID) {
                        Text("Select...").tag(nil as UUID?)
                        ForEach(model.nodes) { node in
                            Text(nodeLabel(node)).tag(node.id as UUID?)
                        }
                    }

                    HStack {
                        Text("Radius:")
                        TextField("", value: $radius, format: .number)
                        Text("mm")
                    }

                    HStack {
                        Text("Thickness:")
                        TextField("", value: $thickness, format: .number)
                        Text("mm")
                    }
                }
            }
            .padding()

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    guard let start = startNodeID, let end = endNodeID else { return }

                    switch elementType {
                    case .shaft:
                        model.addShaftElement(startNodeID: start, endNodeID: end)
                        if let index = model.shaftElements.indices.last {
                            model.shaftElements[index].diameter = diameter
                        }
                    case .disk:
                        model.addDiskElement(innerNodeID: start, outerNodeID: end)
                        if let index = model.diskElements.indices.last {
                            model.diskElements[index].thicknessBegin = thicknessBegin
                            model.diskElements[index].thicknessEnd = thicknessEnd
                        }
                    case .shell:
                        model.addShellElement(startNodeID: start, endNodeID: end)
                        if let index = model.shellElements.indices.last {
                            model.shellElements[index].radius = radius
                            model.shellElements[index].thickness = thickness
                        }
                    }

                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(startNodeID == nil || endNodeID == nil)
            }
            .padding()
        }
        .frame(width: 450, height: 450)
    }

    func nodeLabel(_ node: FEANode) -> String {
        node.label.isEmpty ? node.description : node.label
    }
}

// MARK: - Constraint Row

struct ConstraintRow: View {
    @ObservedObject var model: FEAModel
    let constraint: Constraint

    var body: some View {
        HStack {
            Image(systemName: "pin.fill")
                .foregroundColor(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text(nodeName)
                    .font(.caption)
                Text("\(constraint.dofType.displayName): \(constraintDesc)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { model.deleteConstraint(constraint) }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(4)
    }

    var nodeName: String {
        if let node = model.getNode(id: constraint.nodeID) {
            return node.label.isEmpty ? node.description : node.label
        }
        return "???"
    }

    var constraintDesc: String {
        switch constraint.constraintType {
        case .fixed:
            return "= 0"
        case .prescribed:
            return "= \(constraint.value)"
        }
    }
}

// MARK: - Add Constraint Sheet

struct AddConstraintSheet: View {
    @ObservedObject var model: FEAModel
    @Binding var isPresented: Bool

    @State private var selectedNodeID: UUID?
    @State private var selectedDOF: DOFType = .w
    @State private var selectedType: ConstraintType = .fixed
    @State private var prescribedValue: Double = 0.0

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Constraint")
                .font(.title2)
                .bold()

            Form {
                Picker("Node", selection: $selectedNodeID) {
                    Text("Select node...").tag(nil as UUID?)
                    ForEach(model.nodes) { node in
                        Text(node.label.isEmpty ? node.description : node.label).tag(node.id as UUID?)
                    }
                }

                if let nodeID = selectedNodeID {
                    Picker("DOF", selection: $selectedDOF) {
                        ForEach(model.getAvailableDOFs(for: nodeID), id: \.self) { dof in
                            Text(dof.displayName).tag(dof)
                        }
                    }
                }

                Picker("Type", selection: $selectedType) {
                    Text("Fixed (= 0)").tag(ConstraintType.fixed)
                    Text("Prescribed").tag(ConstraintType.prescribed)
                }

                if selectedType == .prescribed {
                    HStack {
                        Text("Value:")
                        TextField("", value: $prescribedValue, format: .number)
                    }
                }
            }
            .padding()

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    guard let nodeID = selectedNodeID else { return }

                    let constraint = Constraint(
                        nodeID: nodeID,
                        dofType: selectedDOF,
                        constraintType: selectedType,
                        value: prescribedValue
                    )
                    model.addConstraint(constraint)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedNodeID == nil)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }
}

// MARK: - Visualization View

struct VisualizationView: View {
    @ObservedObject var model: FEAModel
    let results: FEAResults?

    var body: some View {
        Canvas { context, size in
            let padding: CGFloat = 40
            let _ = size.width - 2 * padding
            let _ = size.height - 2 * padding

            // Draw axes
            var axesPath = Path()
            axesPath.move(to: CGPoint(x: padding, y: padding))
            axesPath.addLine(to: CGPoint(x: padding, y: size.height - padding))
            axesPath.addLine(to: CGPoint(x: size.width - padding, y: size.height - padding))
            context.stroke(axesPath, with: .color(.gray), lineWidth: 1)

            // Draw nodes
            for node in model.nodes {
                let point = getNodePoint(node: node, size: size, padding: padding)
                let nodeCircle = Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
                context.fill(nodeCircle, with: .color(.blue))
                context.stroke(nodeCircle, with: .color(.black), lineWidth: 1)
            }

            // Draw shaft elements
            for element in model.shaftElements {
                guard let start = model.getNode(id: element.startNodeID),
                      let end = model.getNode(id: element.endNodeID) else { continue }

                let p1 = getNodePoint(node: start, size: size, padding: padding)
                let p2 = getNodePoint(node: end, size: size, padding: padding)

                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                context.stroke(path, with: .color(.blue), lineWidth: 3)
            }

            // Draw disk elements
            for element in model.diskElements {
                guard let inner = model.getNode(id: element.innerNodeID),
                      let outer = model.getNode(id: element.outerNodeID) else { continue }

                let p1 = getNodePoint(node: inner, size: size, padding: padding)
                let p2 = getNodePoint(node: outer, size: size, padding: padding)

                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                context.stroke(path, with: .color(.green), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }

            // Draw shell elements
            for element in model.shellElements {
                guard let start = model.getNode(id: element.startNodeID),
                      let end = model.getNode(id: element.endNodeID) else { continue }

                let p1 = getNodePoint(node: start, size: size, padding: padding)
                let p2 = getNodePoint(node: end, size: size, padding: padding)

                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                context.stroke(path, with: .color(.orange), lineWidth: 2)
            }

            // Draw constraints
            for constraint in model.constraints {
                guard let node = model.getNode(id: constraint.nodeID) else { continue }
                let point = getNodePoint(node: node, size: size, padding: padding)

                let constraintRect = Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
                context.stroke(constraintRect, with: .color(.purple), lineWidth: 2)
            }
        }
    }

    func getNodePoint(node: FEANode, size: CGSize, padding: CGFloat) -> CGPoint {
        let width = size.width - 2 * padding
        let height = size.height - 2 * padding

        // Find bounds
        let allX = model.nodes.map { $0.x }
        let allR = model.nodes.map { $0.r }

        let minX = allX.min() ?? 0
        let maxX = allX.max() ?? 1000
        let minR = allR.min() ?? 0
        let maxR = allR.max() ?? 500

        // Normalize coordinates
        let normalizedX = maxX > minX ? (node.x - minX) / (maxX - minX) : 0.5
        let normalizedR = maxR > minR ? (node.r - minR) / (maxR - minR) : 0.5

        // Map to screen coordinates
        let screenX = padding + CGFloat(normalizedX) * width
        let screenY = size.height - padding - CGFloat(normalizedR) * height

        return CGPoint(x: screenX, y: screenY)
    }
}

// MARK: - Results View

struct ResultsView: View {
    @ObservedObject var viewModel: FEAViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isRunning {
                    ProgressView("Running analysis...")
                        .padding()
                } else if let error = viewModel.error {
                    GroupBox("Error") {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                } else if let results = viewModel.results {
                    GroupBox("Analysis Complete") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Status:")
                                    .bold()
                                Text(results.success ? "✓ Converged" : "✗ Failed")
                                    .foregroundColor(results.success ? .green : .red)
                            }
                            HStack {
                                Text("DOFs:")
                                    .bold()
                                Text("\(results.totalDOFs)")
                            }
                            HStack {
                                Text("Solve Time:")
                                    .bold()
                                Text(String(format: "%.3f s", results.solveTime))
                            }
                        }
                        .font(.caption)
                    }

                    if !results.solutionVector.isEmpty {
                        GroupBox("Solution Vector") {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(Array(results.solutionVector.enumerated()), id: \.offset) { index, value in
                                        Text("DOF \(index): \(value, specifier: "%.6e")")
                                            .font(.system(.caption, design: .monospaced))
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                        }
                    }
                } else {
                    Text("No results yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
    }
}

// MARK: - View Model

class FEAViewModel: ObservableObject {
    @Published var results: FEAResults?
    @Published var isRunning = false
    @Published var error: String?

    func runAnalysis(model: FEAModel) {
        isRunning = true
        error = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let results = try model.solve()
                DispatchQueue.main.async {
                    self.results = results
                    self.isRunning = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                    self.isRunning = false
                }
            }
        }
    }
}
