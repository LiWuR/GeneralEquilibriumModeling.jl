# GEM

`GEM` is the low-level equilibrium-modeling and solver layer of `GeneralEquilibriumModeling.jl`.

## Loading

```julia
using GeneralEquilibriumModeling.GEM
```

## Role in the package

`GEM` provides the core equilibrium objects, variable references, condition rules, JuMP/MCP construction, and solver interfaces.

## Detailed API pages

- [`GEM.AuxiliaryEquationJumpV1`](GEM_AuxiliaryEquationJumpV1.md)
- [`GEM.AuxiliaryEquationsV4`](GEM_AuxiliaryEquationsV4.md)
- [`GEM.AuxiliaryVariablesV1`](GEM_AuxiliaryVariablesV1.md)
- [`GEM.EquilibriumAgentCoreV1`](GEM_EquilibriumAgentCoreV1.md)
- [`GEM.EquilibriumJumpModelV2`](GEM_EquilibriumJumpModelV2.md)
- [`GEM.EquilibriumMarginalUtilityModelV5`](GEM_EquilibriumMarginalUtilityModelV5.md)
- [`GEM.EquilibriumModelSolverV10V19`](GEM_EquilibriumModelSolverV10V19.md)
- [`GEM.EquilibriumNetSupplyModelV11`](GEM_EquilibriumNetSupplyModelV11.md)
- [`GEM.EquilibriumResultV1`](GEM_EquilibriumResultV1.md)
- [`GEM.EquilibriumVariableRefsV3`](GEM_EquilibriumVariableRefsV3.md)
- [`GEM.ProducerConditionsV1`](GEM_ProducerConditionsV1.md)
- [`GEM.ProductionNetSupplyV1`](GEM_ProductionNetSupplyV1.md)

## Public API

The block below is retained as the canonical Documenter API page for the exported bindings of this submodule.

```@autodocs
Modules = [GeneralEquilibriumModeling.GEM]
Order = [:module, :type, :function, :macro, :constant]
```

