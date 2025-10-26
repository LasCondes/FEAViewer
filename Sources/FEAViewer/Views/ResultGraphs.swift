import SwiftUI
import AxiSymFEA

// MARK: - Axial Force Graph

struct AxialForceGraphView: View {
    let model: FEAModel
    let results: FEAResults

    var body: some View {
        BaseGraphView(
            data: calculateAxialForceData(),
            xAxisLabel: "Position (mm)",
            yAxisLabel: "Axial Force (N)"
        )
    }

    private func calculateAxialForceData() -> GraphData {
        var forceData: [(x: Double, force: Double)] = []
        let E = model.material.youngsModulus

        for element in model.shaftElements {
            guard let node1 = model.getNode(id: element.startNodeID),
                  let node2 = model.getNode(id: element.endNodeID),
                  let disps1 = results.nodeDisplacements[element.startNodeID],
                  let disps2 = results.nodeDisplacements[element.endNodeID],
                  disps1.count > 2, disps2.count > 2 else { continue }

            // DOF order for shaft: [w, gamma, u, beta] - u is at index 2
            let u1 = disps1[2]
            let u2 = disps2[2]

            // Calculate axial force: F = E * A / L * Δu
            let diameter = element.diameter
            let A = .pi * pow(diameter, 2) / 4.0
            let L = abs(node2.x - node1.x)
            let force = L > 0 ? E * A / L * (u2 - u1) : 0.0

            forceData.append((x: node1.x, force: force))
            forceData.append((x: node2.x, force: force))
        }

        return GraphData(points: forceData.map { (x: $0.x, y: $0.force) }, color: .orange)
    }
}

// MARK: - Axial Displacement Graph

struct AxialDisplacementGraphView: View {
    let model: FEAModel
    let results: FEAResults

    var body: some View {
        BaseGraphView(
            data: calculateAxialDisplacementData(),
            xAxisLabel: "Position (mm)",
            yAxisLabel: "Axial Displacement u (mm)",
            yFormat: "%.3e"
        )
    }

    private func calculateAxialDisplacementData() -> GraphData {
        var axialData: [(x: Double, u: Double)] = []

        for node in model.nodes {
            let isShaftNode = model.shaftElements.contains {
                $0.startNodeID == node.id || $0.endNodeID == node.id
            }

            if isShaftNode, let disps = results.nodeDisplacements[node.id], disps.count > 2 {
                let u = disps[2]  // u is at index 2
                axialData.append((x: node.x, u: u))
            }
        }

        return GraphData(
            points: axialData.map { (x: $0.x, y: $0.u) },
            color: .purple,
            showPoints: true
        )
    }
}

// MARK: - Torque Graph

struct TorqueGraphView: View {
    let model: FEAModel
    let results: FEAResults

    var body: some View {
        BaseGraphView(
            data: calculateTorqueData(),
            xAxisLabel: "Position (mm)",
            yAxisLabel: "Torque (N·mm)"
        )
    }

    private func calculateTorqueData() -> GraphData {
        var torqueData: [(x: Double, torque: Double)] = []

        let E = model.material.youngsModulus
        let nu = model.material.poissonsRatio
        let G = E / (2.0 * (1.0 + nu))  // Shear modulus

        for element in model.shaftElements {
            guard let node1 = model.getNode(id: element.startNodeID),
                  let node2 = model.getNode(id: element.endNodeID),
                  let disps1 = results.nodeDisplacements[element.startNodeID],
                  let disps2 = results.nodeDisplacements[element.endNodeID],
                  disps1.count > 3, disps2.count > 3 else { continue }

            // DOF order for shaft: [w, gamma, u, beta] - beta is at index 3
            let beta1 = disps1[3]
            let beta2 = disps2[3]

            // Calculate torque: T = G * J / L * Δβ
            let diameter = element.diameter
            let J = .pi * pow(diameter, 4) / 32.0  // Polar moment of inertia
            let L = abs(node2.x - node1.x)
            let torque = L > 0 ? G * J / L * (beta2 - beta1) : 0.0

            torqueData.append((x: node1.x, torque: torque))
            torqueData.append((x: node2.x, torque: torque))
        }

        return GraphData(points: torqueData.map { (x: $0.x, y: $0.torque) }, color: .blue)
    }
}

// MARK: - Angular Displacement Graph

struct AngularDisplacementGraphView: View {
    let model: FEAModel
    let results: FEAResults

    var body: some View {
        BaseGraphView(
            data: calculateAngularDisplacementData(),
            xAxisLabel: "Position (mm)",
            yAxisLabel: "Angular Displacement β (rad)",
            yFormat: "%.3e"
        )
    }

    private func calculateAngularDisplacementData() -> GraphData {
        var angularData: [(x: Double, beta: Double)] = []

        for node in model.nodes {
            let isShaftNode = model.shaftElements.contains {
                $0.startNodeID == node.id || $0.endNodeID == node.id
            }

            if isShaftNode, let disps = results.nodeDisplacements[node.id], disps.count > 3 {
                let beta = disps[3]  // beta is at index 3
                angularData.append((x: node.x, beta: beta))
            }
        }

        return GraphData(
            points: angularData.map { (x: $0.x, y: $0.beta) },
            color: .green,
            showPoints: true
        )
    }
}
