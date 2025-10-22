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

        // TODO: Apply boundary conditions and loads based on user input
        // For now, just solve the assembled system

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
        results = nil
    }
}

// MARK: - Errors

enum FEAError: LocalizedError {
    case noElements
    case solutionFailed

    var errorDescription: String? {
        switch self {
        case .noElements:
            return "No elements in model. Add at least one element."
        case .solutionFailed:
            return "FEA solver failed to converge"
        }
    }
}
