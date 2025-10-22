import Foundation
import AxiSymFEA

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
    var diameter: Double = 50.0           // mm
    var startPosition: Double = 0.0       // mm
    var endPosition: Double = 1000.0      // mm
    var model: ShaftElement.ShaftModel = .timoshenko
}

struct DiskConfig: Identifiable {
    let id = UUID()
    var innerRadius: Double = 100.0       // mm
    var outerRadius: Double = 500.0       // mm
    var thicknessBegin: Double = 20.0     // mm
    var thicknessEnd: Double = 10.0       // mm
    var mode: Int = 0
}

struct ShellConfig: Identifiable {
    let id = UUID()
    var radius: Double = 300.0            // mm
    var thickness: Double = 10.0          // mm
    var startPosition: Double = 0.0       // mm
    var endPosition: Double = 500.0       // mm
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

enum ConstraintLocation: String, Codable, CaseIterable {
    case shaftStart
    case shaftEnd
    case diskInner
    case diskOuter
    case shellStart
    case shellEnd

    var displayName: String {
        switch self {
        case .shaftStart: return "Shaft Start"
        case .shaftEnd: return "Shaft End"
        case .diskInner: return "Disk Inner"
        case .diskOuter: return "Disk Outer"
        case .shellStart: return "Shell Start"
        case .shellEnd: return "Shell End"
        }
    }
}

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
    var elementIndex: Int           // Index in respective array
    var location: ConstraintLocation
    var dofType: DOFType
    var constraintType: ConstraintType
    var value: Double = 0.0         // For prescribed displacements

    var description: String {
        let locStr = location.displayName
        let dofStr = dofType.displayName
        let typeStr = constraintType == .fixed ? "= 0" : "= \(value)"
        return "\(locStr), \(dofStr) \(typeStr)"
    }
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

    @Published var shaftElements: [ShaftConfig] = []
    @Published var diskElements: [DiskConfig] = []
    @Published var shellElements: [ShellConfig] = []
    @Published var material = MaterialConfig()
    @Published var constraints: [Constraint] = []
    @Published var results: FEAResults?

    // MARK: - Element Management

    func addShaftElement() {
        // Position new element after the last one
        let lastPosition = shaftElements.last?.endPosition ?? 0.0
        var newElement = ShaftConfig()
        newElement.startPosition = lastPosition
        newElement.endPosition = lastPosition + 1000.0
        shaftElements.append(newElement)
    }

    func deleteShaftElement(_ element: ShaftConfig) {
        shaftElements.removeAll { $0.id == element.id }
    }

    func addDiskElement() {
        var newElement = DiskConfig()
        // Position new disk outside the last one
        if let lastDisk = diskElements.last {
            newElement.innerRadius = lastDisk.outerRadius
            newElement.outerRadius = lastDisk.outerRadius + 400.0
        }
        diskElements.append(newElement)
    }

    func deleteDiskElement(_ element: DiskConfig) {
        diskElements.removeAll { $0.id == element.id }
    }

    func addShellElement() {
        // Position new element after the last one
        let lastPosition = shellElements.last?.endPosition ?? 0.0
        var newElement = ShellConfig()
        newElement.startPosition = lastPosition
        newElement.endPosition = lastPosition + 500.0
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

    func getAvailableDOFs(for location: ConstraintLocation) -> [DOFType] {
        switch location {
        case .shaftStart, .shaftEnd:
            return [.w, .gamma, .u, .beta]
        case .diskInner, .diskOuter:
            return [.u, .v, .w, .phi]
        case .shellStart, .shellEnd:
            return [.u, .v, .w, .phi]
        }
    }

    // MARK: - FEA Execution

    func solve() throws -> FEAResults {
        let startTime = Date()

        // Create assembly
        let assembly = FEAssembly()

        // Add shaft elements
        for config in shaftElements {
            let element = ShaftElement(
                diameter: config.diameter,
                axialPositionStart: config.startPosition,
                axialPositionEnd: config.endPosition,
                youngsModulus: material.youngsModulus,
                poissonsRatio: material.poissonsRatio,
                mode: 0,
                model: config.model
            )
            assembly.addElement(element)
        }

        // Add disk elements
        for config in diskElements {
            let element = DiskElement(
                innerRadius: config.innerRadius,
                outerRadius: config.outerRadius,
                thicknessBegin: config.thicknessBegin,
                thicknessEnd: config.thicknessEnd,
                youngsModulus: material.youngsModulus,
                poissonsRatio: material.poissonsRatio,
                useNumericalIntegration: true,
                mode: config.mode
            )
            assembly.addElement(element)
        }

        // Add shell elements
        for config in shellElements {
            let element = ShellElement(
                radius: config.radius,
                thickness: config.thickness,
                axialPositionStart: config.startPosition,
                axialPositionEnd: config.endPosition,
                youngsModulus: material.youngsModulus,
                poissonsRatio: material.poissonsRatio,
                useNumericalIntegration: false,
                mode: config.mode,
                model: config.model
            )
            assembly.addElement(element)
        }

        // Assemble system
        assembly.assemble(mode: 0)

        let totalDOFs = assembly.variableCount()

        // Apply constraints
        try applyConstraints(assembly: assembly)

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
        shaftElements.removeAll()
        diskElements.removeAll()
        shellElements.removeAll()
        constraints.removeAll()
        results = nil
    }

    // MARK: - Private Helper Methods

    private func applyConstraints(assembly: FEAssembly) throws {
        // Store element references for constraint application
        var shaftElementRefs: [Element] = []
        var diskElementRefs: [Element] = []
        var shellElementRefs: [Element] = []

        // Rebuild element list to match assembly order
        for config in shaftElements {
            let element = ShaftElement(
                diameter: config.diameter,
                axialPositionStart: config.startPosition,
                axialPositionEnd: config.endPosition,
                youngsModulus: material.youngsModulus,
                poissonsRatio: material.poissonsRatio,
                mode: 0,
                model: config.model
            )
            shaftElementRefs.append(element)
        }

        for config in diskElements {
            let element = DiskElement(
                innerRadius: config.innerRadius,
                outerRadius: config.outerRadius,
                thicknessBegin: config.thicknessBegin,
                thicknessEnd: config.thicknessEnd,
                youngsModulus: material.youngsModulus,
                poissonsRatio: material.poissonsRatio,
                useNumericalIntegration: true,
                mode: config.mode
            )
            diskElementRefs.append(element)
        }

        for config in shellElements {
            let element = ShellElement(
                radius: config.radius,
                thickness: config.thickness,
                axialPositionStart: config.startPosition,
                axialPositionEnd: config.endPosition,
                youngsModulus: material.youngsModulus,
                poissonsRatio: material.poissonsRatio,
                useNumericalIntegration: false,
                mode: config.mode,
                model: config.model
            )
            shellElementRefs.append(element)
        }

        // Apply each constraint
        for constraint in constraints {
            let (element, nodeIndex) = try getElementAndNode(
                constraint: constraint,
                shaftRefs: shaftElementRefs,
                diskRefs: diskElementRefs,
                shellRefs: shellElementRefs
            )

            let node = element.nodes[nodeIndex]
            let dofIndices = assembly.getDOFIndices(forNode: node)
            let dofIndex = try getDOFIndex(for: constraint.dofType, in: constraint.location)

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

    private func getElementAndNode(
        constraint: Constraint,
        shaftRefs: [Element],
        diskRefs: [Element],
        shellRefs: [Element]
    ) throws -> (Element, Int) {
        switch constraint.location {
        case .shaftStart:
            guard constraint.elementIndex < shaftRefs.count else {
                throw FEAError.invalidConstraint("Shaft element index out of range")
            }
            return (shaftRefs[constraint.elementIndex], 0)

        case .shaftEnd:
            guard constraint.elementIndex < shaftRefs.count else {
                throw FEAError.invalidConstraint("Shaft element index out of range")
            }
            return (shaftRefs[constraint.elementIndex], 1)

        case .diskInner:
            guard constraint.elementIndex < diskRefs.count else {
                throw FEAError.invalidConstraint("Disk element index out of range")
            }
            return (diskRefs[constraint.elementIndex], 0)

        case .diskOuter:
            guard constraint.elementIndex < diskRefs.count else {
                throw FEAError.invalidConstraint("Disk element index out of range")
            }
            return (diskRefs[constraint.elementIndex], 1)

        case .shellStart:
            guard constraint.elementIndex < shellRefs.count else {
                throw FEAError.invalidConstraint("Shell element index out of range")
            }
            return (shellRefs[constraint.elementIndex], 0)

        case .shellEnd:
            guard constraint.elementIndex < shellRefs.count else {
                throw FEAError.invalidConstraint("Shell element index out of range")
            }
            return (shellRefs[constraint.elementIndex], 1)
        }
    }

    private func getDOFIndex(for dofType: DOFType, in location: ConstraintLocation) throws -> Int {
        // Map DOF type to index based on element type
        switch location {
        case .shaftStart, .shaftEnd:
            // Shaft DOF order: [w, gamma, u, beta]
            switch dofType {
            case .w: return 0
            case .gamma: return 1
            case .u: return 2
            case .beta: return 3
            default:
                throw FEAError.invalidConstraint("Invalid DOF type for shaft element")
            }

        case .diskInner, .diskOuter, .shellStart, .shellEnd:
            // Disk/Shell DOF order: [u, v, w, phi]
            switch dofType {
            case .u: return 0
            case .v: return 1
            case .w: return 2
            case .phi: return 3
            default:
                throw FEAError.invalidConstraint("Invalid DOF type for disk/shell element")
            }
        }
    }
}

// MARK: - Errors

enum FEAError: LocalizedError {
    case noElements
    case solutionFailed
    case invalidConstraint(String)

    var errorDescription: String? {
        switch self {
        case .noElements:
            return "No elements in model. Add at least one element."
        case .solutionFailed:
            return "FEA solver failed to converge"
        case .invalidConstraint(let message):
            return "Invalid constraint: \(message)"
        }
    }
}
