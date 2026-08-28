# ================================================================
# activity_demand_specs_v5.jl
#
# Behavioral specifications for agents whose ordinary commodity demand is
# known as a function of one activity level and prices. This includes the
# generic ActivityDemandSpec and the built-in CES/DCES specifications.
#
# This file is included directly into module GEMB.
# ================================================================

export AbstractActivityDemandSpec,
       ActivityDemandSpec,
       activity_demand,
       AbstractCESFunctionSpec,
       CESSpec,
       DCESSpec,
       PowerProductionSpec

"""
    AbstractActivityDemandSpec

Behavioral specification for an agent whose ordinary commodity demands can be
computed directly from an activity level and prices. For a producer, the
activity is a production level. For a consumer without outputs, the activity is
interpreted as a utility/welfare level.
"""
abstract type AbstractActivityDemandSpec end

"""
    ActivityDemandSpec(
        demand_function;
        producer_condition_function=nothing,
    )

Define a generic activity-demand specification.

`demand_function` computes conditional commodity demand from an activity
level and prices. It must accept either

    demand_function(activity, prices)

or

    demand_function(activity, prices, observed_values).

For a producer, `activity` is interpreted as a production level.
For a consumer without outputs, `activity` is interpreted as a
utility/welfare level.

`producer_condition_function` may optionally provide an explicit producer
condition for a producer built from this specification. Consumer condition
handling is determined by the activity-demand consumer builder.
"""
struct ActivityDemandSpec{F,G} <: AbstractActivityDemandSpec
    demand_function::F
    producer_condition_function::G
end

function ActivityDemandSpec(
    demand_function;
    producer_condition_function=nothing,
)
    return ActivityDemandSpec(
        demand_function,
        producer_condition_function,
    )
end

"""
    AbstractCESFunctionSpec

Abstract supertype for the built-in CES-family activity-demand
specifications.
"""
abstract type AbstractCESFunctionSpec <: AbstractActivityDemandSpec end

"""
    CESSpec

CES activity-demand specification.
"""
struct CESSpec{T<:Real} <: AbstractCESFunctionSpec
    beta::Vector{T}
    es::T
    alpha::T
end

"""
    DCESSpec

Displaced CES activity-demand specification.
"""
struct DCESSpec{T<:Real} <: AbstractCESFunctionSpec
    beta::Vector{T}
    es::T
    alpha::T
    xi::Vector{T}
end

function _check_function_parameters(beta, es, alpha)
    isempty(beta) && throw(ArgumentError("beta cannot be empty."))
    all(isfinite, beta) || throw(ArgumentError("beta must be finite."))
    all(x -> x >= 0, beta) || throw(ArgumentError("beta cannot contain negative values."))
    any(x -> x > 0, beta) || throw(ArgumentError("beta must contain at least one positive value."))
    isfinite(es) && es >= 0 || throw(ArgumentError("es must be finite and nonnegative."))
    isfinite(alpha) && alpha > 0 || throw(ArgumentError("alpha must be finite and positive."))

    if isone(es) && !isapprox(
        sum(beta), one(sum(beta)); rtol=1.0e-10, atol=1.0e-12,
    )
        throw(ArgumentError(
            "When es == 1, sum(beta) must equal 1 to retain homogeneity of degree one.",
        ))
    end
    return nothing
end

"""
    CESSpec(beta; es=1.0, alpha=1.0)

Construct a CES activity-demand specification.

`beta` contains the CES distribution parameters, `es` is the elasticity of
substitution, and `alpha` is the scale parameter. Claim behavior is specified
at agent construction time with `claim_rate`; the claim commodity is mapped
separately and resolves to `claim_index` in the low-level builder.

When a `CESSpec` is used to build a producer without fixed endowments, GEMB
uses `UnitRevenueExpenditureBalanceConditions` by default. A producer with
fixed endowments uses `TotalRevenueExpenditureBalanceConditions` instead.
The user may always override this default with `condition_rule=...`.
"""

function CESSpec(
    beta::AbstractVector{<:Real};
    es::Real=1.0,
    alpha::Real=1.0,
)
    _check_function_parameters(beta, es, alpha)
    T = promote_type(Float64, eltype(beta), typeof(es), typeof(alpha))
    return CESSpec{T}(T.(beta), T(es), T(alpha))
end

"""
    DCESSpec(beta; es=1.0, alpha=1.0, xi=zeros(length(beta)))

Construct a displaced CES activity-demand specification.

`beta` contains the CES distribution parameters, `es` is the elasticity of
substitution, `alpha` is the scale parameter, and `xi` contains the
displacement parameters. Claim behavior is specified at agent construction
time with `claim_rate`; the claim commodity is mapped separately and resolves
to `claim_index` in the low-level builder.

When a `DCESSpec` is used to build a producer, GEMB chooses the default
condition rule as follows:

- if every component of `xi` is zero and the producer has no fixed
  endowments, GEMB uses `UnitRevenueExpenditureBalanceConditions`;
- if any component of `xi` is nonzero, GEMB uses
  `TotalRevenueExpenditureBalanceConditions`;
- if the producer has fixed endowments, GEMB uses
  `TotalRevenueExpenditureBalanceConditions`.

The user may always override this default with `condition_rule=...`.

The distinction reflects the treatment of the producer's full net supply.
A zero-displacement DCES producer without fixed endowments is linear and
homogeneous in its activity level. A displaced DCES producer, or a producer
with fixed endowments, is evaluated at its current activity level through
`TotalRevenueExpenditureBalanceConditions`.

GEMB does not prohibit alternative research specifications.
"""

function DCESSpec(
    beta::AbstractVector{<:Real};
    es::Real=1.0,
    alpha::Real=1.0,
    xi::AbstractVector{<:Real}=zeros(length(beta)),
)
    length(xi) == length(beta) ||
        throw(DimensionMismatch("xi length must equal beta length."))
    _check_function_parameters(beta, es, alpha)
    all(isfinite, xi) || throw(ArgumentError("xi must be finite."))
    T = promote_type(Float64, eltype(beta), eltype(xi), typeof(es), typeof(alpha))
    return DCESSpec{T}(T.(beta), T(es), T(alpha), T.(xi))
end

"""
    PowerProductionSpec(; alpha=1.0, theta=1.0)

Define the one-input power production technology

    f(x) = alpha * x^theta

with `alpha > 0` and `theta > 0`.

When production activity is `z`, the conditional input demand is

    x(z) = (z / alpha)^(1 / theta).

`PowerProductionSpec` is producer-only and therefore requires nonempty
`output_indices` when passed to `build_agent`.

By default, a producer built from `PowerProductionSpec` uses
`TotalRevenueExpenditureBalanceConditions()`. Thus a positive activity level
implies equality between total revenue and total expenditure. For a producer,
this is equivalent to zero total profit. This default can be overridden
explicitly with `condition_rule=...`.

The default total revenue-expenditure balance condition is a modeling closure.
In particular, when `theta != 1`, it is not the same condition as
marginal-cost pricing or the first-order condition of unconstrained profit
maximization.
"""
struct PowerProductionSpec{T<:Real} <: AbstractActivityDemandSpec
    alpha::T
    theta::T

    function PowerProductionSpec{T}(alpha::T, theta::T) where {T<:Real}
        isfinite(alpha) && alpha > zero(alpha) || throw(ArgumentError(
            "alpha must be finite and positive.",
        ))
        isfinite(theta) && theta > zero(theta) || throw(ArgumentError(
            "theta must be finite and positive.",
        ))
        return new{T}(alpha, theta)
    end
end

function PowerProductionSpec(;
    alpha::Real=1.0,
    theta::Real=1.0,
)
    T = promote_type(Float64, typeof(alpha), typeof(theta))
    return PowerProductionSpec{T}(T(alpha), T(theta))
end

# ================================================================
# Activity-demand evaluation protocol
# ================================================================

function _call_activity_demand_function(
    demand_function,
    activity,
    prices,
    observed_values,
)
    if applicable(demand_function, activity, prices, observed_values)
        return demand_function(activity, prices, observed_values)
    elseif applicable(demand_function, activity, prices)
        return demand_function(activity, prices)
    end
    throw(ArgumentError(
        "activity demand_function must accept (activity, prices) or " *
        "(activity, prices, observed_values).",
    ))
end

"""
    activity_demand(spec, activity, prices[, observed_values])

Evaluate conditional demand for an activity-demand specification.

`ActivityDemandSpec` may wrap a user function accepting either
`(activity, prices)` or `(activity, prices, observed_values)`. Built-in
specifications dispatch directly to their corresponding demand formulas.
"""
function activity_demand(
    spec::ActivityDemandSpec,
    activity,
    prices,
    observed_values=Any[],
)
    return _call_activity_demand_function(
        spec.demand_function,
        activity,
        prices,
        observed_values,
    )
end

function activity_demand(
    spec::CESSpec,
    activity,
    prices,
    observed_values=Any[],
)
    return CES_input(
        spec.beta,
        activity,
        prices;
        es=spec.es,
        alpha=spec.alpha,
    )
end

function activity_demand(
    spec::DCESSpec,
    activity,
    prices,
    observed_values=Any[],
)
    return DCES_input(
        spec.beta,
        activity,
        prices;
        es=spec.es,
        alpha=spec.alpha,
        xi=spec.xi,
    )
end

function activity_demand(
    spec::PowerProductionSpec,
    activity,
    prices,
    observed_values=Any[],
)
    length(prices) == 1 || throw(DimensionMismatch(
        "PowerProductionSpec requires exactly one input price.",
    ))

    if activity isa Real
        isfinite(activity) || throw(ArgumentError(
            "PowerProductionSpec activity must be finite for numeric evaluation.",
        ))
        activity >= zero(activity) || throw(ArgumentError(
            "PowerProductionSpec activity cannot be negative.",
        ))
    end

    return [
        (activity / spec.alpha)^(one(spec.theta) / spec.theta),
    ]
end
