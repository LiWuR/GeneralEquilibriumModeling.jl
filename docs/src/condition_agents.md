```@meta
CurrentModule = GEMB
```

# Condition agents

`ConditionAgentSpec` represents endogenous equilibrium variables that are
determined directly by explicit conditions rather than by commodity demand or
supply behavior.

A condition agent has three user-facing components:

1. one or more endogenous agent variables;
2. one condition paired with each variable; and
3. optional observed equilibrium variables such as prices or variables owned by
   other agents.

It has no economic commodity demand or supply of its own.

## Basic use

The condition function has the public interface

```julia
condition_function(variables, observed_values)
```

and must return one condition value for each endogenous variable.

For example, the condition

```math
x - 2 = 0
```

can be represented as

```julia
model = GEMBModel(
    [:anchor];
    numeraire=:anchor,
)

add_agent!(
    model,
    ConditionAgentSpec(
        (variables, observed_values) -> [
            variables[1] - 2.0,
        ],
    );
    variable_names=:x,
    variable_start=1.0,
    name=:conditionAgent,
)
```

The variable name, starting value, bounds, observed variables, and agent name
are supplied through [`add_agent!`](@ref), while
[`ConditionAgentSpec`](@ref) describes only the explicit condition.

## Observing equilibrium variables

A condition agent may depend on prices or variables owned by other agents.
Use the same observation mechanism as other GEMB agents.

For example,

```julia
observed_variables=[
    PriceVariableRef(:labor),
    agent_variable_ref(
        :firm,
        :activity,
    ),
]
```

makes the corresponding values available in `observed_values` in the same
order.

Structured agent-variable references may be forward references. GEMB resolves
them when the complete model is built.

## Multiple variables

One condition agent may contain several endogenous variables. The condition
function must return a vector of the same length.

For example,

```math
x+y-3=0
```

```math
x-y-1=0
```

can be written as

```julia
ConditionAgentSpec(
    (variables, observed_values) -> begin
        x = variables[1]
        y = variables[2]

        return [
            x + y - 3.0,
            x - y - 1.0,
        ]
    end,
)
```

with

```julia
variable_names=[:x, :y]
```

## Bounds and complementarity

Condition-agent variables use the ordinary GEM variable-bound and
complementarity semantics.

A free variable,

```math
-\infty < x < +\infty,
```

forces its paired condition to hold as an equality. A variable with a finite
bound instead has the corresponding mixed-complementarity interpretation.

This makes `ConditionAgentSpec` useful both for equality closure equations and
for endogenous variables that may reach policy or feasibility bounds.

## Endogenous policy variables

A common use is to represent an endogenous policy parameter as the variable of
a virtual policy agent.

For example, let `tax_rate = tau` and suppose a government-budget condition is

```math
\tau B(\bm p,z)-p_L G_L=0,
```

where ``B(\bm p,z)`` is the tax base and ``p_LG_L`` is government expenditure.

The policy agent can be written schematically as

```julia
tax_rate_setter = add_agent!(
    model,
    ConditionAgentSpec(
        (variables, observed_values) -> begin
            tau = variables[1]

            # Recover prices, firm activity, or other observed values.
            tax_base = ...
            government_expenditure = ...

            return [
                tau * tax_base -
                government_expenditure,
            ]
        end,
    );
    variable_names=:tax_rate,
    variable_start=0.1,
    observed_variables=[
        PriceVariableRef(:labor),
        agent_variable_ref(
            :firm,
            :activity,
        ),
    ],
    name=:taxRateSetter,
)
```

Other agents can then observe the endogenous rate through

```julia
agent_variable_ref(
    :taxRateSetter,
    :tax_rate,
)
```

and use it directly in their own behavioral specifications.

The same pattern can be used for endogenous tax rates, subsidy rates, policy
parameters, closure variables, and other equilibrium quantities that are
naturally determined by explicit conditions.

## API

Useful starting points are:

- [`ConditionAgentSpec`](@ref)
- [`add_agent!`](@ref)
- `agent_variable_ref`
- `PriceVariableRef`
- [`GEMBModel`](@ref)
- [`build_model`](@ref)
