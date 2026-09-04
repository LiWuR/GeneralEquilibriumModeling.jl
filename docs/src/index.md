# GeneralEquilibriumModeling.jl

`GeneralEquilibriumModeling.jl` is a Julia package for general equilibrium modeling. It contains two coordinated submodules:

* `GEM`: the low-level equilibrium-modeling and solver layer.
* `GEMB`: the higher-level model-building layer built on top of `GEM`.

## Getting started

The package is loaded with:

```julia
using GeneralEquilibriumModeling
```

The two submodules can then be accessed as:

```julia
GEM.NetSupplyAgent
GEM.NetSupplyEquilibriumModel
GEM.PriceVariableRef

GEMB.CESSpec
GEMB.ActivityDemandSpec
GEMB.AgentTemplate
```

Users who prefer to import a submodule directly may write:

```julia
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB
```

## Package structure

```text
GeneralEquilibriumModeling
├── GEM   # core equilibrium modeling and solvers
└── GEMB  # high-level builders and economic specifications
```

The documentation is organized into the `GEM` core documentation and the `GEMB` builder documentation. Example programs are also kept in separate `gem` and `gemb` groups so that the two modeling layers remain easy to distinguish.

## Related book

For a systematic introduction to the general equilibrium modeling methods related to this package, see [*GeneralEquilibriumModeling.jl and Structural Equilibrium Models: A Cookbook*](https://liwur.github.io/GEMBook/).

