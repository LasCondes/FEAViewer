import Foundation
import AxiSymFEA

// MARK: - Node Configuration

enum NodeType: String, Codable {
    case shaft      // On shaft axis (axial position only)
    case disk       // On disk (radial position)
    case shell      // On shell (axial position)

    var displayName: String {
        switch self {
        case .shaft: return "Shaft Node"
        case .disk: return "Disk Node"
        case .shell: return "Shell Node"
        }
    }
}

struct FEANode: Identifiable, Codable {
    let id = UUID()
    var type: NodeType
    var axialPosition: Double?      // For shaft/shell nodes (z-coordinate)
    var radialPosition: Double?     // For disk nodes (r-coordinate)
    var label: String = ""

    // Convenience initializers
    static func shaft(z: Double, label: String = "") -> FEANode {
        FEANode(type: .shaft, axialPosition: z, radialPosition: nil, label: label)
    }

    static func disk(r: Double, label: String = "") -> FEANode {
        FEANode(type: .disk, axialPosition: nil, radialPosition: r, label: label)
    }

    static func shell(z: Double, label: String = "") -> FEANode {
        FEANode(type: .shell, axialPosition: z, radialPosition: nil, label: label)
    }

    var description: String {
        if !label.isEmpty {
            return label
        }
        switch type {
        case .shaft, .shell:
            return "z = \(axialPosition ?? 0)"
        case .disk:
            return "r = \(radialPosition ?? 0)"
        }
    }
}

// MARK: - Element Types

enum FEAElementType: String, Identifiable, CaseIterable {
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

struct ShaftConfig: Identifiable {
    let id = UUID()
    var startNodeID: UUID
    var endNodeID: UUID
    var diameter: Double = 50.0           // mm
    var model: ShaftElement.ShaftModel = .timoshenko
}

struct DiskConfig: Identifiable {
    let id = UUID()
    var innerNodeID: UUID
    var outerNodeID: UUID
    var thicknessBegin: Double = 20.0     // mm
    var thicknessEnd: Double = 10.0       // mm
    var mode: Int = 0
}

struct ShellConfig: Identifiable {
    let id = UUID()
    var startNodeID: UUID
    var endNodeID: UUID
    var radius: Double = 300.0            // mm
    var thickness: Double = 10.0          // mm
    var model: ShellElement.ShellModel = .ventselKrauthammer
    var mode: Int = 1
}

// MARK: - Material Configuration

struct MaterialConfig {
    var youngsModulus: Double = 210000.0  // MPa (Steel)
    var poissonsRatio: Double = 0.3
    var density: Double = 7850.0          // kg/m³
}

// MARK: - Constraint Configuration

enum DOFType: String, Codable, CaseIterable {
    // Shaft DOFs
    case w       // Transverse displacement
    case gamma   // Rotation
    case u       // Axial displacement
    case beta    // Torsional rotation

    // Disk/Shell DOFs (in addition to u, v, w)
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

    // Get available DOFs for a node type
    static func availableDOFs(for nodeType: NodeType) -> [DOFType] {
        switch nodeType {
        case .shaft:
            return [.w, .gamma, .u, .beta]
        case .disk, .shell:
            return [.u, .v, .w, .phi]
        }
    }
}

enum ConstraintType: String, Codable {
    case fixed              // DOF = 0
    case prescribed         // DOF = specified value

    var displayName: String {
        switch self {
        case .fixed: return "Fixed (= 0)"
        case .prescribed: return "Prescribed"
        }
    }
}

struct Constraint: Identifiable, Codable {
    let id = UUID()
    var nodeID: UUID
    var dofType: DOFType
    var constraintType: ConstraintType
    var value: Double = 0.0         // For prescribed displacements
}

// MARK: - FEA Results

struct FEAResults {
    let solveTime: TimeInterval
    let totalDOFs: Int
    let solutionVector: [Double]
    let success: Bool
}

// MARK: - FEA Model

class FEAModel: ObservableObject {

    // MARK: - Published Properties

    @Published var nodes: [FEANode] = []
    @Published var shaftElements: [ShaftConfig] = []
    @Published var diskElements: [DiskConfig] = []
    @Published var shellElements: [ShellConfig] = []
    @Published var material = MaterialConfig()
    @Published var constraints: [Constraint] = []
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

    // MARK: - FEA Execution

    func solve() throws -> FEAResults {
        let startTime = Date()

        // Create assembly
        let assembly = FEAssembly()

        // Map to store AxiSymFEA nodes created from our FEANodes
        var nodeMap: [UUID: Node] = [:]

        // Create AxiSymFEA elements with proper node references
        var elementList: [(Element, [UUID])] = []

        // Add shaft elements
        for config in shaftElements {
            guard let startNode = getNode(id: config.startNodeID),
                  let endNode = getNode(id: config.endNodeID),
                  let startZ = startNode.axialPosition,
                  let endZ = endNode.axialPosition else {
                throw FEAError.invalidElement("Shaft element has invalid nodes")
            }

            let element = ShaftElement(
                diameter: config.diameter,
                axialPositionStart: startZ,
                axialPositionEnd: endZ,
                youngsModulus: material.youngsModulus,
                poissonsRatio: material.poissonsRatio,
                mode: 0,
                model: config.model
            )
            elementList.append((element, [config.startNodeID, config.endNodeID]))
            assembly.addElement(element)
        }

        // Add disk elements
        for config in diskElements {
            guard let innerNode = getNode(id: config.innerNodeID),
                  let outerNode = getNode(id: config.outerNodeID),
                  let innerR = innerNode.radialPosition,
                  let outerR = outerNode.radialPosition else {
                throw FEAError.invalidElement("Disk element has invalid nodes")
            }

            let element = DiskElement(
                innerRadius: innerR,
                outerRadius: outerR,
                thicknessBegin: config.thicknessBegin,
                thicknessEnd: config.thicknessEnd,
                youngsModulus: material.youngsModulus,
                poissonsRatio: material.poissonsRatio,
                useNumericalIntegration: true,
                mode: config.mode
            )
            elementList.append((element, [config.innerNodeID, config.outerNodeID]))
            assembly.addElement(element)
        }

        // Add shell elements
        for config in shellElements {
            guard let startNode = getNode(id: config.startNodeID),
                  let endNode = getNode(id: config.endNodeID),
                  let startZ = startNode.axialPosition,
                  let endZ = endNode.axialPosition else {
                throw FEAError.invalidElement("Shell element has invalid nodes")
            }

            let element = ShellElement(
                radius: config.radius,
                thickness: config.thickness,
                axialPositionStart: startZ,
                axialPositionEnd: endZ,
                youngsModulus: material.youngsModulus,
                poissonsRatio: material.poissonsRatio,
                useNumericalIntegration: false,
                mode: config.mode,
                model: config.model
            )
            elementList.append((element, [config.startNodeID, config.endNodeID]))
            assembly.addElement(element)
        }

        // Assemble system
        assembly.assemble(mode: 0)

        // Build node map: FEANode UUID -> AxiSymFEA Node
        for (element, nodeIDs) in elementList {
            for (index, nodeID) in nodeIDs.enumerated() {
                if nodeMap[nodeID] == nil {
                    nodeMap[nodeID] = element.nodes[index]
                }
            }
        }

        let totalDOFs = assembly.variableCount()

        // Apply constraints
        try applyConstraints(assembly: assembly, nodeMap: nodeMap)

        let success = assembly.solve()

        let solveTime = Date().timeIntervalSince(startTime)

        let solutionVector = assembly.getSolution()?.flattenedData ?? []

        let results = FEAResults(
            solveTime: solveTime,
            totalDOFs: totalDOFs,
            solutionVector: solutionVector,
            success: success
        )

        self.results = results
        return results
    }

    func clear() {
        nodes.removeAll()
        shaftElements.removeAll()
        diskElements.removeAll()
        shellElements.removeAll()
        constraints.removeAll()
        results = nil
    }

    // MARK: - Private Helper Methods

    private func applyConstraints(assembly: FEAssembly, nodeMap: [UUID: Node]) throws {
        // Apply each constraint directly using node references
        for constraint in constraints {
            guard let feaNode = getNode(id: constraint.nodeID) else {
                throw FEAError.invalidConstraint("Constraint references non-existent node")
            }

            guard let axiSymNode = nodeMap[constraint.nodeID] else {
                throw FEAError.invalidConstraint("Node not found in assembly")
            }

            let dofIndices = assembly.getDOFIndices(forNode: axiSymNode)
            let dofIndex = try getDOFIndex(for: constraint.dofType, in: feaNode.type)

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

    private func getDOFIndex(for dofType: DOFType, in nodeType: NodeType) throws -> Int {
        // Map DOF type to index based on node type
        switch nodeType {
        case .shaft:
            // Shaft DOF order: [w, gamma, u, beta]
            switch dofType {
            case .w: return 0
            case .gamma: return 1
            case .u: return 2
            case .beta: return 3
            default:
                throw FEAError.invalidConstraint("Invalid DOF type for shaft node")
            }

        case .disk, .shell:
            // Disk/Shell DOF order: [u, v, w, phi]
            switch dofType {
            case .u: return 0
            case .v: return 1
            case .w: return 2
            case .phi: return 3
            default:
                throw FEAError.invalidConstraint("Invalid DOF type for disk/shell node")
            }
        }
    }
}

// MARK: - Errors

enum FEAError: LocalizedError {
    case noElements
    case solutionFailed
    case invalidConstraint(String)
    case invalidElement(String)

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
        }
    }
}
