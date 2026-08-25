# GEMB.jl

[![CI](https://github.com/LiWuR/GEMB.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/LiWuR/GEMB.jl/actions/workflows/CI.yml)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://LiWuR.github.io/GEMB.jl/dev/)

**GEMB** stands for **General Equilibrium Model Builder**. It is a high-level Julia package for building economic general-equilibrium models from reusable behavioral and structural specifications.

GEMB is built on top of [GEM.jl](https://github.com/LiWuR/GEM.jl). GEM provides the low-level equilibrium representation, condition system, JuMP construction, and complementarity-based solver interface; GEMB provides higher-level model-building tools for consumers, producers, commodities, claims, and static or intertemporal equilibrium structures.

The package is intended especially for economic-theory learning, model experimentation, and transparent construction of general-equilibrium examples.

## Installation

After GEM and GEMB are registered in the Julia General registry, install GEMB with:

```julia
import Pkg
Pkg.add("GEMB")
```

During prerelease development, install the development repositories with:

```julia
import Pkg
Pkg.develop(url = "https://github.com/LiWuR/GEM.jl")
Pkg.develop(url = "https://github.com/LiWuR/GEMB.jl")
```

## Quick start

Load the package with:

```julia
using GEMB
```

GEMB provides high-level builders and specifications that are translated into GEM equilibrium objects and then solved through the GEM core.

## Package architecture

- **GEM.jl** — low-level general-equilibrium modeling and solution engine.
- **GEMB.jl** — high-level economic model builder built on GEM.

This separation keeps equilibrium representation and numerical solution in GEM while allowing GEMB to focus on concise economic model specification.

## Documentation

Development documentation is hosted at:

https://LiWuR.github.io/GEMB.jl/dev/

Tagged releases are deployed by Documenter.jl and provide versioned and `stable` documentation.

## License

GEMB.jl is released under the MIT License. See [`LICENSE`](LICENSE).

## Development note

Parts of the implementation and documentation have been developed with assistance from generative-AI tools. The maintainer reviews, tests, and takes responsibility for the code and documentation included in the package.
