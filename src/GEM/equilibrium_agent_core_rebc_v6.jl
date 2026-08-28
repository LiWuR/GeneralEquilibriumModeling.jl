# ================================================================
# equilibrium_agent_core_v1.jl
#
# Core economic-agent types and generic accessors for GEM.
#
# This file is intentionally independent of the equilibrium-model container,
# auxiliary variables, JuMP, and PATH.
# ================================================================

"""
    EquilibriumAgentCoreV1

Defines the core economic-agent abstractions, condition rules, equilibrium-
variable references, and generic agent accessors used by GEM.
"""
module EquilibriumAgentCoreV1

export AbstractNetSupplyAgent,
       AbstractAgentConditionRule,
       AbstractEquilibriumVariableRef,
       UnitRevenueExpenditureBalanceConditions,
       TotalRevenueExpenditureBalanceConditions,
       ExplicitAgentConditions,
       AgentVariableRef,
       agent_name,
       agent_commodity_indices,
       agent_variable_count,
       agent_condition_rule,
       agent_uses_automatic_conditions,
       agent_observed_variables,
       agent_observed_variable_count,
       agent_net_supply

"""
    AbstractNetSupplyAgent

Abstract supertype for economic agents represented through net supply in GEM.
"""
abstract type AbstractNetSupplyAgent end

"""
    AbstractAgentConditionRule

Abstract supertype for rules that define agent-specific equilibrium conditions.
"""
abstract type AbstractAgentConditionRule end

"""
    AbstractEquilibriumVariableRef

Abstract supertype for references to endogenous equilibrium variables.
"""
abstract type AbstractEquilibriumVariableRef end

"""
    AgentVariableRef(agent_name, variable_name)

Reference to an endogenous variable owned by another economic agent.

`agent_name` identifies the agent and `variable_name` identifies the referenced
variable within that agent.
"""
struct AgentVariableRef <: AbstractEquilibriumVariableRef
    agent_name::Symbol
    variable_name::Symbol
end

Base.:(==)(a::AgentVariableRef, b::AgentVariableRef) =
    a.agent_name == b.agent_name && a.variable_name == b.variable_name
Base.hash(ref::AgentVariableRef, h::UInt) =
    hash(ref.variable_name, hash(ref.agent_name, h))

"""
    UnitRevenueExpenditureBalanceConditions

Construct one zero-profit condition per endogenous agent variable from
the value of net supply at one unit of that variable, with all other
agent variables set to zero.

For variable `k`, the complementarity mapping is

    -p' * s(e_k, p)

where `e_k` is the `k`th unit vector. This rule is appropriate when
net supply is linear and homogeneous in the activity variables.
"""
struct UnitRevenueExpenditureBalanceConditions <: AbstractAgentConditionRule end

"""
    TotalRevenueExpenditureBalanceConditions

Construct one total-profit condition per endogenous activity variable.

For activity `k`, let `z^(k)` be the activity vector that keeps the current
value of activity `k` and sets all other endogenous activity variables to zero.
The complementarity mapping is

    -p' * s(z^(k), p)

For an agent with one endogenous activity variable, this reduces to

    -p' * s(z, p)

This automatic construction is intended for a separable composite agent whose
activities can be evaluated independently. GEM does not check separability.
If activities interact, or if common fixed endowments or other
non-activity-specific net-supply components require a different allocation
across activity conditions, provide an explicit `condition_rule`.
"""
struct TotalRevenueExpenditureBalanceConditions <: AbstractAgentConditionRule end

"""
    ExplicitAgentConditions(condition_function)

Condition rule defined by an explicit numerical complementarity mapping.

`condition_function` must accept either
`(local_variables, local_prices, net_supply)` or
`(local_variables, local_prices, net_supply, observed_values)`.
"""
struct ExplicitAgentConditions{F} <: AbstractAgentConditionRule
    condition_function::F
end

function (rule::ExplicitAgentConditions)(
    local_variables,
    local_prices,
    net_supply,
)
    return rule.condition_function(local_variables, local_prices, net_supply)
end

function (rule::ExplicitAgentConditions)(
    local_variables,
    local_prices,
    net_supply,
    observed_values,
)
    if applicable(
        rule.condition_function,
        local_variables,
        local_prices,
        net_supply,
        observed_values,
    )
        return rule.condition_function(
            local_variables,
            local_prices,
            net_supply,
            observed_values,
        )
    elseif applicable(
        rule.condition_function,
        local_variables,
        local_prices,
        net_supply,
    )
        return rule.condition_function(local_variables, local_prices, net_supply)
    end
    throw(ArgumentError(
        "ExplicitAgentConditions.condition_function must accept either " *
        "(local_variables, local_prices, net_supply) or " *
        "(local_variables, local_prices, net_supply, observed_values).",
    ))
end

"""
    agent_name(agent)

Return the symbolic name of an economic agent.
"""
agent_name(agent::AbstractNetSupplyAgent) = agent.name

"""
    agent_commodity_indices(agent)

Return the model commodity indices associated with an economic agent.
"""
agent_commodity_indices(agent::AbstractNetSupplyAgent) = agent.commodity_indices

"""
    agent_variable_count(agent)

Return the number of endogenous variables owned by an economic agent.
"""
agent_variable_count(agent::AbstractNetSupplyAgent) = length(agent.variable_names)

"""
    agent_condition_rule(agent)

Return the equilibrium-condition rule associated with an economic agent.
"""
agent_condition_rule(agent::AbstractNetSupplyAgent) = agent.condition_rule

"""
    agent_observed_variables(agent)

Return the endogenous equilibrium-variable references observed by an agent.
"""
agent_observed_variables(agent::AbstractNetSupplyAgent) = agent.observed_variables

"""
    agent_observed_variable_count(agent)

Return the number of endogenous equilibrium variables observed by an agent.
"""
agent_observed_variable_count(agent::AbstractNetSupplyAgent) =
    length(agent.observed_variables)

"""
    agent_uses_automatic_conditions(agent)

Return `true` when an agent has endogenous variables and uses a profit
condition rule constructed automatically from net-supply value.
"""
agent_uses_automatic_conditions(agent::AbstractNetSupplyAgent) =
    (
        agent.condition_rule isa UnitRevenueExpenditureBalanceConditions ||
        agent.condition_rule isa TotalRevenueExpenditureBalanceConditions
    ) &&
    agent_variable_count(agent) > 0

"""
    _call_net_supply_function(agent, local_variables, local_prices, observed_values)

Call an agent's net-supply function using either its three-argument or
observed-variable-aware four-argument interface.
"""
function _call_net_supply_function(
    agent::AbstractNetSupplyAgent,
    local_variables,
    local_prices,
    observed_values,
)
    if applicable(
        agent.net_supply_function,
        local_variables,
        local_prices,
        observed_values,
    )
        return agent.net_supply_function(
            local_variables,
            local_prices,
            observed_values,
        )
    elseif applicable(
        agent.net_supply_function,
        local_variables,
        local_prices,
    )
        return agent.net_supply_function(local_variables, local_prices)
    end
    throw(ArgumentError(
        "Economic agent $(agent.name) net_supply_function must accept either " *
        "(local_variables, local_prices) or " *
        "(local_variables, local_prices, observed_values).",
    ))
end

"""
    agent_net_supply(agent, local_variables, local_prices[, observed_values])

Evaluate and validate an economic agent's local net-supply vector.

The returned vector follows GEM's sign convention: positive entries denote
supply and negative entries denote demand. If the agent declares observed
variables, `observed_values` must be supplied with matching length.
"""
function agent_net_supply(
    agent::AbstractNetSupplyAgent,
    local_variables,
    local_prices,
    observed_values,
)
    length(observed_values) == length(agent.observed_variables) ||
        throw(DimensionMismatch(
            "Economic agent $(agent.name) received an observed_values vector " *
            "whose length does not match observed_variables.",
        ))

    net_supply = _call_net_supply_function(
        agent,
        local_variables,
        local_prices,
        observed_values,
    )

    net_supply isa AbstractVector ||
        throw(ArgumentError(
            "Economic agent $(agent.name) net_supply_function must return a vector.",
        ))
    length(net_supply) == length(agent.commodity_indices) ||
        throw(DimensionMismatch(
            "Economic agent $(agent.name) returned net supply whose length " *
            "does not match commodity_indices.",
        ))
    return net_supply
end

function agent_net_supply(
    agent::AbstractNetSupplyAgent,
    local_variables,
    local_prices,
)
    isempty(agent.observed_variables) ||
        throw(ArgumentError(
            "Economic agent $(agent.name) declares observed variables; " *
            "agent_net_supply must be called with observed_values.",
        ))
    return agent_net_supply(agent, local_variables, local_prices, Any[])
end

end # module EquilibriumAgentCoreV1
