# FEAViewer Example Models

This directory contains example FEA models in JSON format that can be loaded from the Examples menu.

## Available Examples

1. **Simply Supported Shaft (500mm)** - Shaft bent by a transverse load at its center, in Fourier mode 1 (the bending mode)
2. **Torque Shaft (Torsion)** - Shaft with applied torque demonstrating torsional behavior
3. **Axial Load Shaft (Tension)** - Shaft with axial tensile load demonstrating axial deformation

## JSON Format

Each example file should follow this structure:

```json
{
  "nodes": [
    {
      "id": "unique-uuid",
      "x": 0.0,
      "r": 0.0,
      "label": "Node Label"
    }
  ],
  "shaftElements": [
    {
      "id": "unique-uuid",
      "startNodeID": "node-uuid",
      "endNodeID": "node-uuid",
      "diameter": 400.0,
      "modelString": "timoshenko",
      "mode": 0
    }
  ],
  "diskElements": [
    {
      "id": "unique-uuid",
      "innerNodeID": "node-uuid",
      "outerNodeID": "node-uuid",
      "thicknessBegin": 20.0,
      "thicknessEnd": 10.0,
      "mode": 0
    }
  ],
  "shellElements": [
    {
      "id": "unique-uuid",
      "startNodeID": "node-uuid",
      "endNodeID": "node-uuid",
      "radius": 300.0,
      "thickness": 10.0,
      "modelString": "ventselKrauthammer",
      "mode": 1
    }
  ],
  "material": {
    "youngsModulus": 210000.0,
    "poissonsRatio": 0.3,
    "density": 7850.0
  },
  "constraints": [
    {
      "id": "unique-uuid",
      "nodeID": "node-uuid",
      "dofType": "w",
      "constraintType": "fixed",
      "value": 0.0
    }
  ],
  "loads": [
    {
      "id": "unique-uuid",
      "nodeID": "node-uuid",
      "dofType": "beta",
      "magnitude": 10000.0
    }
  ]
}
```

## Field Descriptions

### Nodes
- `id`: Unique UUID for the node
- `x`: Axial position (mm)
- `r`: Radial position (mm)
- `label`: Optional descriptive label

### Elements

#### Shaft Elements
- `diameter`: Shaft diameter (mm)
- `modelString`: "timoshenko" or "eulerBernoulli"
- `mode`: Fourier mode (0 for axial/torsion, 1/-1 for bending)
- **Important**: Both nodes must be at r=0 (on the centerline). Shaft elements are 1D beam elements along the axis of symmetry.

#### Disk Elements
- `thicknessBegin`: Thickness at inner radius (mm)
- `thicknessEnd`: Thickness at outer radius (mm)
- `mode`: Fourier mode

#### Shell Elements
- `radius`: Shell radius (mm)
- `thickness`: Shell thickness (mm)
- `modelString`: "ventselKrauthammer" (currently only option)
- `mode`: Fourier mode

### Material
- `youngsModulus`: Young's modulus (MPa)
- `poissonsRatio`: Poisson's ratio (dimensionless)
- `density`: Material density (kg/m³)

### Constraints
- `dofType`: "u", "v", "w", "gamma", "phi", or "beta"
- `constraintType`: "fixed" or "prescribed"
- `value`: Prescribed value (if using prescribed constraint)

### Loads
- `dofType`: DOF to apply load to
- `magnitude`: Load magnitude (N for forces, N·mm for moments)

## DOF Types

- `u`: Axial displacement
- `v`: Tangential displacement
- `w`: Transverse/radial displacement
- `gamma`: Rotation about transverse axis
- `phi`: Rotation about tangential axis
- `beta`: Torsional rotation

## Adding New Examples

1. Create a new JSON file in this directory
2. Add an entry to `Examples.swift` in the `examples` array:
   ```swift
   Example(name: "Your Example Name", filename: "your-file.json")
   ```
3. Rebuild the project

The example will then appear in the Examples menu in FEAViewer.
