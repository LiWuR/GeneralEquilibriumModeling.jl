"""
    GeneralEquilibriumModeling

A Julia package for general equilibrium modeling.

The package provides two coordinated submodules:

- `GEM`: the core equilibrium-modeling and solver framework.
- `GEMB`: economic specifications and model-building tools built on `GEM`.

For a systematic introduction to the general equilibrium modeling methods
related to this package, see
[*GeneralEquilibriumModeling.jl and Structural Equilibrium Models: A Cookbook*](https://liwur.github.io/GEMBook/).
"""
module GeneralEquilibriumModeling

include("GEM/GEM.jl")
include("GEMB/GEMB.jl")

export GEM, GEMB

end
