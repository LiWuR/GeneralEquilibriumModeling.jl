# GEM.jl

[![CI](https://github.com/LiWuR/GeneralEquilibriumModeling.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/LiWuR/GeneralEquilibriumModeling.jl/actions/workflows/CI.yml)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://LiWuR.github.io/GEM.jl/dev/)

**GEM** stands for **General Equilibrium Modeling**. It is a Julia package for representing and solving general-equilibrium models, with an emphasis on structural equilibrium systems expressed through net-supply, equilibrium, and complementarity conditions.

GEM is the low-level equilibrium engine in the GEM/GEMB package family. **GEMB** provides higher-level economic model builders, while GEM provides the underlying equilibrium representation, variables, condition rules, JuMP construction, and solver interface.

## Installation

Before registration in the Julia General registry, install the development version from GitHub:

```julia
import Pkg
Pkg.add(url = "https://github.com/LiWuR/GeneralEquilibriumModeling.jl")
```

After GEM is registered in General, installation will be:

```julia
import Pkg
Pkg.add("GeneralEquilibriumModeling")
```

## Quick start

Load GEM with:

```julia
using GeneralEquilibriumModeling.GEM
```

The package documentation describes the equilibrium model types, variable references, condition rules, auxiliary equations, and solver interface.

## PATH solver and licensing

GEM uses [PATHSolver.jl](https://github.com/chkwon/PATHSolver.jl) to solve mixed complementarity problems. PATHSolver.jl is an open-source Julia wrapper, while the underlying PATH solver is closed source and has separate licensing terms.

Without a PATH license, PATH can solve problems with at most **300 variables** and **2000 Jacobian nonzeros**. Larger models require a valid PATH license.

GEM does **not** include or distribute a PATH license. A license can be configured by setting the environment variable before loading GEM/PATHSolver:

```julia
ENV["PATH_LICENSE_STRING"] = "<license string>"
using GeneralEquilibriumModeling.GEM
```

or directly through PATHSolver after importing it:

```julia
import PATHSolver
PATHSolver.c_api_License_SetString("<license string>")
```

If PATH reports that a suitable license is unavailable, GEM raises `PATHSolverLicenseError` with a user-facing explanation of the likely license/size issue.

## Documentation

Development documentation is hosted at:

https://LiWuR.github.io/GEM.jl/dev/

Tagged releases are deployed by Documenter.jl and provide versioned and `stable` documentation.

## Related package

**GEMB.jl (General Equilibrium Model Builder)** is the higher-level modeling layer built on top of GEM. GEM is intended to remain the general equilibrium core; GEMB provides convenient economic specifications and model-building interfaces.

## License

GEM.jl is released under the MIT License. See [`LICENSE`](LICENSE).

The PATHSolver.jl wrapper is also MIT-licensed. The underlying PATH solver is separate software with its own license terms; see the PATHSolver.jl documentation for details.

## Development note

Parts of the implementation and documentation have been developed with assistance from generative-AI tools. The maintainer reviews, tests, and takes responsibility for the code and documentation included in the package.
