import SwiftUI
import AppKit
import AxiSymFEA

@main
struct FEAViewerApp: App {
    @NSApplicationDelegateAdaptor(FEAAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1600, height: 900)
    }
}

struct ContentView: View {
    @StateObject private var feaModel = FEAModel()
    @StateObject private var viewModel = FEAViewModel()

    func saveModel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "model.json"
        panel.title = "Save FEA Model"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try feaModel.saveToFile(url)
                } catch {
                    print("Error saving model: \(error)")
                }
            }
        }
    }

    func loadModel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = "Load FEA Model"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try feaModel.loadFromFile(url)
                } catch {
                    print("Error loading model: \(error)")
                }
            }
        }
    }

    func loadExample(_ model: SerializableModel) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(model) {
            try? feaModel.loadFromData(data)
        }
    }

    var body: some View {
        HSplitView {
            // Left: Model definition
            VStack(spacing: 0) {
                // Title bar
                HStack {
                    Text("FEA Model")
                        .font(.headline)
                    Spacer()

                    Menu("Examples") {
                        ForEach(ExampleModels.allExamples, id: \.name) { example in
                            Button(example.name) {
                                loadExample(example.model)
                            }
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Load...") {
                        loadModel()
                    }
                    .buttonStyle(.bordered)

                    Button("Save...") {
                        saveModel()
                    }
                    .buttonStyle(.bordered)
                    .disabled(feaModel.nodes.isEmpty)

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

final class FEAAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        app.mainWindow?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Model Builder View

struct ModelBuilderView: View {
    @ObservedObject var model: FEAModel
    @State private var showingAddNode = false
    @State private var showingAddElement = false
    @State private var showingAddConstraint = false
    @State private var showingAddLoad = false

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
                            Button(action: { showingAddNode.toggle() }) {
                                Label(showingAddNode ? "Cancel" : "Add", systemImage: showingAddNode ? "xmark.circle" : "plus.circle")
                            }
                        }

                        if showingAddNode {
                            AddNodeForm(model: model, isShowing: $showingAddNode)
                                .padding(8)
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(8)
                        }

                        ForEach(model.nodes) { node in
                            NodeRow(model: model, node: node)
                        }

                        if model.nodes.isEmpty && !showingAddNode {
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

                // Loads
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Loads")
                                .font(.headline)
                            Spacer()
                            Button(action: { showingAddLoad = true }) {
                                Label("Add", systemImage: "plus.circle")
                            }
                            .disabled(model.nodes.isEmpty)
                        }

                        ForEach(model.loads) { load in
                            LoadRow(model: model, load: load)
                        }

                        if model.loads.isEmpty {
                            Text("No loads defined")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingAddElement) {
            AddElementSheet(model: model, isPresented: $showingAddElement)
        }
        .sheet(isPresented: $showingAddConstraint) {
            AddConstraintSheet(model: model, isPresented: $showingAddConstraint)
        }
        .sheet(isPresented: $showingAddLoad) {
            AddLoadSheet(model: model, isPresented: $showingAddLoad)
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

// MARK: - Add Node Form (Inline)

struct AddNodeForm: View {
    @ObservedObject var model: FEAModel
    @Binding var isShowing: Bool

    @State private var xText: String = "0"
    @State private var rText: String = "0"
    @State private var label: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New Node").font(.subheadline).bold()

            HStack {
                Text("x:")
                    .frame(width: 60, alignment: .leading)
                TextField("0", text: $xText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("mm")
                Spacer()
            }

            HStack {
                Text("r:")
                    .frame(width: 60, alignment: .leading)
                TextField("0", text: $rText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("mm")
                Spacer()
            }

            HStack {
                Text("Label:")
                    .frame(width: 60, alignment: .leading)
                TextField("optional", text: $label)
                    .textFieldStyle(.roundedBorder)
                Spacer()
            }

            HStack {
                Spacer()
                Button("Add Node") {
                    let x = Double(xText) ?? 0.0
                    let r = Double(rText) ?? 0.0
                    let node = FEANode(x: x, r: r, label: label)
                    model.addNode(node)
                    // Reset form
                    xText = "0"
                    rText = "0"
                    label = ""
                    isShowing = false
                }
                .buttonStyle(.borderedProminent)
            }
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
                    Picker("Node 1", selection: $startNodeID) {
                        Text("Select...").tag(nil as UUID?)
                        ForEach(model.nodes) { node in
                            Text(nodeLabel(node)).tag(node.id as UUID?)
                        }
                    }

                    Picker("Node 2", selection: $endNodeID) {
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
                    Picker("Node 1", selection: $startNodeID) {
                        Text("Select...").tag(nil as UUID?)
                        ForEach(model.nodes) { node in
                            Text(nodeLabel(node)).tag(node.id as UUID?)
                        }
                    }

                    Picker("Node 2", selection: $endNodeID) {
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
                    Picker("Node 1", selection: $startNodeID) {
                        Text("Select...").tag(nil as UUID?)
                        ForEach(model.nodes) { node in
                            Text(nodeLabel(node)).tag(node.id as UUID?)
                        }
                    }

                    Picker("Node 2", selection: $endNodeID) {
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
                    guard let node1ID = startNodeID, let node2ID = endNodeID else { return }
                    guard let node1 = model.getNode(id: node1ID), let node2 = model.getNode(id: node2ID) else { return }

                    switch elementType {
                    case .shaft:
                        // Sort by x position (axial)
                        let (startID, endID) = node1.x <= node2.x ? (node1ID, node2ID) : (node2ID, node1ID)
                        model.addShaftElement(startNodeID: startID, endNodeID: endID)
                        if let index = model.shaftElements.indices.last {
                            model.shaftElements[index].diameter = diameter
                        }
                    case .disk:
                        // Sort by r position (radial) - smaller r is inner
                        let (innerID, outerID) = node1.r <= node2.r ? (node1ID, node2ID) : (node2ID, node1ID)
                        model.addDiskElement(innerNodeID: innerID, outerNodeID: outerID)
                        if let index = model.diskElements.indices.last {
                            model.diskElements[index].thicknessBegin = thicknessBegin
                            model.diskElements[index].thicknessEnd = thicknessEnd
                        }
                    case .shell:
                        // Sort by x position (axial)
                        let (startID, endID) = node1.x <= node2.x ? (node1ID, node2ID) : (node2ID, node1ID)
                        model.addShellElement(startNodeID: startID, endNodeID: endID)
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

// MARK: - Load Row

struct LoadRow: View {
    @ObservedObject var model: FEAModel
    let load: Load

    var body: some View {
        HStack {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(nodeName)
                    .font(.caption)
                Text(load.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { model.deleteLoad(load) }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color.red.opacity(0.1))
        .cornerRadius(4)
    }

    var nodeName: String {
        if let node = model.getNode(id: load.nodeID) {
            return node.label.isEmpty ? node.description : node.label
        }
        return "???"
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

// MARK: - Add Load Sheet

struct AddLoadSheet: View {
    @ObservedObject var model: FEAModel
    @Binding var isPresented: Bool

    @State private var selectedNodeID: UUID?
    @State private var selectedDOF: DOFType = .w
    @State private var magnitude: Double = 0.0

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Load")
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

                HStack {
                    Text("Magnitude:")
                    TextField("", value: $magnitude, format: .number)
                    Text(loadUnit)
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

                    let load = Load(
                        nodeID: nodeID,
                        dofType: selectedDOF,
                        magnitude: magnitude
                    )
                    model.addLoad(load)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedNodeID == nil)
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }

    var loadUnit: String {
        switch selectedDOF {
        case .u, .v, .w:
            return "N"
        case .gamma, .phi, .beta:
            return "N·mm"
        }
    }
}

// MARK: - Visualization View

struct VisualizationView: View {
    @ObservedObject var model: FEAModel
    let results: FEAResults?

    var body: some View {
        Canvas { context, size in
            let padding: CGFloat = 40

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

            // Draw shaft elements as rectangles
            for element in model.shaftElements {
                guard let start = model.getNode(id: element.startNodeID),
                      let end = model.getNode(id: element.endNodeID) else { continue }

                let p1 = getNodePoint(node: start, size: size, padding: padding)
                let p2 = getNodePoint(node: end, size: size, padding: padding)

                // Calculate rectangle for shaft (representing diameter)
                let shaftHeight: CGFloat = 20  // Visual height for shaft
                let rect = CGRect(
                    x: min(p1.x, p2.x),
                    y: min(p1.y, p2.y) - shaftHeight/2,
                    width: abs(p2.x - p1.x),
                    height: shaftHeight
                )

                let path = Path(rect)
                context.fill(path, with: .color(.blue.opacity(0.3)))
                context.stroke(path, with: .color(.blue), lineWidth: 2)
            }

            // Draw disk elements
            for element in model.diskElements {
                guard let inner = model.getNode(id: element.innerNodeID),
                      let outer = model.getNode(id: element.outerNodeID) else { continue }

                let p1 = getNodePoint(node: inner, size: size, padding: padding)
                let p2 = getNodePoint(node: outer, size: size, padding: padding)

                // Draw as trapezoid representing thickness variation
                var path = Path()
                let t1Height = CGFloat(element.thicknessBegin) * 0.2
                let t2Height = CGFloat(element.thicknessEnd) * 0.2

                path.move(to: CGPoint(x: p1.x, y: p1.y - t1Height/2))
                path.addLine(to: CGPoint(x: p2.x, y: p2.y - t2Height/2))
                path.addLine(to: CGPoint(x: p2.x, y: p2.y + t2Height/2))
                path.addLine(to: CGPoint(x: p1.x, y: p1.y + t1Height/2))
                path.closeSubpath()

                context.fill(path, with: .color(.green.opacity(0.3)))
                context.stroke(path, with: .color(.green), lineWidth: 2)
            }

            // Draw shell elements as rectangles
            for element in model.shellElements {
                guard let start = model.getNode(id: element.startNodeID),
                      let end = model.getNode(id: element.endNodeID) else { continue }

                let p1 = getNodePoint(node: start, size: size, padding: padding)
                let p2 = getNodePoint(node: end, size: size, padding: padding)

                let shellHeight = CGFloat(element.thickness) * 0.5
                let rect = CGRect(
                    x: min(p1.x, p2.x),
                    y: min(p1.y, p2.y) - shellHeight/2,
                    width: abs(p2.x - p1.x),
                    height: shellHeight
                )

                let path = Path(rect)
                context.fill(path, with: .color(.orange.opacity(0.3)))
                context.stroke(path, with: .color(.orange), lineWidth: 2)
            }

            // Draw constraints
            for constraint in model.constraints {
                guard let node = model.getNode(id: constraint.nodeID) else { continue }
                let point = getNodePoint(node: node, size: size, padding: padding)

                let constraintRect = Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
                context.stroke(constraintRect, with: .color(.purple), lineWidth: 2)
            }

            // Draw loads
            for load in model.loads {
                guard let node = model.getNode(id: load.nodeID) else { continue }
                let point = getNodePoint(node: node, size: size, padding: padding)

                // Draw different visualizations based on load type
                switch load.dofType {
                case .beta:  // Torque - draw curved arrow
                    let radius: CGFloat = 15
                    var torquePath = Path()

                    // Draw arc - note: screen Y is inverted, so clockwise on screen = counter-clockwise in physics
                    // Positive torque (counter-clockwise in physics) appears clockwise on screen
                    torquePath.addArc(
                        center: point,
                        radius: radius,
                        startAngle: .degrees(45),
                        endAngle: .degrees(315),
                        clockwise: load.magnitude < 0  // Inverted due to screen coordinates
                    )

                    // Draw arrowhead at the end of the arc
                    let arrowAngle = load.magnitude < 0 ? 315.0 : 45.0  // Swapped for screen coordinates
                    let angleRad = arrowAngle * .pi / 180.0
                    let arrowTip = CGPoint(
                        x: point.x + radius * cos(angleRad),
                        y: point.y + radius * sin(angleRad)
                    )
                    let arrowSize: CGFloat = 8

                    // Perpendicular angle for arrowhead direction
                    let perpAngle = load.magnitude < 0 ? (angleRad - .pi / 2) : (angleRad + .pi / 2)

                    var arrowPath = Path()
                    arrowPath.move(to: arrowTip)
                    arrowPath.addLine(to: CGPoint(
                        x: arrowTip.x + arrowSize * cos(perpAngle + 0.4),
                        y: arrowTip.y + arrowSize * sin(perpAngle + 0.4)
                    ))
                    arrowPath.move(to: arrowTip)
                    arrowPath.addLine(to: CGPoint(
                        x: arrowTip.x + arrowSize * cos(perpAngle - 0.4),
                        y: arrowTip.y + arrowSize * sin(perpAngle - 0.4)
                    ))

                    context.stroke(torquePath, with: .color(.red), lineWidth: 2)
                    context.stroke(arrowPath, with: .color(.red), lineWidth: 2)

                case .w:  // Transverse force - vertical arrow
                    let arrowLength: CGFloat = 25
                    let direction = load.magnitude > 0 ? -1.0 : 1.0

                    var arrowPath = Path()
                    arrowPath.move(to: point)
                    let endPoint = CGPoint(x: point.x, y: point.y + CGFloat(direction) * arrowLength)
                    arrowPath.addLine(to: endPoint)

                    // Arrowhead
                    arrowPath.move(to: endPoint)
                    arrowPath.addLine(to: CGPoint(x: endPoint.x - 5, y: endPoint.y - CGFloat(direction) * 8))
                    arrowPath.move(to: endPoint)
                    arrowPath.addLine(to: CGPoint(x: endPoint.x + 5, y: endPoint.y - CGFloat(direction) * 8))

                    context.stroke(arrowPath, with: .color(.red), lineWidth: 2)

                case .u:  // Axial force - horizontal arrow
                    let arrowLength: CGFloat = 25
                    let direction = load.magnitude > 0 ? 1.0 : -1.0

                    var arrowPath = Path()
                    arrowPath.move(to: point)
                    let endPoint = CGPoint(x: point.x + CGFloat(direction) * arrowLength, y: point.y)
                    arrowPath.addLine(to: endPoint)

                    // Arrowhead
                    arrowPath.move(to: endPoint)
                    arrowPath.addLine(to: CGPoint(x: endPoint.x - CGFloat(direction) * 8, y: endPoint.y - 5))
                    arrowPath.move(to: endPoint)
                    arrowPath.addLine(to: CGPoint(x: endPoint.x - CGFloat(direction) * 8, y: endPoint.y + 5))

                    context.stroke(arrowPath, with: .color(.red), lineWidth: 2)

                case .v:  // Tangential force - diagonal arrow
                    let arrowLength: CGFloat = 25
                    let direction = load.magnitude > 0 ? 1.0 : -1.0

                    var arrowPath = Path()
                    arrowPath.move(to: point)
                    let endPoint = CGPoint(x: point.x + CGFloat(direction) * arrowLength * 0.707, y: point.y + CGFloat(direction) * arrowLength * 0.707)
                    arrowPath.addLine(to: endPoint)

                    // Arrowhead
                    arrowPath.move(to: endPoint)
                    arrowPath.addLine(to: CGPoint(x: endPoint.x - 8, y: endPoint.y))
                    arrowPath.move(to: endPoint)
                    arrowPath.addLine(to: CGPoint(x: endPoint.x, y: endPoint.y - 8))

                    context.stroke(arrowPath, with: .color(.red), lineWidth: 2)

                case .gamma, .phi:  // Moments - small curved arrow
                    let radius: CGFloat = 12
                    var momentPath = Path()

                    momentPath.addArc(
                        center: point,
                        radius: radius,
                        startAngle: .degrees(0),
                        endAngle: .degrees(270),
                        clockwise: load.magnitude > 0
                    )

                    context.stroke(momentPath, with: .color(.red), lineWidth: 2)
                }
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
                                Text("Mode:")
                                    .bold()
                                Text("\(results.analysisMode)")
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

                    if results.success, let model = viewModel.model {
                        // Graphs (if shaft elements exist)
                        if !model.shaftElements.isEmpty {
                            GroupBox("Axial Force Distribution") {
                                AxialForceGraphView(model: model, results: results)
                                    .frame(height: 200)
                            }

                            GroupBox("Axial Displacement Distribution") {
                                AxialDisplacementGraphView(model: model, results: results)
                                    .frame(height: 200)
                            }

                            GroupBox("Torque Distribution") {
                                TorqueGraphView(model: model, results: results)
                                    .frame(height: 200)
                            }

                            GroupBox("Angular Displacement Distribution") {
                                AngularDisplacementGraphView(model: model, results: results)
                                    .frame(height: 200)
                            }
                        }

                        // Reaction Forces
                        if !results.reactionForces.isEmpty {
                            GroupBox("Reaction Forces") {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(results.reactionForces) { reaction in
                                        if let node = model.getNode(id: reaction.nodeID) {
                                            HStack {
                                                Image(systemName: "arrow.up.circle.fill")
                                                    .foregroundColor(.purple)
                                                    .frame(width: 12)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(node.label.isEmpty ? node.description : node.label)
                                                        .font(.caption)
                                                        .bold()
                                                    Text("\(reaction.dofType.displayName): \(reaction.magnitude, specifier: "%.3e") \(reactionUnit(for: reaction.dofType))")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                            }
                                            .padding(6)
                                            .background(Color.purple.opacity(0.1))
                                            .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                        }

                        GroupBox("Node Displacements") {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(results.nodeDisplacements.sorted(by: { model.getNode(id: $0.key)?.x ?? 0 < model.getNode(id: $1.key)?.x ?? 0 })), id: \.key) { nodeID, disps in
                                        if let node = model.getNode(id: nodeID) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(node.label.isEmpty ? node.description : node.label)
                                                    .font(.caption)
                                                    .bold()
                                                ForEach(Array(disps.enumerated()), id: \.offset) { index, value in
                                                    Text("  DOF[\(index)]: \(value, specifier: "%.6e")")
                                                        .font(.system(.caption2, design: .monospaced))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
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

    func reactionUnit(for dofType: DOFType) -> String {
        switch dofType {
        case .u, .v, .w:
            return "N"  // Force
        case .gamma, .phi, .beta:
            return "N·mm"  // Moment/Torque
        }
    }
}

// MARK: - View Model

@MainActor
class FEAViewModel: ObservableObject {
    @Published var results: FEAResults?
    @Published var isRunning = false
    @Published var error: String?
    var model: FEAModel?

    func runAnalysis(model: FEAModel) {
        self.model = model
        isRunning = true
        error = nil

        Task {
            do {
                // Run the solve operation (it handles background execution internally)
                let results = try await model.solve()

                self.results = results
                self.isRunning = false
            } catch {
                self.error = error.localizedDescription
                self.isRunning = false
            }
        }
    }
}
