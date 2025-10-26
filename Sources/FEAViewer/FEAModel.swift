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

    init(id: UUID = UUID(), startNodeID: UUID, endNodeID: UUID, diameter: Double = 50.0, model: ShaftElement.ShaftModel = .timoshenko, mode: Int = 0) {
        self.id = id
        self.startNodeID = startNodeID
        self.endNodeID = endNodeID
        self.diameter = diameter
        self.modelString = model == .eulerBernoulli ? "eulerBernoulli" : "timoshenko"
        self.mode = mode
    }

    var model: ShaftElement.ShaftModel {
        get {
            modelString == "eulerBernoulli" ? .eulerBernoulli : .timoshenko
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
        self.modelString = model == .ventselKrauthammer ? "ventselKrauthammer" : "ventselKrauthammer"  // Only one model available
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

        // Create assembly
        let assembly = FEAssembly()

        // Map to store AxiSymFEA nodes created from our FEANodes
        var nodeMap: [UUID: Node] = [:]

        // First, create all unique nodes with sequential IDs
        for (index, feaNode) in modelData.nodes.enumerated() {
            // All elements (shaft, disk, shell) use 4 DOFs
            let axiSymNode = Node(id: index, r: feaNode.r, z: feaNode.x, numberOfDisplacements: 4)
            nodeMap[feaNode.id] = axiSymNode
        }

        // Add shaft elements using the created nodes
        for config in modelData.shaftElements {
            guard let startNode = nodeMap[config.startNodeID],
                  let endNode = nodeMap[config.endNodeID] else {
                throw FEAError.invalidElement("Shaft element has invalid nodes")
            }

            // Validate that shaft element nodes are at r=0 (on centerline)
            guard let startFEANode = modelData.nodes.first(where: { $0.id == config.startNodeID }),
                  let endFEANode = modelData.nodes.first(where: { $0.id == config.endNodeID }) else {
                throw FEAError.invalidElement("Shaft element references non-existent nodes")
            }

            if abs(startFEANode.r) > 1e-6 {
                throw FEAError.invalidElement("Shaft element start node '\(startFEANode.label.isEmpty ? startFEANode.description : startFEANode.label)' must be at r=0 (currently r=\(startFEANode.r))")
            }

            if abs(endFEANode.r) > 1e-6 {
                throw FEAError.invalidElement("Shaft element end node '\(endFEANode.label.isEmpty ? endFEANode.description : endFEANode.label)' must be at r=0 (currently r=\(endFEANode.r))")
            }

            let element = ShaftElement(
                node1: startNode,
                node2: endNode,
                diameter: config.diameter,
                youngsModulus: modelData.material.youngsModulus,
                poissonsRatio: modelData.material.poissonsRatio,
                mode: config.mode,
                model: config.model
            )
            assembly.addElement(element)
        }

        // Add disk elements using the created nodes
        for config in modelData.diskElements {
            guard let innerNode = nodeMap[config.innerNodeID],
                  let outerNode = nodeMap[config.outerNodeID] else {
                throw FEAError.invalidElement("Disk element has invalid nodes")
            }

            let element = DiskElement(
                innerNode: innerNode,
                outerNode: outerNode,
                thicknessBegin: config.thicknessBegin,
                thicknessEnd: config.thicknessEnd,
                youngsModulus: modelData.material.youngsModulus,
                poissonsRatio: modelData.material.poissonsRatio,
                useNumericalIntegration: true,
                mode: config.mode
            )
            assembly.addElement(element)
        }

        // Add shell elements using the created nodes
        for config in modelData.shellElements {
            guard let startNode = nodeMap[config.startNodeID],
                  let endNode = nodeMap[config.endNodeID] else {
                throw FEAError.invalidElement("Shell element has invalid nodes")
            }

            let element = ShellElement(
                node1: startNode,
                node2: endNode,
                thickness: config.thickness,
                youngsModulus: modelData.material.youngsModulus,
                poissonsRatio: modelData.material.poissonsRatio,
                useNumericalIntegration: false,
                mode: config.mode,
                model: config.model
            )
            assembly.addElement(element)
        }

        // Determine mode from elements (use mode 0 if mixed or empty)
        let modes = modelData.shaftElements.map { $0.mode } + modelData.diskElements.map { $0.mode } + modelData.shellElements.map { $0.mode }
        let analysisMode = modes.first ?? 0

        // Assemble system
        assembly.assemble(mode: analysisMode)

        let totalDOFs = assembly.variableCount()

        // Apply constraints
        try Self.applyConstraints(modelData: modelData, assembly: assembly, nodeMap: nodeMap)

        // Apply loads
        try Self.applyLoads(modelData: modelData, assembly: assembly, nodeMap: nodeMap)

        let success = assembly.solve()

        let solveTime = Date().timeIntervalSince(startTime)

        let solutionVector = assembly.getSolution()?.flattenedData ?? []

        // Extract node displacements
        var nodeDisplacements: [UUID: [Double]] = [:]
        for (nodeID, axiSymNode) in nodeMap {
            let dofIndices = assembly.getDOFIndices(forNode: axiSymNode)
            var disps: [Double] = []
            for dofIndex in dofIndices {
                if dofIndex < solutionVector.count {
                    disps.append(solutionVector[dofIndex])
                }
            }
            nodeDisplacements[nodeID] = disps
        }

        // Calculate reaction forces at constraints using the assembly API
        let reactionsByDOF = assembly.getReactionForces()

        var reactionForces: [ReactionForce] = []
        for constraint in modelData.constraints {
            guard let axiSymNode = nodeMap[constraint.nodeID] else { continue }

            // Get element type to determine DOF ordering
            let elementType = Self.getElementTypeForNode(constraint.nodeID, in: modelData)
            guard let dofIndex = try? Self.getDOFIndex(for: constraint.dofType, elementType: elementType) else {
                continue
            }

            let dofIndices = assembly.getDOFIndices(forNode: axiSymNode)
            guard dofIndex < dofIndices.count else { continue }

            let globalDOF = dofIndices[dofIndex]

            // Get reaction force from the assembly
            let reactionMagnitude = reactionsByDOF[globalDOF] ?? 0.0

            reactionForces.append(ReactionForce(
                constraintID: constraint.id,
                nodeID: constraint.nodeID,
                dofType: constraint.dofType,
                magnitude: reactionMagnitude
            ))
        }

        return FEAResults(
            solveTime: solveTime,
            totalDOFs: totalDOFs,
            solutionVector: solutionVector,
            success: success,
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

    nonisolated private static func applyConstraints(modelData: SerializableModel, assembly: FEAssembly, nodeMap: [UUID: Node]) throws {
        // Apply each constraint directly using node references
        for constraint in modelData.constraints {
            guard modelData.nodes.contains(where: { $0.id == constraint.nodeID }) else {
                throw FEAError.invalidConstraint("Constraint references non-existent node")
            }

            guard let axiSymNode = nodeMap[constraint.nodeID] else {
                throw FEAError.invalidConstraint("Node not found in assembly")
            }

            let dofIndices = assembly.getDOFIndices(forNode: axiSymNode)

            // Determine element type from which element uses this node
            let elementType = Self.getElementTypeForNode(constraint.nodeID, in: modelData)
            let dofIndex = try Self.getDOFIndex(for: constraint.dofType, elementType: elementType)

            guard dofIndex < dofIndices.count else {
                throw FEAError.invalidConstraint("DOF index out of range")
            }

            let globalDOF = dofIndices[dofIndex]

            switch constraint.constraintType {
            case .fixed:
                assembly.fixDOF(globalDOF)
            case .prescribed:
                assembly.prescribeDisplacement(constraint.value, atDOF: globalDOF)
            }
        }
    }

    nonisolated private static func getElementTypeForNode(_ nodeID: UUID, in modelData: SerializableModel) -> FEAElementType? {
        // Check which type of element uses this node
        if modelData.shaftElements.contains(where: { $0.startNodeID == nodeID || $0.endNodeID == nodeID }) {
            return .shaft
        }
        if modelData.diskElements.contains(where: { $0.innerNodeID == nodeID || $0.outerNodeID == nodeID }) {
            return .disk
        }
        if modelData.shellElements.contains(where: { $0.startNodeID == nodeID || $0.endNodeID == nodeID }) {
            return .shell
        }
        return nil
    }

    nonisolated private static func getDOFIndex(for dofType: DOFType, elementType: FEAElementType?) throws -> Int {
        // Map DOF type to index based on element type
        switch elementType {
        case .shaft:
            // Shaft DOF order: [w, gamma, u, beta]
            switch dofType {
            case .w: return 0
            case .gamma: return 1
            case .u: return 2
            case .beta: return 3
            default:
                throw FEAError.invalidConstraint("Invalid DOF type for shaft element")
            }

        case .disk, .shell:
            // Disk/Shell DOF order: [u, v, w, phi]
            switch dofType {
            case .u: return 0
            case .v: return 1
            case .w: return 2
            case .phi: return 3
            default:
                throw FEAError.invalidConstraint("Invalid DOF type for disk/shell element")
            }

        case nil:
            // Node not connected to any element, assume disk/shell DOF ordering
            switch dofType {
            case .u: return 0
            case .v: return 1
            case .w: return 2
            case .phi: return 3
            default: return 0
            }
        }
    }

    nonisolated private static func applyLoads(modelData: SerializableModel, assembly: FEAssembly, nodeMap: [UUID: Node]) throws {
        // Apply each load to the corresponding DOF
        for load in modelData.loads {
            guard modelData.nodes.contains(where: { $0.id == load.nodeID }) else {
                throw FEAError.invalidLoad("Load references non-existent node")
            }

            guard let axiSymNode = nodeMap[load.nodeID] else {
                throw FEAError.invalidLoad("Node not found in assembly")
            }

            let dofIndices = assembly.getDOFIndices(forNode: axiSymNode)

            // Determine element type from which element uses this node
            let elementType = Self.getElementTypeForNode(load.nodeID, in: modelData)
            let dofIndex = try Self.getDOFIndex(for: load.dofType, elementType: elementType)

            guard dofIndex < dofIndices.count else {
                throw FEAError.invalidLoad("DOF index out of range")
            }

            let globalDOF = dofIndices[dofIndex]
            assembly.applyForce(load.magnitude, atDOF: globalDOF)
        }
    }
}

// MARK: - Errors

enum FEAError: LocalizedError, Sendable {
    case noElements
    case solutionFailed
    case invalidConstraint(String)
    case invalidElement(String)
    case invalidLoad(String)

    var errorDescription: String? {
        switch self {
        case .noElements:
            return "No elements in model. Add at least one element."
        case .solutionFailed:
            return "FEA solver failed to converge"
        case .invalidConstraint(let message):
            return "Invalid constraint: \(message)"
        case .invalidElement(let message):
            return "Invalid element: \(message)"
        case .invalidLoad(let message):
            return "Invalid load: \(message)"
        }
    }
}
