# Custom net-supply agents

`GEMB` provides two complementary high-level agent-construction paths.

For standard economic behavior, prefer [`add_agent!`](@ref) together with a
behavioral specification such as `CESSpec`, `ProductionFunctionSpec`,
`MarginalUtilityConsumerSpec`, or `MarshallDemandConsumerSpec`. These
specifications retain economic semantics and allow GEMB to construct and
validate the corresponding low-level agent automatically.

When the existing specifications do not naturally represent an economic
agent, use [`add_net_supply_agent!`](@ref). This advanced interface lets the
user supply the complete net-supply mapping, equilibrium variables, and
condition rule while still using GEMB commodity names and GEMBModel
registration.

## Basic pattern

```julia
using GeneralEquilibriumModeling

model = GEMB.GEMBModel(
    [:product, :labor];
    numeraire=:product,
    numeraire_value=1.0,
)

consumer_net_supply = function (
    local_variables,
    local_prices,
    observed_values=Any[],
)
    x_product = local_variables[1]
    x_labor = local_variables[2]

    return [
        -x_product,
        100.0 - x_labor,
    ]
end

consumer_conditions = function (
    local_variables,
    local_prices,
    net_supply,
)
    x_product = local_variables[1]
    x_labor = local_variables[2]
    mu = local_variables[3]

    p_product = local_prices[1]
    p_labor = local_prices[2]

    return [
        mu * p_product - 0.5 / x_product,
        mu * p_labor - 0.5 / x_labor,
        100.0 * p_labor -
            p_product * x_product -
            p_labor * x_labor,
    ]
end

GEMB.add_net_supply_agent!(
    model,
    consumer_net_supply;
    commodities=[:product, :labor],
    variable_names=[
        :demand_product,
        :demand_labor,
        :budget_multiplier,
    ],
    variable_lower_bounds=[
        1.0e-10,
        1.0e-10,
        0.0,
    ],
    variable_upper_bounds=[
        Inf,
        Inf,
        Inf,
    ],
    variable_start=[
        50.0,
        50.0,
        0.01,
    ],
    condition_rule=
        GEM.ExplicitAgentConditions(
            consumer_conditions,
        ),
    name=:consumer,
)
```

The `commodities` argument uses the same high-level selectors as the rest of
`GEMBModel`. GEMB resolves `[:product, :labor]` to the integer commodity
indices required by `GEM.NetSupplyAgent`, constructs the low-level agent, and
registers it in the model. The user does not need to manipulate
`model.agents`, `model.agent_refs`, or either model index dictionary directly.

## When to use this interface

Use `add_net_supply_agent!` when the agent requires a complete custom
net-supply mapping or a condition structure that is not naturally represented
by an existing GEMB specification. Examples include custom consumers,
nonstandard producers, governments, financial institutions, externality
agents, and specialized virtual agents.

Do not use this interface merely to reimplement behavior already represented
by a standard specification. Standard specifications remain the preferred
interface because they preserve more economic structure and support stronger
model-specific validation.

## Relationship to the builder API

`build_agent` remains part of GEMB, but it is primarily an advanced
construction and extension interface. It maps behavioral specifications to
low-level GEM agents and is useful for package development, unit testing,
extensions, and direct GEM/GEMB integration.

For ordinary model construction, the recommended order is:

1. `add_agent!` with a standard behavioral specification.
2. `add_net_supply_agent!` when a complete custom agent is required.
3. `build_agent` or direct GEM objects for advanced development and extension
   work.

The two high-level paths ultimately produce the same low-level
`GEM.AbstractNetSupplyAgent` representation and can therefore be mixed in one
`GEMBModel`.
