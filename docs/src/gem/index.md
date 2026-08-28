```@meta
CurrentModule = GEM
```

# GEM

GEM is the low-level core submodule of `GeneralEquilibriumModeling.jl`. It
formulates and solves general equilibrium models as mixed complementarity
problems. Consumers, producers, and other economic agents are represented
through a unified net-supply framework, while agent optimality conditions,
market-clearing conditions, and auxiliary equilibrium equations are assembled
into a single equilibrium system.

GEM exposes the low-level net-supply, complementarity-condition,
model-construction, and solver interfaces used by `GeneralEquilibriumModeling.jl`.
For most routine economic modeling tasks, users are encouraged to work through
the higher-level `GEMB` submodule, which provides more convenient model-building
interfaces while using GEM as the underlying equilibrium engine. Direct use of
GEM is mainly useful when users need fine-grained control over agent net
supplies, complementarity conditions, variable bounds, or custom equilibrium
structures.

GEM supports marginal-utility consumers, automatic zero-profit conditions,
stationary-production conditions, cost-minimization KKT conditions, multiple
production activities, joint production, cross-agent observable variables,
and endogenous auxiliary variables. Commodity prices may have nonnegative,
nonpositive, free, or user-defined bounds, allowing the framework to represent
ordinary goods, pollution, taxes, subsidies, claims, and other policy
instruments. The resulting complementarity problem is constructed with JuMP
and solved using PATH.

## Main features

- Unified net-supply representation for all economic agents
- Consumers specified through marginal-utility functions
- Producers with automatic zero-profit, stationary-production, or
  cost-minimization KKT conditions
- Multiple activity levels and joint-production technologies
- Cross-agent observable equilibrium variables
- Endogenous auxiliary variables and auxiliary equations
- Flexible commodity-price bounds, including free and negative prices
- JuMP-based MCP construction and PATH solution
- Structured equilibrium results and residual diagnostics

## Basic workflow

A GEM model is constructed and solved in four steps:

1. Define consumers, producers, and other net-supply agents.
2. Assemble the agents, commodities, numeraire, and optional auxiliary
   equations into an equilibrium model.
3. Solve the resulting mixed complementarity problem.
4. Inspect equilibrium prices, agent variables, net supplies, market
   residuals, and solver diagnostics.

## Key API entry points
Detailed documentation for GEM's types and functions is provided in the API
reference pages. The following interfaces are useful starting points:

- [`NetSupplyEquilibriumModel`](@ref)
- [`NetSupplyAgent`](@ref)
- [`MarginalUtilityConsumerConditions`](@ref)
- [`ProductionStationarityConditions`](@ref)
- [`CostMinimizationKKTConditions`](@ref)
- [`ProductionNetSupply`](@ref)
- [`EquilibriumResult`](@ref)
