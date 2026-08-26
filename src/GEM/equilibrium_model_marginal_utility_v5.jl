# ================================================================
# equilibrium_model_marginal_utility_v5.jl
#
# Marginal-utility consumer complementarity conditions.
#
# V4 extends V3 in two directions:
#   1. The condition rule now belongs to EquilibriumAgentCoreV1.
#   2. A marginal-utility function may optionally depend on the values of
#      variables observed from other agents:
#          MU(demand)
#      or
#          MU(demand, observed_values).
#
# The rule itself analogously supports both condition interfaces:
#     rule(local_variables, local_prices, net_supply)
# and
#     rule(local_variables, local_prices, net_supply, observed_values).
#
# This file remains a pure model layer. It contains no JuMP/PATH code.
# ================================================================

"""
    EquilibriumMarginalUtilityModelV5

Define consumer equilibrium conditions from marginal utility, local prices,
net supply, and optional observed equilibrium variables.
"""
module EquilibriumMarginalUtilityModelV5

using ..EquilibriumAgentCoreV1: AbstractAgentConditionRule

export MarginalUtilityConsumerConditions,
       evaluate_marginal_utility

"""
    MarginalUtilityConsumerConditions(
        marginal_utility_function,
        demand_variable_positions,
        demand_price_positions,
        multiplier_variable_position,
    )

Define consumer complementarity conditions from marginal utility and a budget
constraint. The marginal-utility function may accept either `demand` or
`(demand, observed_values)` and must return one value per demand variable.
"""
struct MarginalUtilityConsumerConditions{F} <: AbstractAgentConditionRule
    marginal_utility_function::F
    demand_variable_positions::Vector{Int}
    demand_price_positions::Vector{Int}
    multiplier_variable_position::Int
end

function MarginalUtilityConsumerConditions(
    marginal_utility_function,
    demand_variable_positions::AbstractVector{<:Integer},
    demand_price_positions::AbstractVector{<:Integer},
    multiplier_variable_position::Integer,
)
    dv = Int.(collect(demand_variable_positions))
    dp = Int.(collect(demand_price_positions))

    isempty(dv) && throw(ArgumentError(
        "demand_variable_positions cannot be empty.",
    ))
    length(dv) == length(dp) || throw(DimensionMismatch(
        "demand_variable_positions and demand_price_positions must have " *
        "the same length.",
    ))
    all(>=(1), dv) || throw(ArgumentError(
        "demand_variable_positions must contain positive integers.",
    ))
    all(>=(1), dp) || throw(ArgumentError(
        "demand_price_positions must contain positive integers.",
    ))
    length(unique(dv)) == length(dv) || throw(ArgumentError(
        "demand_variable_positions cannot contain duplicates.",
    ))
    length(unique(dp)) == length(dp) || throw(ArgumentError(
        "demand_price_positions cannot contain duplicates.",
    ))
    multiplier_variable_position >= 1 || throw(ArgumentError(
        "multiplier_variable_position must be a positive integer.",
    ))
    multiplier_variable_position in dv && throw(ArgumentError(
        "multiplier_variable_position cannot overlap a demand variable position.",
    ))

    return MarginalUtilityConsumerConditions{typeof(marginal_utility_function)}(
        marginal_utility_function,
        dv,
        dp,
        Int(multiplier_variable_position),
    )
end

function _validate_marginal_utility(marginal_utility, demand)
    marginal_utility isa AbstractVector || throw(ArgumentError(
        "marginal_utility_function must return a vector.",
    ))
    length(marginal_utility) == length(demand) || throw(DimensionMismatch(
        "The marginal-utility vector length must equal the number of demand variables.",
    ))
    return marginal_utility
end

"""
    evaluate_marginal_utility(rule, demand[, observed_values])

Evaluate the marginal-utility function stored in `rule`.

The stored function may implement either `MU(demand)` or
`MU(demand, observed_values)`. If the two-argument form is applicable, it is
preferred so an agent that declares observed variables can use them directly.
"""
function evaluate_marginal_utility(
    rule::MarginalUtilityConsumerConditions,
    demand,
    observed_values,
)
    f = rule.marginal_utility_function

    marginal_utility = if applicable(f, demand, observed_values)
        f(demand, observed_values)
    elseif applicable(f, demand)
        f(demand)
    else
        throw(ArgumentError(
            "marginal_utility_function must accept either (demand) or " *
            "(demand, observed_values).",
        ))
    end

    return _validate_marginal_utility(marginal_utility, demand)
end

function evaluate_marginal_utility(
    rule::MarginalUtilityConsumerConditions,
    demand,
)
    f = rule.marginal_utility_function
    applicable(f, demand) || throw(ArgumentError(
        "marginal_utility_function requires observed_values; call " *
        "evaluate_marginal_utility(rule, demand, observed_values).",
    ))
    return _validate_marginal_utility(f(demand), demand)
end

function _condition_vector(
    rule::MarginalUtilityConsumerConditions,
    local_variables,
    local_prices,
    net_supply,
    observed_values,
)
    maximum(rule.demand_variable_positions) <= length(local_variables) ||
        throw(DimensionMismatch(
            "A demand variable position exceeds local_variables length.",
        ))
    rule.multiplier_variable_position <= length(local_variables) ||
        throw(DimensionMismatch(
            "multiplier_variable_position exceeds local_variables length.",
        ))
    maximum(rule.demand_price_positions) <= length(local_prices) ||
        throw(DimensionMismatch(
            "A demand price position exceeds local_prices length.",
        ))
    length(net_supply) == length(local_prices) || throw(DimensionMismatch(
        "net_supply and local_prices must have the same length.",
    ))

    demand = collect(local_variables[rule.demand_variable_positions])
    multiplier = local_variables[rule.multiplier_variable_position]
    marginal_utility = evaluate_marginal_utility(
        rule,
        demand,
        observed_values,
    )

    stationarity = [
        multiplier * local_prices[rule.demand_price_positions[k]] -
        marginal_utility[k]
        for k in eachindex(demand)
    ]

    budget_slack = sum(
        local_prices[k] * net_supply[k] for k in eachindex(local_prices)
    )

    return vcat(stationarity, [budget_slack])
end

function (rule::MarginalUtilityConsumerConditions)(
    local_variables,
    local_prices,
    net_supply,
)
    # Preserve the V3 interface. This path is intended for consumers that do
    # not declare cross-agent observed variables.
    return _condition_vector(
        rule,
        local_variables,
        local_prices,
        net_supply,
        Any[],
    )
end

function (rule::MarginalUtilityConsumerConditions)(
    local_variables,
    local_prices,
    net_supply,
    observed_values,
)
    return _condition_vector(
        rule,
        local_variables,
        local_prices,
        net_supply,
        observed_values,
    )
end

end # module EquilibriumMarginalUtilityModelV5
