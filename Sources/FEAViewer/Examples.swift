import Foundation

// MARK: - Example Models

struct ExampleModels {

    struct Example {
        let name: String
        let filename: String
    }

    static let examples: [Example] = [
        Example(name: "Simply Supported Shaft (500mm)", filename: "simply-supported-shaft.json"),
        Example(name: "Torque Shaft (Torsion)", filename: "torque-shaft.json"),
        Example(name: "Axial Load Shaft (Tension)", filename: "axial-load-shaft.json")
    ]

    static func loadExample(filename: String) -> SerializableModel? {
        // Try to load from Bundle.module first (for SPM resources)
        if let url = Bundle.module.url(forResource: "Resources/\(filename.replacingOccurrences(of: ".json", with: ""))", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let model = try decoder.decode(SerializableModel.self, from: data)
                return model
            } catch {
                print("Error decoding example from bundle: \(error)")
            }
        }

        // Fallback: try to find the file in the Resources directory relative to current directory
        let fileManager = FileManager.default
        let currentPath = fileManager.currentDirectoryPath

        let possiblePaths = [
            "\(currentPath)/Resources/\(filename)",
            "\(currentPath)/FEAViewer/Resources/\(filename)",
            "\(currentPath)/../Resources/\(filename)",
            "\(currentPath)/../../Resources/\(filename)"
        ]

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: path))
                    let decoder = JSONDecoder()
                    let model = try decoder.decode(SerializableModel.self, from: data)
                    return model
                } catch {
                    print("Error loading example from \(path): \(error)")
                    continue
                }
            }
        }

        print("Warning: Could not find example file \(filename) in any of the expected locations")
        return nil
    }

    static var allExamples: [(name: String, model: SerializableModel)] {
        return examples.compactMap { example in
            guard let model = loadExample(filename: example.filename) else {
                return nil
            }
            return (name: example.name, model: model)
        }
    }
}
