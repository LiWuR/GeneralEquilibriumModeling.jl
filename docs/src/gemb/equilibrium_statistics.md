```@meta
CurrentModule = GEMB
```

# Equilibrium statistics

GEMB provides a post-solve statistics layer for organizing the economic
information stored in an equilibrium result. The statistics functions do not
solve the model again and do not re-evaluate agent behavior.

A typical workflow is:

```julia
result = solve(model)

stats = equilibrium_statistics(model, result)

print_equilibrium_statistics(model, result)
```

The unified [`equilibrium_statistics`](@ref) interface returns a named tuple
with the following fields:

```julia
stats.prices

stats.activity_levels
stats.activity_level_refs

stats.net_supply_matrix
stats.net_supply_value_matrix
stats.agent_net_supply_values

stats.total_net_supply
stats.commodity_names
stats.agent_refs
```

## Activity levels

`stats.activity_levels` collects the explicitly represented activity levels in
the solved model. The economic interpretation of an activity level depends on
the representation of the agent. For example, it may represent a production
activity level or a consumer's utility level.

The ordering is first by agent order and then by the existing variable order
within each agent. `stats.activity_level_refs` has the same length and
identifies the agent that owns each activity level.

A multi-activity agent therefore contributes more than one entry to
`activity_levels`, and the same agent reference appears repeatedly in
`activity_level_refs`. An agent without an explicitly represented activity
level contributes no entry.

The statistics layer recognizes `:activity`, `:activity_*`, and `:utility` as
standard activity-level variables. Other endogenous agent variables, such as
input quantities, multipliers, claim quantities, and auxiliary variables, are
not included in `activity_levels`.

## Net-supply matrix

[`net_supply_matrix`](@ref) constructs the commodity-by-agent net-supply matrix

```math
\mathbf{\bar S}
=
\mathbf S-\mathbf D
```

where `\mathbf S` and `\mathbf D` denote the supply matrix and demand matrix,
respectively.

Rows of `\mathbf{\bar S}` follow `model.commodity_names`, while columns follow
`model.agents` and `stats.agent_refs`. Therefore, the element `\bar S_{ij}`
represents the net supply of commodity `i` by agent `j`.

A positive entry represents net supply, a negative entry represents net demand,
and a zero entry means that the agent has no net supply of that commodity.

Summing across agents gives the total net supply of each commodity:

```math
\mathbf{\bar S}\mathbf 1
=
\mathbf{\bar s}
```

where `\mathbf{\bar s}` is the total net-supply vector stored as
`stats.total_net_supply`. When the equilibrium result already contains
`total_net_supply`, GEMB checks that the row sums of `\mathbf{\bar S}`
reproduce this vector within numerical tolerance.


## Net-supply value matrix

[`net_supply_value_matrix`](@ref) converts the net-supply matrix into value
terms at equilibrium prices. Define the net-supply value matrix as

```math
\mathbf{\bar S}_v
=
\operatorname{Diag}(\mathbf p)\mathbf{\bar S}
```

where `\mathbf p` is the equilibrium price vector.

The rows and columns of `\mathbf{\bar S}_v` have the same interpretation as
those of `\mathbf{\bar S}`: rows represent commodities and columns represent
agents. The element `(\bar S_v)_{ij}` is therefore the equilibrium value of
agent `j`'s net supply of commodity `i`.

A positive entry represents the value of net supply, while a negative entry
represents the value of net demand.

[`agent_net_supply_values`](@ref) sums `\mathbf{\bar S}_v` across commodities.
Hence the net-supply value of each agent is obtained from the column sums of
the net-supply value matrix:

```math
\mathbf 1^\mathsf{T}\mathbf{\bar S}_v
```

Equivalently, the corresponding column vector is

```math
\mathbf{\bar S}^{\mathsf T}\mathbf p
```


## Printing equilibrium statistics

[`print_equilibrium_statistics`](@ref) provides a compact human-readable
summary:

```julia
print_equilibrium_statistics(model, result)
```

The display contains:

- equilibrium prices;
- activity levels;
- the net-supply matrix;
- the net-supply value matrix;
- net-supply value by agent; and
- total net supply by commodity.

Two display options are available:

```julia
print_equilibrium_statistics(
    model,
    result;
    display_tol=1.0e-10,
    sigdigits=8,
)
```

Values whose absolute magnitude does not exceed `display_tol` are displayed as
zero. This affects only printing; the equilibrium result and the statistics
returned by [`equilibrium_statistics`](@ref) are unchanged.

An explicit output stream may also be supplied:

```julia
print_equilibrium_statistics(io, model, result)
```

## Design principle

Equilibrium statistics are intentionally separate from model solution:

```julia
result = solve(model)
stats = equilibrium_statistics(model, result)
```

This keeps the solver responsible for equilibrium computation and the
statistics layer responsible for post-solve organization and presentation.
