# FEAViewer

**Interactive macOS Application for Axisymmetric Finite Element Analysis**

FEAViewer is a modern SwiftUI application for building, visualizing, and analyzing axisymmetric FEA models using the [AxiSymFEA](https://github.com/LasCondes/AxiSymFEA) library.

## Features

- **Interactive Model Building**: Add, edit, and delete FEA elements visually
- **Multi-Element Support**:
  - Shaft elements (beam + bar, bending/axial/torsion)
  - Disk elements (radial disk bending)
  - Shell elements (cylindrical shells)
- **Real-time Visualization**: 2D representation of FEA model geometry
- **Material Configuration**: Edit Young's modulus, Poisson's ratio, density
- **Analysis Execution**: Run FEA solver and view results
- **Clean Architecture**: MVVM pattern with separated model/UI layers

## Requirements

- macOS 13.0+
- Swift 6.2+
- Xcode 15+ (for development)

## Installation

### From Source

```bash
git clone https://github.com/LasCondes/FEAViewer.git
cd FEAViewer
swift build
swift run FEAViewer
```

### Xcode

```bash
open Package.swift
```

Then build and run from Xcode.

## Usage

### Building a Model

1. **Add Elements**: Click the "Add" button for Shaft, Disk, or Shell elements
2. **Configure Properties**: Edit dimensions, positions, and element-specific settings
3. **Set Material**: Adjust Young's modulus and Poisson's ratio (default: Steel)
4. **Run Analysis**: Click "Run Analysis" to solve the FEA system
5. **View Results**: Check the results panel for DOF count, solve time, and success status

### Element Types

#### Shaft Elements
- Diameter, Start Z, End Z positions
- Euler-Bernoulli or Timoshenko beam models
- DOFs: w, gamma, u, beta (bending, rotation, axial, torsion)

#### Disk Elements
- Inner/Outer radius, thickness variation
- Radial disk bending (TMB equations)
- DOFs: u, v, w, phi (radial, tangential, transverse, rotation)

#### Shell Elements
- Radius, thickness, axial extent
- Ventsel-Krauthammer or TWK shell models
- DOFs: u, v, w, phi

## License

MIT License

## Related Projects

- **[AxiSymFEA](https://github.com/LasCondes/AxiSymFEA)** - FEA library
- **[PulleySwift](https://github.com/LasCondes/PulleySwift)** - Pulley analysis tools
