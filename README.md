# GeneralEquilibriumModeling.jl

[![CI](https://github.com/LiWuR/GeneralEquilibriumModeling.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/LiWuR/GeneralEquilibriumModeling.jl/actions/workflows/CI.yml)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://LiWuR.github.io/GeneralEquilibriumModeling.jl/dev/)

**GeneralEquilibriumModeling.jl** is a Julia package for general-equilibrium modeling. It combines a low-level equilibrium engine with a higher-level model-building layer in one package:

- **`GEM`**: core equilibrium representation, complementarity conditions, JuMP construction, and solver interfaces.
- **`GEMB`**: higher-level economic specifications, agent builders, model templates, and intertemporal modeling tools built on top of `GEM`.

This organization allows users to work at two levels. Routine economic models can be expressed through the higher-level `GEMB` interfaces, while lower-level `GEM` objects remain available when fine-grained control over net supplies, equilibrium conditions, variable bounds, or solver structure is needed.

## Installation

Before registration in the Julia General registry, install the package directly from GitHub:

```julia
import Pkg
Pkg.add(url = "https://github.com/LiWuR/GeneralEquilibriumModeling.jl")
```

After registration in General, installation will be:

```julia
import Pkg
Pkg.add("GeneralEquilibriumModeling")
```

## Quick start

Load the package with:

```julia
using GeneralEquilibriumModeling
```

The two modeling layers are then available as submodules:

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

## Package structure

```text
GeneralEquilibriumModeling
├── GEM   # core equilibrium modeling and solvers
└── GEMB  # high-level builders and economic specifications
```

The source tree, tests, examples, and documentation follow the same separation:

```text
src/GEM/
src/GEMB/

test/gem/
test/gemb/
test/integration/

examples/gem/
examples/gemb/

docs/src/gem/
docs/src/gemb/
```

## GEM: core equilibrium engine

`GEM` formulates and solves general-equilibrium models as mixed complementarity problems. Economic agents are represented through a unified net-supply framework, and agent optimality conditions, market-clearing conditions, and auxiliary equilibrium equations are assembled into one equilibrium system.

Main capabilities include:

- unified net-supply representations for economic agents;
- marginal-utility consumer conditions;
- unit-profit, total-profit, stationary-production, and cost-minimization KKT conditions;
- multiple activity levels and joint production;
- cross-agent observable equilibrium variables;
- endogenous auxiliary variables and equations;
- flexible price bounds, including free and negative prices;
- JuMP-based MCP construction;
- structured equilibrium results and residual diagnostics.

Direct use of `GEM` is useful when a model requires explicit control over agent net supplies, complementarity conditions, variable bounds, or custom equilibrium structures.

## GEMB: high-level model-building layer

`GEMB` provides higher-level behavioral specifications and builders that are translated into ordinary `GEM` equilibrium objects.

Its modeling interfaces include:

- `CESSpec` and `DCESSpec`;
- generic `ActivityDemandSpec`;
- marginal-utility and Marshallian-demand consumers;
- production-function-based agents;
- producer condition rules such as `UnitProfitConditions` and `TotalProfitConditions`;
- condition-only agents for endogenous policy and closure variables;
- ad valorem claims;
- multiple-output and joint-production models;
- dated commodities, repeated agent templates, dated claims, and intertemporal equilibrium models;
- additive mean-standard-deviation asset-exchange equilibrium tools.

`GEMB` is intended for routine economic modeling in which users prefer to specify economic behavior directly rather than manually construct all net-supply and complementarity functions.

## Examples

The repository contains separate example collections for the two modeling levels:

- `examples/gem/` contains low-level equilibrium-modeling examples;
- `examples/gemb/` contains higher-level specification and builder examples.

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

The manual is organized into separate `GEM` and `GEMB` sections, with API references, modeling guides, and worked examples for each layer.

## License

GeneralEquilibriumModeling.jl is released under the MIT License. See [`LICENSE`](LICENSE).

The PATHSolver.jl wrapper is also MIT-licensed. The underlying PATH solver is separate software with its own license terms.

## Development note

Parts of the implementation and documentation have been developed with assistance from generative-AI tools. The maintainer reviews, tests, and takes responsibility for the code and documentation included in the package.
