import Foundation
import AxiSymFEA

// MARK: - Node Configuration

struct FEANode: Identifiable, Codable, Sendable {
    let id: UUID
    var x: Double
    var r: Double
    var label: String

    init(id: UUID = UUID(), x: Double = 0.0, r: Double = 0.0, label: String = "") {
        self.id = id
        self.x = x
        self.r = r
        self.label = label
    }

    var description: String {
        if !label.isEmpty {
            return label
        }
        return String(format: "(x=%.1f, r=%.1f)", x, r)
    }
}

// MARK: - Element Types

enum FEAElementType: String, Identifiable, CaseIterable, Sendable {
    case shaft
    case disk
    case shell

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shaft: return "Shaft Element"
        case .disk: return "Disk Element"
        case .shell: return "Shell Element"
        }
    }
}

// MARK: - Element Configuration

struct ShaftConfig: Identifiable, Codable, Sendable {
    let id: UUID
    var startNodeID: UUID
    var endNodeID: UUID
    var diameter: Double
    private var modelString: String
    var mode: Int  // Fourier mode: 0 (axial/torsion), 1/-1 (bending)

    init(id: UUID = UUID(), startNodeID: UUID, endNodeID: UUID, diameter: Double = 50.0, model: ShaftElement.ShaftModel = .timoshenko(), mode: Int = 0) {
        self.id = id
        self.startNodeID = startNodeID
        self.endNodeID = endNodeID
        self.diameter = diameter
        self.modelString = model == .eulerBernoulli ? "eulerBernoulli" : "timoshenko"
        self.mode = mode
    }

    var model: ShaftElement.ShaftModel {
        get {
            modelString == "eulerBernoulli" ? .eulerBernoulli : .timoshenko()
        }
        set {
            modelString = newValue == .eulerBernoulli ? "eulerBernoulli" : "timoshenko"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, startNodeID, endNodeID, diameter, modelString, mode
    }
}

struct DiskConfig: Identifiable, Codable, Sendable {
    let id: UUID
    var innerNodeID: UUID
    var outerNodeID: UUID
    var thicknessBegin: Double
    var thicknessEnd: Double
    var mode: Int

    init(id: UUID = UUID(), innerNodeID: UUID, outerNodeID: UUID, thicknessBegin: Double = 20.0, thicknessEnd: Double = 10.0, mode: Int = 0) {
        self.id = id
        self.innerNodeID = innerNodeID
        self.outerNodeID = outerNodeID
        self.thicknessBegin = thicknessBegin
        self.thicknessEnd = thicknessEnd
        self.mode = mode
    }
}

struct ShellConfig: Identifiable, Codable, Sendable {
    let id: UUID
    var startNodeID: UUID
    var endNodeID: UUID
    var radius: Double
    var thickness: Double
    private var modelString: String
    var mode: Int

    init(id: UUID = UUID(), startNodeID: UUID, endNodeID: UUID, radius: Double = 300.0, thickness: Double = 10.0, model: ShellElement.ShellModel = .ventselKrauthammer, mode: Int = 1) {
        self.id = id
        self.startNodeID = startNodeID
        self.endNodeID = endNodeID
        self.radius = radius
        self.thickness = thickness
        self.modelString = "ventselKrauthammer"  // The only shell theory FEAViewer offers
        self.mode = mode
    }

    var model: ShellElement.ShellModel {
        get {
            .ventselKrauthammer  // Only one model type
        }
        set {
            modelString = "ventselKrauthammer"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, startNodeID, endNodeID, radius, thickness, modelString, mode
    }
}

// MARK: - Material Configuration

struct MaterialConfig: Codable, Sendable {
    var youngsModulus: Double = 210000.0  // MPa (Steel)
    var poissonsRatio: Double = 0.3
    var density: Double = 7850.0          // kg/m³
}

// MARK: - Constraint Configuration

enum DOFType: String, Codable, CaseIterable, Sendable {
    // Shaft DOFs
    case w       // Transverse displacement
    case gamma   // Rotation
    case u       // Axial displacement
    case beta    // Torsional rotation

    // Disk/Shell DOFs
    case v       // Tangential displacement
    case phi     // Rotation

    var displayName: String {
        switch self {
        case .w: return "w (transverse)"
        case .gamma: return "γ (rotation)"
        case .u: return "u (axial)"
        case .beta: return "β (torsion)"
        case .v: return "v (tangential)"
        case .phi: return "φ (rotation)"
        }
    }
}

enum ConstraintType: String, Codable, Sendable {
    case fixed              // DOF = 0
    case prescribed         // DOF = specified value

    var displayName: String {
        switch self {
        case .fixed: return "Fixed (= 0)"
        case .prescribed: return "Prescribed"
        }
    }
}

struct Constraint: Identifiable, Codable, Sendable {
    let id: UUID
    var nodeID: UUID
    var dofType: DOFType
    var constraintType: ConstraintType
    var value: Double

    init(id: UUID = UUID(), nodeID: UUID, dofType: DOFType, constraintType: ConstraintType, value: Double = 0.0) {
        self.id = id
        self.nodeID = nodeID
        self.dofType = dofType
        self.constraintType = constraintType
        self.value = value
    }
}

// MARK: - Load Configuration

struct Load: Identifiable, Codable, Sendable {
    let id: UUID
    var nodeID: UUID
    var dofType: DOFType
    var magnitude: Double

    init(id: UUID = UUID(), nodeID: UUID, dofType: DOFType, magnitude: Double = 0.0) {
        self.id = id
        self.nodeID = nodeID
        self.dofType = dofType
        self.magnitude = magnitude
    }

    var description: String {
        let dofStr = dofType.displayName
        return "\(dofStr): \(magnitude) \(unit)"
    }

    var unit: String {
        switch dofType {
        case .u, .v, .w:
            return "N"  // Force
        case .gamma, .phi, .beta:
            return "N·mm"  // Moment/Torque
        }
    }
}

// MARK: - FEA Results

struct ReactionForce: Identifiable, Sendable {
    let id = UUID()
    let constraintID: UUID
    let nodeID: UUID
    let dofType: DOFType
    let magnitude: Double
}

struct FEAResults: Sendable {
    let solveTime: TimeInterval
    let totalDOFs: Int
    let solutionVector: [Double]
    let success: Bool
    let nodeDisplacements: [UUID: [Double]]  // Maps node UUID to DOF displacements
    let analysisMode: Int
    let reactionForces: [ReactionForce]  // Reaction forces at constraints
}

// MARK: - Serializable Model

struct SerializableModel: Codable, Sendable {
    var nodes: [FEANode]
    var shaftElements: [ShaftConfig]
    var diskElements: [DiskConfig]
    var shellElements: [ShellConfig]
    var material: MaterialConfig
    var constraints: [Constraint]
    var loads: [Load]
}

// MARK: - FEA Model

@MainActor
class FEAModel: ObservableObject {

    // MARK: - Published Properties

    @Published var nodes: [FEANode] = []
    @Published var shaftElements: [ShaftConfig] = []
    @Published var diskElements: [DiskConfig] = []
    @Published var shellElements: [ShellConfig] = []
    @Published var material = MaterialConfig()
    @Published var constraints: [Constraint] = []
    @Published var loads: [Load] = []
    @Published var results: FEAResults?

    // MARK: - Node Management

    func addNode(_ node: FEANode) {
        nodes.append(node)
    }

    func deleteNode(_ node: FEANode) {
        // Check if node is used by any elements
        let isUsedByShaft = shaftElements.contains { $0.startNodeID == node.id || $0.endNodeID == node.id }
        let isUsedByDisk = diskElements.contains { $0.innerNodeID == node.id || $0.outerNodeID == node.id }
        let isUsedByShell = shellElements.contains { $0.startNodeID == node.id || $0.endNodeID == node.id }

        if isUsedByShaft || isUsedByDisk || isUsedByShell {
            // Cannot delete node that is referenced by elements
            return
        }

        // Remove node and any constraints on it
        nodes.removeAll { $0.id == node.id }
        constraints.removeAll { $0.nodeID == node.id }
    }

    func getNode(id: UUID) -> FEANode? {
        return nodes.first { $0.id == id }
    }

    // MARK: - Element Management

    func addShaftElement(startNodeID: UUID, endNodeID: UUID) {
        // Validate that shaft element nodes are at r=0
        if let startNode = getNode(id: startNodeID), abs(startNode.r) > 1e-6 {
            print("Warning: Shaft element start node '\(startNode.label.isEmpty ? startNode.description : startNode.label)' should be at r=0 (currently r=\(startNode.r))")
        }

        if let endNode = getNode(id: endNodeID), abs(endNode.r) > 1e-6 {
            print("Warning: Shaft element end node '\(endNode.label.isEmpty ? endNode.description : endNode.label)' should be at r=0 (currently r=\(endNode.r))")
        }

        let newElement = ShaftConfig(
            startNodeID: startNodeID,
            endNodeID: endNodeID
        )
        shaftElements.append(newElement)
    }

    func deleteShaftElement(_ element: ShaftConfig) {
        shaftElements.removeAll { $0.id == element.id }
    }

    func addDiskElement(innerNodeID: UUID, outerNodeID: UUID) {
        let newElement = DiskConfig(
            innerNodeID: innerNodeID,
            outerNodeID: outerNodeID
        )
        diskElements.append(newElement)
    }

    func deleteDiskElement(_ element: DiskConfig) {
        diskElements.removeAll { $0.id == element.id }
    }

    func addShellElement(startNodeID: UUID, endNodeID: UUID) {
        let newElement = ShellConfig(
            startNodeID: startNodeID,
            endNodeID: endNodeID
        )
        shellElements.append(newElement)
    }

    func deleteShellElement(_ element: ShellConfig) {
        shellElements.removeAll { $0.id == element.id }
    }

    // MARK: - Constraint Management

    func addConstraint(_ constraint: Constraint) {
        constraints.append(constraint)
    }

    func deleteConstraint(_ constraint: Constraint) {
        constraints.removeAll { $0.id == constraint.id }
    }

    func getConstrainedDOFs(for nodeID: UUID) -> Set<DOFType> {
        return Set(constraints.filter { $0.nodeID == nodeID }.map { $0.dofType })
    }

    // MARK: - Load Management

    func addLoad(_ load: Load) {
        loads.append(load)
    }

    func deleteLoad(_ load: Load) {
        loads.removeAll { $0.id == load.id }
    }

    func getAvailableDOFs(for nodeID: UUID) -> [DOFType] {
        // Determine which DOFs exist at this node based on connected elements
        var dofs = Set<DOFType>()

        // Check if node is used by shaft elements
        let usedByShaft = shaftElements.contains { $0.startNodeID == nodeID || $0.endNodeID == nodeID }
        if usedByShaft {
            dofs.insert(.w)
            dofs.insert(.gamma)
            dofs.insert(.u)
            dofs.insert(.beta)
        }

        // Check if node is used by disk elements
        let usedByDisk = diskElements.contains { $0.innerNodeID == nodeID || $0.outerNodeID == nodeID }
        if usedByDisk {
            dofs.insert(.u)
            dofs.insert(.v)
            dofs.insert(.w)
            dofs.insert(.phi)
        }

        // Check if node is used by shell elements
        let usedByShell = shellElements.contains { $0.startNodeID == nodeID || $0.endNodeID == nodeID }
        if usedByShell {
            dofs.insert(.u)
            dofs.insert(.v)
            dofs.insert(.w)
            dofs.insert(.phi)
        }

        // If node not used by any elements, return all possible DOFs
        if dofs.isEmpty {
            return DOFType.allCases
        }

        return Array(dofs).sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Model Validation

    /// Validates the model before analysis
    /// - Throws: FEAError if validation fails
    func validateModel() throws {
        // Check for nodes
        guard !nodes.isEmpty else {
            throw FEAError.noElements
        }

        // Check for at least one element
        let totalElements = shaftElements.count + diskElements.count + shellElements.count
        guard totalElements > 0 else {
            throw FEAError.noElements
        }

        // Validate material properties
        guard material.youngsModulus > 0 else {
            throw FEAError.invalidElement("Young's modulus must be positive (got \(material.youngsModulus))")
        }
        guard material.poissonsRatio >= 0 && material.poissonsRatio < 0.5 else {
            throw FEAError.invalidElement("Poisson's ratio must be between 0 and 0.5 (got \(material.poissonsRatio))")
        }
        guard material.density > 0 else {
            throw FEAError.invalidElement("Density must be positive (got \(material.density))")
        }

        // Validate shaft elements
        for element in shaftElements {
            guard element.diameter > 0 else {
                throw FEAError.invalidElement("Shaft diameter must be positive")
            }
            guard getNode(id: element.startNodeID) != nil else {
                throw FEAError.invalidElement("Shaft element references non-existent start node")
            }
            guard getNode(id: element.endNodeID) != nil else {
                throw FEAError.invalidElement("Shaft element references non-existent end node")
            }
        }

        // Validate disk elements
        for element in diskElements {
            guard element.thicknessBegin > 0 && element.thicknessEnd > 0 else {
                throw FEAError.invalidElement("Disk thickness must be positive")
            }
            guard getNode(id: element.innerNodeID) != nil else {
                throw FEAError.invalidElement("Disk element references non-existent inner node")
            }
            guard getNode(id: element.outerNodeID) != nil else {
                throw FEAError.invalidElement("Disk element references non-existent outer node")
            }
        }

        // Validate shell elements
        for element in shellElements {
            guard element.radius > 0 && element.thickness > 0 else {
                throw FEAError.invalidElement("Shell radius and thickness must be positive")
            }
            guard getNode(id: element.startNodeID) != nil else {
                throw FEAError.invalidElement("Shell element references non-existent start node")
            }
            guard getNode(id: element.endNodeID) != nil else {
                throw FEAError.invalidElement("Shell element references non-existent end node")
            }
        }

        // Validate constraints reference existing nodes
        for constraint in constraints {
            guard getNode(id: constraint.nodeID) != nil else {
                throw FEAError.invalidConstraint("Constraint references non-existent node")
            }
        }

        // Validate loads reference existing nodes
        for load in loads {
            guard getNode(id: load.nodeID) != nil else {
                throw FEAError.invalidLoad("Load references non-existent node")
            }
        }
    }

    // MARK: - FEA Execution

    func solve() async throws -> FEAResults {
        // Validate model before solving
        try validateModel()

        // Capture all the model data we need on the main actor
        let modelData = SerializableModel(
            nodes: nodes,
            shaftElements: shaftElements,
            diskElements: diskElements,
            shellElements: shellElements,
            material: material,
            constraints: constraints,
            loads: loads
        )

        // Perform the actual solve in a background task
        let results = try await Task.detached {
            try Self.performSolve(with: modelData)
        }.value

        // Store results back on main actor
        self.results = results
        return results
    }

    nonisolated private static func performSolve(with modelData: SerializableModel) throws -> FEAResults {
        let startTime = Date()
        let exact = GeometryTolerance.exact
        let feaNodes = Dictionary(uniqueKeysWithValues: modelData.nodes.map { ($0.id, $0) })
        func name(_ node: FEANode) -> String { node.label.isEmpty ? node.description : node.label }

        // A node's degrees of freedom are fixed by its layout: w, γ, u, β on a shaft node and
        // u, v, w, φ on a disk or shell node. AxiSymFEA can't share one node between the two;
        // a shaft joins a disk through a connector element instead.
        let shaftNodeIDs = Set(modelData.shaftElements.flatMap { [$0.startNodeID, $0.endNodeID] })
        let shellDiskNodeIDs = Set(modelData.diskElements.flatMap { [$0.innerNodeID, $0.outerNodeID] }
            + modelData.shellElements.flatMap { [$0.startNodeID, $0.endNodeID] })
        if let shared = modelData.nodes.first(where: { shaftNodeIDs.contains($0.id) && shellDiskNodeIDs.contains($0.id) }) {
            throw FEAError.invalidElement("Node '\(name(shared))' joins a shaft to a disk or shell. A shaft node carries different degrees of freedom, so the two can't share a node.")
        }

        var nodeMap: [UUID: Node] = [:]
        for (index, feaNode) in modelData.nodes.enumerated() {
            nodeMap[feaNode.id] = shaftNodeIDs.contains(feaNode.id)
                ? Node.shaft(id: index, z: feaNode.x)
                : Node.shellDisk(id: index, r: feaNode.r, z: feaNode.x)
        }
        let material = Material(youngsModulus: modelData.material.youngsModulus,
                                poissonsRatio: modelData.material.poissonsRatio)

        // AxiSymFEA checks each element's geometry with preconditions, which would stop the app,
        // so a model that breaks one is refused here with an error instead.
        var elements: [any Element] = []
        for config in modelData.shaftElements {
            guard let start = feaNodes[config.startNodeID], let end = feaNodes[config.endNodeID],
                  let startNode = nodeMap[config.startNodeID], let endNode = nodeMap[config.endNodeID] else {
                throw FEAError.invalidElement("Shaft element has invalid nodes")
            }
            for node in [start, end] where abs(node.r) > 1e-6 {
                throw FEAError.invalidElement("Shaft element node '\(name(node))' must be at r=0 (currently r=\(node.r))")
            }
            guard !exact.matches(start.x, end.x) else {
                throw FEAError.invalidElement("Shaft element from '\(name(start))' to '\(name(end))' has zero length")
            }
            guard config.diameter.isFinite, config.diameter > 0 else {
                throw FEAError.invalidElement("Shaft element diameter must be positive (currently \(config.diameter))")
            }
            elements.append(ShaftElement(node1: startNode, node2: endNode, diameter: config.diameter,
                                         material: material, mode: config.mode, model: config.model))
        }
        for config in modelData.diskElements {
            guard let inner = feaNodes[config.innerNodeID], let outer = feaNodes[config.outerNodeID],
                  let innerNode = nodeMap[config.innerNodeID], let outerNode = nodeMap[config.outerNodeID] else {
                throw FEAError.invalidElement("Disk element has invalid nodes")
            }
            guard exact.matches(inner.x, outer.x) else {
                throw FEAError.invalidElement("Disk element nodes '\(name(inner))' and '\(name(outer))' must be at the same axial position")
            }
            guard inner.r > 0, outer.r > inner.r else {
                throw FEAError.invalidElement("Disk element needs 0 < inner radius < outer radius (currently \(inner.r) and \(outer.r))")
            }
            guard [config.thicknessBegin, config.thicknessEnd].allSatisfy({ $0.isFinite && $0 > 0 }) else {
                throw FEAError.invalidElement("Disk element thicknesses must be positive")
            }
            elements.append(DiskElement(innerNode: innerNode, outerNode: outerNode,
                                        thicknessBegin: config.thicknessBegin, thicknessEnd: config.thicknessEnd,
                                        material: material, mode: config.mode))
        }
        for config in modelData.shellElements {
            guard let start = feaNodes[config.startNodeID], let end = feaNodes[config.endNodeID],
                  let startNode = nodeMap[config.startNodeID], let endNode = nodeMap[config.endNodeID] else {
                throw FEAError.invalidElement("Shell element has invalid nodes")
            }
            guard exact.matches(start.r, end.r) else {
                throw FEAError.invalidElement("Shell element nodes '\(name(start))' and '\(name(end))' must be at the same radius")
            }
            guard start.r > 0 else {
                throw FEAError.invalidElement("Shell element radius must be positive (currently r=\(start.r))")
            }
            guard !exact.matches(start.x, end.x) else {
                throw FEAError.invalidElement("Shell element from '\(name(start))' to '\(name(end))' has zero length")
            }
            guard config.thickness.isFinite, config.thickness > 0 else {
                throw FEAError.invalidElement("Shell element thickness must be positive (currently \(config.thickness))")
            }
            elements.append(ShellElement(node1: startNode, node2: endNode, thickness: config.thickness,
                                         material: material, mode: config.mode, model: config.model))
        }
        guard !elements.isEmpty else { throw FEAError.noElements }

        // Every element is built for the model's Fourier mode.
        let modes = modelData.shaftElements.map { $0.mode } + modelData.diskElements.map { $0.mode } + modelData.shellElements.map { $0.mode }
        let analysisMode = modes.first ?? 0
        if let other = modes.first(where: { $0 != analysisMode }) {
            throw FEAError.invalidElement("Every element must use the same Fourier mode; this model mixes \(analysisMode) and \(other)")
        }

        // The node and quantity a constraint or load acts on.
        func target(_ nodeID: UUID, _ dofType: DOFType, _ invalid: (String) -> FEAError, _ subject: String) throws -> (Node, DOFKind) {
            guard let node = nodeMap[nodeID] else { throw invalid("\(subject) references non-existent node") }
            let onShaft = shaftNodeIDs.contains(nodeID)
            guard onShaft || shellDiskNodeIDs.contains(nodeID) else { throw invalid("\(subject) is on a node no element uses") }
            guard let kind = Self.dofKind(for: dofType, onShaftNode: onShaft) else {
                throw invalid(onShaft ? "Invalid DOF type for shaft element" : "Invalid DOF type for disk/shell element")
            }
            return (node, kind)
        }
        let conditions: [BoundaryCondition] = try modelData.constraints.map { constraint in
            let (node, kind) = try target(constraint.nodeID, constraint.dofType, FEAError.invalidConstraint, "Constraint")
            switch constraint.constraintType {
            case .fixed: return .fixed(kind, at: node)
            case .prescribed: return .prescribed(kind, value: constraint.value, at: node)
            }
        }
        let loads: [HarmonicNodalLoad] = try modelData.loads.map { load in
            let (node, kind) = try target(load.nodeID, load.dofType, FEAError.invalidLoad, "Load")
            return HarmonicNodalLoad(load.magnitude, on: kind, at: node)
        }

        let model = AxisymmetricModel(mode: analysisMode, elements: elements)
        let solution: HarmonicSolution
        do {
            solution = try HarmonicProblem(model: model, boundaryConditions: conditions, nodalLoads: loads).solve(output: .none)
        } catch {
            throw FEAError.analysisFailed((error as? LocalizedError)?.errorDescription ?? String(describing: error))
        }
        let solveTime = Date().timeIntervalSince(startTime)

        // Displacements in each node's own order, as above, and the solution as those in node order.
        var nodeDisplacements: [UUID: [Double]] = [:]
        var solutionVector: [Double] = []
        for feaNode in modelData.nodes where shaftNodeIDs.contains(feaNode.id) || shellDiskNodeIDs.contains(feaNode.id) {
            guard let node = nodeMap[feaNode.id] else { continue }
            let displacements = try node.dofLayout.kinds.map { try solution.displacement($0, at: node) }
            nodeDisplacements[feaNode.id] = displacements
            solutionVector += displacements
        }
        let reactionForces = try modelData.constraints.map { constraint in
            let (node, kind) = try target(constraint.nodeID, constraint.dofType, FEAError.invalidConstraint, "Constraint")
            return ReactionForce(constraintID: constraint.id, nodeID: constraint.nodeID,
                                 dofType: constraint.dofType, magnitude: try solution.reaction(kind, at: node))
        }

        return FEAResults(
            solveTime: solveTime,
            totalDOFs: solutionVector.count,
            solutionVector: solutionVector,
            success: true,
            nodeDisplacements: nodeDisplacements,
            analysisMode: analysisMode,
            reactionForces: reactionForces
        )
    }

    func clear() {
        nodes.removeAll()
        shaftElements.removeAll()
        diskElements.removeAll()
        shellElements.removeAll()
        constraints.removeAll()
        loads.removeAll()
        results = nil
    }

    // MARK: - Save/Load

    func saveToFile(_ url: URL) throws {
        let model = SerializableModel(
            nodes: nodes,
            shaftElements: shaftElements,
            diskElements: diskElements,
            shellElements: shellElements,
            material: material,
            constraints: constraints,
            loads: loads
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(model)
        try data.write(to: url)
    }

    func loadFromFile(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let model = try decoder.decode(SerializableModel.self, from: data)

        self.nodes = model.nodes
        self.shaftElements = model.shaftElements
        self.diskElements = model.diskElements
        self.shellElements = model.shellElements
        self.material = model.material
        self.constraints = model.constraints
        self.loads = model.loads
        self.results = nil
    }

    func loadFromData(_ data: Data) throws {
        let decoder = JSONDecoder()
        let model = try decoder.decode(SerializableModel.self, from: data)

        self.nodes = model.nodes
        self.shaftElements = model.shaftElements
        self.diskElements = model.diskElements
        self.shellElements = model.shellElements
        self.material = model.material
        self.constraints = model.constraints
        self.loads = model.loads
        self.results = nil
    }

    // MARK: - Private Helper Methods

    /// The AxiSymFEA quantity a DOF names: w, γ, u, β on a shaft node, and u, v, w, φ on a disk or
    /// shell node, which are the orders of AxiSymFEA's `shaft` and `shellDisk` layouts.
    nonisolated private static func dofKind(for dofType: DOFType, onShaftNode: Bool) -> DOFKind? {
        if onShaftNode {
            switch dofType {
            case .w: return .radial
            case .gamma: return .meridionalRotation
            case .u: return .axial
            case .beta: return .torsion
            default: return nil
            }
        }
        switch dofType {
        case .u: return .axial
        case .v: return .tangential
        case .w: return .radial
        case .phi: return .meridionalRotation
        default: return nil
        }
    }
}

// MARK: - Errors

enum FEAError: LocalizedError, Sendable {
    case noElements
    case solutionFailed
    case analysisFailed(String)
    case invalidConstraint(String)
    case invalidElement(String)
    case invalidLoad(String)

    var errorDescription: String? {
        switch self {
        case .noElements:
            return "No elements in model. Add at least one element."
        case .solutionFailed:
            return "FEA solver failed to converge"
        case .analysisFailed(let message):
            return "Analysis failed: \(message)"
        case .invalidConstraint(let message):
            return "Invalid constraint: \(message)"
        case .invalidElement(let message):
            return "Invalid element: \(message)"
        case .invalidLoad(let message):
            return "Invalid load: \(message)"
        }
    }
}
