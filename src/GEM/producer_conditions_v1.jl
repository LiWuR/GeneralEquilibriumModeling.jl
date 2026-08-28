# ================================================================
# producer_conditions_v1.jl
#
# Unified pure-model production condition rules for GEM.
#
# This module consolidates the two production-function condition rules:
#
#   1. ProductionStationarityConditions
#   2. CostMinimizationKKTConditions
#
# Both rules use the canonical local-variable order
#
#   [activity, input_1, ..., input_m, production_multiplier]
#
# and generate the same residual vector
#
#   total_loss
#   p_1 - lambda * MP_1
#   ...
#   p_m - lambda * MP_m
#   production - activity
#
# Their economic interpretation differs through the bounds imposed on the
# paired local variables:
#
#   :stationary
#       stationary first-order system; the production multiplier may be free.
#
#   :cost_min
#       KKT complementarity for cost minimization; inputs and the production
#       multiplier are nonnegative.
#
# The net-supply accounting map remains separate. This module contains no
# JuMP/PATH code and constructs no agent objects.
# ================================================================

"""
    ProducerConditionsV1

Define stationary-production and cost-minimization KKT condition rules using a
common local-variable order and residual mapping.
"""
module ProducerConditionsV1

using ..EquilibriumAgentCoreV1: AbstractAgentConditionRule

export AbstractProductionConditions,
       ProductionStationarityConditions,
       CostMinimizationKKTConditions,
       evaluate_production,
       evaluate_marginal_product,
       evaluate_total_loss


# ----------------------------------------------------------------
# 1. Common production-condition interface
# ----------------------------------------------------------------

"""
    AbstractProductionConditions

Abstract supertype for production-function equilibrium-condition rules.
"""
abstract type AbstractProductionConditions <: AbstractAgentConditionRule end

function _normalize_input_price_positions(
    input_price_positions::AbstractVector{<:Integer},
)
    positions = Int.(collect(input_price_positions))

    isempty(positions) && throw(ArgumentError(
        "input_price_positions cannot be empty.",
    ))
    all(>=(1), positions) || throw(ArgumentError(
        "input_price_positions must contain positive integers.",
    ))
    length(unique(positions)) == length(positions) || throw(ArgumentError(
        "input_price_positions cannot contain duplicates.",
    ))

    return positions
end

function _canonical_variable_positions(input_count::Integer)
    input_count >= 1 || throw(ArgumentError(
        "A production condition rule requires at least one input.",
    ))

    return (
        activity=1,
        inputs=collect(2:(input_count + 1)),
        multiplier=input_count + 2,
    )
end


# ----------------------------------------------------------------
# 2. Production stationarity conditions
# ----------------------------------------------------------------

"""
    ProductionStationarityConditions(
        production_function,
        marginal_product_function,
        input_price_positions,
    )

Create a production stationarity condition rule.

The local-variable order is

    [activity, input_1, ..., input_m, production_multiplier]

and the condition vector is

    total_loss
    p_1 - lambda * MP_1
    ...
    p_m - lambda * MP_m
    production - activity

The supplied `marginal_product_function` may be a scaled marginal-product
function rather than the exact gradient of `production_function`. 

ProductionStationarityConditions imposes only the stationary first-order conditions, 
or marginal-pricing conditions. It is particularly useful when the production set is nonconvex, 
so cost-minimization conditions may be too restrictive. 
The current formulation assumes an interior solution, so the marginal-pricing conditions hold as equalities.
"""
struct ProductionStationarityConditions{PF,MPF} <: AbstractProductionConditions
    production_function::PF
    marginal_product_function::MPF
    activity_variable_position::Int
    input_variable_positions::Vector{Int}
    input_price_positions::Vector{Int}
    multiplier_variable_position::Int
end

function ProductionStationarityConditions(
    production_function,
    marginal_product_function,
    input_price_positions::AbstractVector{<:Integer},
)
    price_positions =
        _normalize_input_price_positions(input_price_positions)
    variable_positions =
        _canonical_variable_positions(length(price_positions))

    return ProductionStationarityConditions{
        typeof(production_function),
        typeof(marginal_product_function),
    }(
        production_function,
        marginal_product_function,
        variable_positions.activity,
        variable_positions.inputs,
        price_positions,
        variable_positions.multiplier,
    )
end


# ----------------------------------------------------------------
# 3. Cost-minimization KKT conditions
# ----------------------------------------------------------------

"""
    CostMinimizationKKTConditions(
        production_function,
        marginal_product_function,
        input_price_positions,
    )

Create a cost-minimization KKT condition rule.

The local-variable order is

    [activity, input_1, ..., input_m, production_multiplier]

and the condition vector is

    total_loss
    p_1 - lambda * MP_1
    ...
    p_m - lambda * MP_m
    production - activity

When the paired local-variable bounds satisfy

    activity >= 0
    input_i >= 0
    production_multiplier >= 0

the input and production conditions implement the standard KKT
complementarity conditions for cost minimization.

For nonconvex technologies, these KKT conditions are generally necessary
conditions only and do not guarantee a global cost minimum.

The supplied `marginal_product_function` may be a scaled marginal-product
function rather than the exact gradient of `production_function`. In
particular, multiplying all marginal products by a common positive scaling
factor does not change the stationary solution, because the production
multiplier `lambda` adjusts inversely to that scaling.

This can be useful when a scaled marginal-product expression has a simpler
algebraic form or is more convenient for numerical evaluation. The scaling
must preserve the relative proportions of the marginal products at each
evaluation point; component-specific scaling generally changes the first-order
conditions.

This rule represents stationary first-order conditions only. It does not
classify the stationary point as a cost minimum or a cost maximum.
"""
struct CostMinimizationKKTConditions{PF,MPF} <: AbstractProductionConditions
    production_function::PF
    marginal_product_function::MPF
    activity_variable_position::Int
    input_variable_positions::Vector{Int}
    input_price_positions::Vector{Int}
    multiplier_variable_position::Int
end

function CostMinimizationKKTConditions(
    production_function,
    marginal_product_function,
    input_price_positions::AbstractVector{<:Integer},
)
    price_positions =
        _normalize_input_price_positions(input_price_positions)
    variable_positions =
        _canonical_variable_positions(length(price_positions))

    return CostMinimizationKKTConditions{
        typeof(production_function),
        typeof(marginal_product_function),
    }(
        production_function,
        marginal_product_function,
        variable_positions.activity,
        variable_positions.inputs,
        price_positions,
        variable_positions.multiplier,
    )
end


# ----------------------------------------------------------------
# 4. Shared production-function evaluation
# ----------------------------------------------------------------

function _validate_production(production)
    (production isa AbstractArray || production isa Tuple) &&
        throw(ArgumentError(
            "production_function must return a scalar value or scalar expression.",
        ))
    return production
end

function _validate_marginal_product(marginal_product, inputs)
    marginal_product isa AbstractVector || throw(ArgumentError(
        "marginal_product_function must return a vector.",
    ))
    length(marginal_product) == length(inputs) || throw(DimensionMismatch(
        "The marginal-product vector length must equal the number of input variables.",
    ))
    return marginal_product
end

"""
    evaluate_production(rule, inputs[, observed_values])

Evaluate the production function stored in a production condition rule.

The stored function may implement either

    f(inputs)

or

    f(inputs, observed_values).

When `observed_values` is supplied, the two-argument form is preferred.
"""
function evaluate_production(
    rule::AbstractProductionConditions,
    inputs,
    observed_values,
)
    observed_values === nothing &&
        return evaluate_production(rule, inputs)

    f = rule.production_function

    production = if applicable(f, inputs, observed_values)
        f(inputs, observed_values)
    elseif applicable(f, inputs)
        f(inputs)
    else
        throw(ArgumentError(
            "production_function must accept either (inputs) or " *
            "(inputs, observed_values).",
        ))
    end

    return _validate_production(production)
end

function evaluate_production(
    rule::AbstractProductionConditions,
    inputs,
)
    f = rule.production_function

    applicable(f, inputs) || throw(ArgumentError(
        "production_function requires observed_values; call " *
        "evaluate_production(rule, inputs, observed_values).",
    ))

    return _validate_production(f(inputs))
end

"""
    evaluate_marginal_product(rule, inputs[, observed_values])

Evaluate the marginal-product function stored in a production condition rule.

The stored function may implement either

    MP(inputs)

or

    MP(inputs, observed_values).

When `observed_values` is supplied, the two-argument form is preferred.
"""
function evaluate_marginal_product(
    rule::AbstractProductionConditions,
    inputs,
    observed_values,
)
    observed_values === nothing &&
        return evaluate_marginal_product(rule, inputs)

    f = rule.marginal_product_function

    marginal_product = if applicable(f, inputs, observed_values)
        f(inputs, observed_values)
    elseif applicable(f, inputs)
        f(inputs)
    else
        throw(ArgumentError(
            "marginal_product_function must accept either (inputs) or " *
            "(inputs, observed_values).",
        ))
    end

    return _validate_marginal_product(marginal_product, inputs)
end

function evaluate_marginal_product(
    rule::AbstractProductionConditions,
    inputs,
)
    f = rule.marginal_product_function

    applicable(f, inputs) || throw(ArgumentError(
        "marginal_product_function requires observed_values; call " *
        "evaluate_marginal_product(rule, inputs, observed_values).",
    ))

    return _validate_marginal_product(f(inputs), inputs)
end


# ----------------------------------------------------------------
# 5. Shared total-loss evaluation
# ----------------------------------------------------------------

"""
    evaluate_total_loss(local_prices, net_supply)

Return total loss:

    total_loss = -sum(local_prices .* net_supply).

Positive net supply is supply and negative net supply is demand.
"""
function evaluate_total_loss(local_prices, net_supply)
    length(net_supply) == length(local_prices) || throw(DimensionMismatch(
        "net_supply and local_prices must have the same length.",
    ))

    return -sum(
        local_prices[k] * net_supply[k]
        for k in eachindex(local_prices)
    )
end


# ----------------------------------------------------------------
# 6. Shared condition mapping
# ----------------------------------------------------------------

function _validate_condition_arguments(
    rule::AbstractProductionConditions,
    local_variables,
    local_prices,
    net_supply,
)
    expected_variable_count =
        length(rule.input_variable_positions) + 2

    length(local_variables) == expected_variable_count ||
        throw(DimensionMismatch(
            "$(nameof(typeof(rule))) requires local_variables ordered as " *
            "[activity, inputs..., production_multiplier].",
        ))

    maximum(rule.input_price_positions) <= length(local_prices) ||
        throw(DimensionMismatch(
            "An input price position exceeds local_prices length.",
        ))

    length(net_supply) == length(local_prices) ||
        throw(DimensionMismatch(
            "net_supply and local_prices must have the same length.",
        ))

    return nothing
end

function _condition_vector(
    rule::AbstractProductionConditions,
    local_variables,
    local_prices,
    net_supply,
    observed_values,
)
    _validate_condition_arguments(
        rule,
        local_variables,
        local_prices,
        net_supply,
    )

    activity =
        local_variables[rule.activity_variable_position]

    inputs =
        collect(local_variables[rule.input_variable_positions])

    multiplier =
        local_variables[rule.multiplier_variable_position]

    production =
        evaluate_production(
            rule,
            inputs,
            observed_values,
        )

    marginal_product =
        evaluate_marginal_product(
            rule,
            inputs,
            observed_values,
        )

    total_loss =
        evaluate_total_loss(
            local_prices,
            net_supply,
        )

    input_residuals = [
        local_prices[rule.input_price_positions[k]] -
        multiplier * marginal_product[k]
        for k in eachindex(inputs)
    ]

    production_residual =
        production - activity

    return vcat(
        [total_loss],
        input_residuals,
        [production_residual],
    )
end

function (rule::AbstractProductionConditions)(
    local_variables,
    local_prices,
    net_supply,
)
    return _condition_vector(
        rule,
        local_variables,
        local_prices,
        net_supply,
        nothing,
    )
end

function (rule::AbstractProductionConditions)(
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

end # module ProducerConditionsV1
