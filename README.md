# PulleyViewer

A macOS application for visualizing finite element analysis (FEA) models and results from the PulleySwift library.

## Features

- **Interactive Model Visualization**: 2D visualization of shaft/beam models with:
  - Fixed support indicators
  - Applied loads (forces and moments)
  - Coordinate system display
  - Dimensional annotations

- **Deformed Shape Display**: Shows the deflected shape of the structure (amplified 10x for visibility)

- **Real-time FEA Analysis**: Runs FEA simulations using the PulleySwift engine

- **Results Display**: Shows:
  - Displacement values
  - Rotation values
  - Comparison with analytical solutions
  - Error percentage

- **Validation**: Compares FEA results with classical beam theory (Euler-Bernoulli)

## Example Model

The app demonstrates a cantilever beam:
- **Length**: 1000mm
- **Diameter**: 50mm
- **Material**: Steel (E = 210,000 MPa, ν = 0.3)
- **Loading**: 1000N transverse load at free end
- **Boundary Conditions**: Fixed support at left end

## Building and Running

```bash
swift build
swift run
```

Or open in Xcode:

```bash
open Package.swift
```

## Requirements

- macOS 13.0 or later
- Swift 6.2 or later
- PulleySwift library (included as local dependency)

## Architecture

### UI Components

- **ContentView**: Main split view with model visualization and results
- **GeometryView**: Canvas-based 2D rendering of the FEA model
- **ResultsView**: Scrollable results panel with grouped data
- **FEAViewModel**: ObservableObject managing model state and FEA execution

### FEA Integration

The app integrates with PulleySwift's FEA engine:

```swift
let assembly = FEAssembly()
let element = ShaftElement(...)
assembly.addElement(element)
assembly.assemble(mode: 0)

// Apply boundary conditions
assembly.fixDOF(...)

// Apply loads
assembly.applyForce(...)

// Solve
assembly.solve()

// Extract results
assembly.getDisplacement(atDOF: ...)
```

### Visualization Features

- **Undeformed geometry**: Gray solid outline
- **Deformed geometry**: Blue dashed curve (10x amplification)
- **Fixed support**: Black hatched wall symbol
- **Applied loads**: Red arrows with magnitude labels
- **Dimensions**: Gray dimension lines with values

## Screenshots

The app features:
- Left panel: Interactive model visualization with parameter overlay
- Right panel: Results with displacement values, validation, and theory

## Future Enhancements

Potential additions:
- Interactive parameter editing (sliders for length, diameter, load)
- Multiple load cases
- Export results to CSV/JSON
- 3D visualization using SceneKit or RealityKit
- Animation of deformation
- Stress contour plots
- Multiple element types (disk, shell)
- Support for complex assemblies with multiple elements

## License

Part of the PulleySwift project - FEA for conveyor belt pulley design.
