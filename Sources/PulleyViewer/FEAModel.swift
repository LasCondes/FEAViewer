import Foundation
import PulleyFEA
import PulleyCore

// MARK: - Model Parameters

/// Parameters defining the cantilever beam geometry and loading
struct CantileverBeamParameters {
    var length: Double          // mm
    var diameter: Double        // mm
    var load: Double           // N (negative = downward)
    var youngsModulus: Double  // MPa
    var poissonsRatio: Double

    static var `default`: CantileverBeamParameters {
        CantileverBeamParameters(
            length: 1000.0,
            diameter: 50.0,
            load: -1000.0,
            youngsModulus: 210000.0,
            poissonsRatio: 0.3
        )
    }
}

// MARK: - Analysis Results

/// Results from FEA analysis
struct FEAResults {
    // Computed displacements
    let endDeflection: Double      // mm
    let endRotation: Double        // rad

    // Analytical comparison
    let analyticalDeflection: Double  // mm
    let error: Double                 // percentage

    // Additional info
    let solveTime: TimeInterval       // seconds
    let totalDOFs: Int

    var errorPercentage: Double {
        error * 100.0
    }
}

// MARK: - FEA Model

/// Encapsulates the finite element analysis model and execution
class CantileverBeamModel {

    // MARK: - Properties

    private(set) var parameters: CantileverBeamParameters
    private(set) var results: FEAResults?

    // MARK: - Initialization

    init(parameters: CantileverBeamParameters = .default) {
        self.parameters = parameters
    }

    // MARK: - Model Building

    /// Build and solve the FEA model
    func solve() throws -> FEAResults {
        let startTime = Date()

        // Create FE assembly
        let assembly = FEAssembly()

        // Create shaft element
        let element = ShaftElement(
            diameter: parameters.diameter,
            axialPositionStart: 0.0,
            axialPositionEnd: parameters.length,
            youngsModulus: parameters.youngsModulus,
            poissonsRatio: parameters.poissonsRatio,
            mode: 0,
            model: .timoshenko
        )

        // Add element and assemble
        assembly.addElement(element)
        assembly.assemble(mode: 0)

        let totalDOFs = assembly.variableCount()

        // Get node references
        let node0 = element.nodes[0]  // Fixed end
        let node1 = element.nodes[1]  // Free end

        let node0DOFs = assembly.getDOFIndices(forNode: node0)
        let node1DOFs = assembly.getDOFIndices(forNode: node1)

        // Apply boundary conditions (fixed at left end)
        assembly.fixDOF(node0DOFs[0])  // w = 0
        assembly.fixDOF(node0DOFs[1])  // gamma = 0
        assembly.fixDOF(node0DOFs[2])  // u = 0
        assembly.fixDOF(node0DOFs[3])  // beta = 0

        // Apply load at free end
        assembly.applyForce(parameters.load, atDOF: node1DOFs[0])

        // Solve the system
        guard assembly.solve() else {
            throw FEAError.solutionFailed
        }

        // Extract results
        guard let w1 = assembly.getDisplacement(atDOF: node1DOFs[0]),
              let gamma1 = assembly.getDisplacement(atDOF: node1DOFs[1]) else {
            throw FEAError.resultExtractionFailed
        }

        // Calculate analytical solution (Euler-Bernoulli)
        let I = Double.pi * pow(parameters.diameter, 4) / 64.0
        let analytical = abs(parameters.load) * pow(parameters.length, 3) /
                        (3.0 * parameters.youngsModulus * I)

        // Calculate error
        let error = abs(abs(w1) - analytical) / analytical

        let solveTime = Date().timeIntervalSince(startTime)

        let results = FEAResults(
            endDeflection: w1,
            endRotation: gamma1,
            analyticalDeflection: analytical,
            error: error,
            solveTime: solveTime,
            totalDOFs: totalDOFs
        )

        self.results = results
        return results
    }

    // MARK: - Parameter Updates

    func updateParameters(_ parameters: CantileverBeamParameters) {
        self.parameters = parameters
        self.results = nil  // Invalidate results
    }

    func updateLength(_ length: Double) {
        parameters.length = length
        results = nil
    }

    func updateDiameter(_ diameter: Double) {
        parameters.diameter = diameter
        results = nil
    }

    func updateLoad(_ load: Double) {
        parameters.load = load
        results = nil
    }
}

// MARK: - Errors

enum FEAError: LocalizedError {
    case solutionFailed
    case resultExtractionFailed

    var errorDescription: String? {
        switch self {
        case .solutionFailed:
            return "FEA solver failed to converge"
        case .resultExtractionFailed:
            return "Failed to extract results from solution"
        }
    }
}
