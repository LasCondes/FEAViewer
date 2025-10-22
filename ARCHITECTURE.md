# PulleyViewer Architecture

## Overview

PulleyViewer uses a clean separation between the FEA model logic and the visualization UI, following MVVM (Model-View-ViewModel) architecture.

## Layer Separation

```
┌─────────────────────────────────────────┐
│              View Layer                 │
│  (SwiftUI Views - PulleyViewer.swift)  │
│  - ContentView                          │
│  - GeometryView                         │
│  - ResultsView                          │
└─────────────────┬───────────────────────┘
                  │
                  │ Binds to @Published properties
                  ↓
┌─────────────────────────────────────────┐
│          ViewModel Layer                │
│        (FEAViewModel)                   │
│  - Manages UI state                     │
│  - Coordinates FEA execution            │
│  - Exposes results for binding          │
└─────────────────┬───────────────────────┘
                  │
                  │ Delegates to
                  ↓
┌─────────────────────────────────────────┐
│           Model Layer                   │
│         (FEAModel.swift)                │
│  - CantileverBeamParameters             │
│  - FEAResults                           │
│  - CantileverBeamModel                  │
└─────────────────┬───────────────────────┘
                  │
                  │ Uses
                  ↓
┌─────────────────────────────────────────┐
│         PulleySwift Library             │
│  - FEAssembly                           │
│  - ShaftElement                         │
│  - LAPACK Solver                        │
└─────────────────────────────────────────┘
```

## Components

### 1. Model Layer (`FEAModel.swift`)

#### `CantileverBeamParameters`
Pure data struct containing model parameters:
```swift
struct CantileverBeamParameters {
    var length: Double          // mm
    var diameter: Double        // mm
    var load: Double           // N
    var youngsModulus: Double  // MPa
    var poissonsRatio: Double
}
```

**Responsibilities:**
- Store geometry and material properties
- Provide default values
- Value type (struct) for immutability

#### `FEAResults`
Pure data struct containing analysis results:
```swift
struct FEAResults {
    let endDeflection: Double
    let endRotation: Double
    let analyticalDeflection: Double
    let error: Double
    let solveTime: TimeInterval
    let totalDOFs: Int
}
```

**Responsibilities:**
- Store computed results
- Include validation metrics
- Performance metrics

#### `CantileverBeamModel`
Core business logic for FEA:
```swift
class CantileverBeamModel {
    private(set) var parameters: CantileverBeamParameters
    private(set) var results: FEAResults?

    func solve() throws -> FEAResults
    func updateParameters(_ parameters: CantileverBeamParameters)
}
```

**Responsibilities:**
- Build FEA model from parameters
- Execute analysis (calls PulleySwift)
- Compute analytical solutions
- Calculate validation metrics
- Error handling

**Key Methods:**
- `solve()`: Main analysis entry point
  1. Create `FEAssembly`
  2. Build `ShaftElement` from parameters
  3. Apply boundary conditions
  4. Apply loads
  5. Solve system
  6. Extract displacements
  7. Compute analytical comparison
  8. Return `FEAResults`

### 2. ViewModel Layer (`FEAViewModel`)

Bridge between UI and model:
```swift
class FEAViewModel: ObservableObject {
    @Published var isRunning: Bool
    @Published var errorMessage: String?
    @Published var results: FEAResults?

    private var feaModel: CantileverBeamModel

    func runAnalysis()
    func updateLength(_ length: Double)
    func updateDiameter(_ diameter: Double)
    func updateLoad(_ load: Double)
}
```

**Responsibilities:**
- UI state management (isRunning, errors)
- Async coordination (background FEA execution)
- Thread marshaling (results to main thread)
- Expose model data as computed properties

**Design Patterns:**
- **Observable Object**: SwiftUI binding
- **Async Coordination**: DispatchQueue for background work
- **Delegation**: Forwards to `CantileverBeamModel`

### 3. View Layer

#### `ContentView`
Main container with split view:
- Left panel: Model visualization
- Right panel: Results display

#### `GeometryView`
Canvas-based 2D rendering:
- Draws undeformed geometry
- Draws deformed shape (if results available)
- Draws boundary conditions (fixed support)
- Draws loads (arrows)
- Draws annotations (dimensions, labels)

**Data Flow:**
```swift
@ObservedObject var viewModel: FEAViewModel
// Access: viewModel.length, viewModel.endDeflection, etc.
```

#### `ResultsView`
Results panel:
- Displacement values
- Validation comparison
- Theory explanation

## Data Flow

### Analysis Execution Flow

```
1. User clicks "Run Analysis" button
   ↓
2. ContentView calls viewModel.runAnalysis()
   ↓
3. FEAViewModel sets isRunning = true
   ↓
4. Background queue dispatched
   ↓
5. FEAViewModel calls feaModel.solve()
   ↓
6. CantileverBeamModel:
   - Creates FEAssembly
   - Builds element
   - Applies BCs and loads
   - Solves system
   - Extracts results
   ↓
7. Returns FEAResults (or throws error)
   ↓
8. Main queue dispatch
   ↓
9. FEAViewModel updates @Published results
   ↓
10. SwiftUI automatically updates views
```

### Parameter Update Flow

```
1. User modifies parameter (future: slider)
   ↓
2. View calls viewModel.updateLength(newValue)
   ↓
3. FEAViewModel forwards to feaModel.updateLength()
   ↓
4. CantileverBeamModel updates parameters
5. Invalidates results (sets to nil)
   ↓
6. UI reflects new parameters
7. Results cleared (user must re-run)
```

## Benefits of Separation

### 1. **Testability**
- Model can be unit tested without UI
- Mock parameters easily
- Verify FEA results independently

```swift
func testCantileverDeflection() {
    let params = CantileverBeamParameters(
        length: 1000, diameter: 50, load: -1000,
        youngsModulus: 210000, poissonsRatio: 0.3
    )
    let model = CantileverBeamModel(parameters: params)
    let results = try model.solve()

    XCTAssertEqual(results.error, 0.0014, accuracy: 0.001)
}
```

### 2. **Reusability**
- `CantileverBeamModel` can be used in:
  - Command-line tools
  - Web services
  - Other GUI frameworks
  - Batch processing

### 3. **Maintainability**
- Clear responsibilities
- Changes to FEA logic don't affect UI
- Changes to UI don't affect FEA
- Easy to add new model types

### 4. **Extensibility**

Add new models without touching UI:
```swift
class SimplySupportedBeamModel {
    func solve() throws -> FEAResults
}

class MultiSpanBeamModel {
    func solve() throws -> FEAResults
}

// ViewModel just needs to switch models
```

### 5. **Performance**
- Background execution isolated to model
- UI remains responsive
- Easy to add progress callbacks

## Error Handling

Model layer uses `throws`:
```swift
enum FEAError: LocalizedError {
    case solutionFailed
    case resultExtractionFailed
}
```

ViewModel catches and exposes:
```swift
@Published var errorMessage: String?
```

View displays if present:
```swift
if let error = viewModel.errorMessage {
    Text(error).foregroundColor(.red)
}
```

## Future Extensions

### 1. Multiple Model Types
```swift
protocol FEAModelProtocol {
    associatedtype Parameters
    associatedtype Results

    func solve() throws -> Results
}

class FEAViewModel<Model: FEAModelProtocol> {
    private var model: Model
}
```

### 2. Parameter Validation
```swift
extension CantileverBeamParameters {
    func validate() throws {
        guard length > 0 else {
            throw ValidationError.invalidLength
        }
        // ... more checks
    }
}
```

### 3. Results History
```swift
class CantileverBeamModel {
    private(set) var resultsHistory: [FEAResults] = []

    func solve() throws -> FEAResults {
        let results = // ... compute
        resultsHistory.append(results)
        return results
    }
}
```

### 4. Export/Import
```swift
extension CantileverBeamParameters: Codable {}
extension FEAResults: Codable {}

// Save/load to JSON
let json = try JSONEncoder().encode(parameters)
```

## File Organization

```
PulleyViewer/
├── Sources/
│   └── PulleyViewer/
│       ├── PulleyViewer.swift      # Views + ViewModel
│       └── FEAModel.swift          # Model layer
├── Package.swift
├── README.md
└── ARCHITECTURE.md                 # This file
```

## Dependencies

- **PulleySwift**: FEA engine (PulleyCore, PulleyFEA)
- **SwiftUI**: UI framework
- **Foundation**: Core utilities
- **Accelerate**: Math operations (via PulleySwift)

## Thread Safety

- **Model**: Not thread-safe (single execution at a time)
- **ViewModel**: Thread-safe via DispatchQueue
- **Views**: Main thread only (SwiftUI requirement)

**Pattern:**
```swift
DispatchQueue.global(qos: .userInitiated).async {
    // Background: Heavy FEA computation
    let results = try model.solve()

    DispatchQueue.main.async {
        // Main thread: Update UI
        self.results = results
    }
}
```

## Summary

The separated architecture provides:
- ✅ Clean separation of concerns
- ✅ Testable business logic
- ✅ Reusable FEA models
- ✅ Maintainable codebase
- ✅ Extensible design
- ✅ Type-safe parameters and results
- ✅ Proper error handling
- ✅ Performance isolation

The model layer (`FEAModel.swift`) is completely independent of SwiftUI and can be extracted to a separate module or used in other contexts.
