# GeneralEquilibriumModeling.jl

[![CI](https://github.com/LiWuR/GeneralEquilibriumModeling.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/LiWuR/GeneralEquilibriumModeling.jl/actions/workflows/CI.yml)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://LiWuR.github.io/GeneralEquilibriumModeling.jl/dev/)
[![codecov](https://codecov.io/gh/LiWuR/GeneralEquilibriumModeling.jl/graph/badge.svg)](https://codecov.io/gh/LiWuR/GeneralEquilibriumModeling.jl)

**GeneralEquilibriumModeling.jl** is a Julia package for general equilibrium modeling. It combines the `GEM` core equilibrium engine with the `GEMB` economic model-building tools in one package:

* **`GEM`**: core equilibrium representation, complementarity conditions, JuMP construction, and solver interfaces.
* **`GEMB`**: economic specifications, agent builders, model templates, and intertemporal modeling tools built on top of `GEM`.

Within `GEMB`, users can work through the GEMB high-level framework for routine economic modeling or the GEMB low-level framework for more direct control over economic-agent construction. The underlying GEM framework remains available when explicit control over net supplies, equilibrium conditions, variable bounds, or solver structure is needed.

## Installation

Install the package from the Julia General registry:

```julia
import Pkg
Pkg.add("GeneralEquilibriumModeling")
```

## Quick start

Load the package with:

```julia
using GeneralEquilibriumModeling
```

The two submodules are then available as:

```julia
GEM.NetSupplyAgent
GEM.NetSupplyEquilibriumModel
GEM.PriceVariableRef

GEMB.CESSpec
GEMB.ActivityDemandSpec
GEMB.AgentTemplate
```

Users who prefer direct submodule imports may write:

```julia
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB
```

## GEM: core equilibrium engine

`GEM` formulates and solves general equilibrium models as mixed complementarity problems. Economic agents are represented through a unified net-supply framework, and agent optimality conditions, market-clearing conditions, and auxiliary equilibrium equations are assembled into one equilibrium system.

Main capabilities include:

* unified net-supply representations for economic agents;
* marginal-utility consumer conditions;
* unit revenue-expenditure balance, total revenue-expenditure balance, production stationarity, and cost-minimization KKT conditions;
* multiple activity levels and joint production;
* cross-agent observable equilibrium variables;
* endogenous auxiliary variables and equations;
* flexible price bounds, including free and negative prices;
* JuMP-based MCP construction;
* structured equilibrium results and residual diagnostics.

Direct use of the GEM framework is useful when a model requires explicit control over agent net supplies, complementarity conditions, variable bounds, or custom equilibrium structures.

## GEMB: economic model-building tools

`GEMB` provides the GEMB high-level framework and the GEMB low-level framework for constructing economic models that are translated into `GEM` equilibrium objects.

Its modeling interfaces include:

* `CESSpec` and `DCESSpec`;
* generic `ActivityDemandSpec`;
* marginal-utility and Marshallian-demand consumers;
* production-function-based agents;
* producer condition rules such as `UnitRevenueExpenditureBalanceConditions` and `TotalRevenueExpenditureBalanceConditions`;
* condition-only agents for endogenous policy and closure variables;
* ad valorem claims;
* multiple-output and joint-production models;
* dated commodities, repeated agent templates, dated claims, and intertemporal equilibrium models;
* asset-exchange equilibrium tools based on an additive mean-standard-deviation utility function.

`GEMB` is intended for economic modeling in which users prefer to specify economic behavior directly rather than manually construct all net-supply and complementarity functions.

## Examples

The repository contains separate example collections for the two submodules:

* `examples/gem/` contains examples based on the GEM framework;
* `examples/gemb/` contains examples based on the GEMB modeling frameworks.

The current examples include pure exchange, production, claims and taxes, pollution and negative prices, joint production, asset equilibrium, condition agents, virtual-agent constructions, and intertemporal equilibrium models.

## PATH solver and licensing

GeneralEquilibriumModeling.jl uses [PATHSolver.jl](https://github.com/chkwon/PATHSolver.jl) for mixed complementarity problems. PATHSolver.jl is an open-source Julia wrapper; the underlying PATH solver is separate software with its own licensing terms.

GeneralEquilibriumModeling.jl does **not** include or distribute a PATH license. A PATH license can be configured before loading the package, for example:

```julia
ENV["PATH_LICENSE_STRING"] = "<license string>"
using GeneralEquilibriumModeling
```

or directly through PATHSolver:

```julia
import PATHSolver
PATHSolver.c_api_License_SetString("<license string>")
```

For PATH licensing details and solver limitations, see the PATHSolver.jl documentation.

## Documentation

Development documentation is hosted at:

https://LiWuR.github.io/GeneralEquilibriumModeling.jl/dev/

The manual is organized into separate `GEM` and `GEMB` sections, with API references, modeling guides, and worked examples for each submodule.

For a systematic introduction to the general equilibrium modeling methods related to this package, see [*GeneralEquilibriumModeling.jl and Structural Equilibrium Models: A Cookbook*](https://liwur.github.io/GEMBook/).

## License

GeneralEquilibriumModeling.jl is released under the MIT License. See [`LICENSE`](LICENSE).

The PATHSolver.jl wrapper is also MIT-licensed. The underlying PATH solver is separate software with its own license terms.

## Development note

Parts of the implementation and documentation have been developed with assistance from generative-AI tools. The maintainer reviews, tests, and takes responsibility for the code and documentation included in the package.
