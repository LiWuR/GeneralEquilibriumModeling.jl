# ================================================================
# activity_supply_specs_v1.jl
#
# Behavioral specifications for price-responsive activity outputs.
#
# This file is included directly into module GEMB.
# ================================================================

export AbstractActivitySupplySpec,
       CETSpec,
       activity_supply

"""
    AbstractActivitySupplySpec

Behavioral specification for the output side of an activity-demand producer.

An activity-supply specification maps the producer's activity level and output
prices into output quantities. It is separate from
`AbstractActivityDemandSpec`, which describes conditional input demand.
"""
abstract type AbstractActivitySupplySpec end

"""
    CETSpec(beta; et=1.0, alpha=1.0)

Define a constant-elasticity-of-transformation (CET) output specification.

`beta` contains nonnegative output weights, `et` is the elasticity of
transformation, and `alpha` is the scale parameter. GEMB uses the dual
unit-revenue representation

    r(p) =
        (sum(beta[i] * p[i]^(1 + et)))^(1 / (1 + et)) / alpha.

Conditional output supply is obtained from Hotelling's lemma:

    y_i(z, p) =
        (z / alpha) *
        beta[i] *
        p[i]^et *
        (sum(beta[j] * p[j]^(1 + et)))^(-et / (1 + et)).

Therefore

    (y_i / y_j) =
        (beta[i] / beta[j]) * (p_i / p_j)^et

whenever the relevant terms are positive, so `et` directly measures the
elasticity of the output ratio with respect to the relative output price.

When `et == 0`, the specification reduces to fixed output proportions:

    y_i(z) = (beta[i] / alpha) * z.

For numeric evaluation, CET output prices must be finite and nonnegative.
When `et > 0`, at least one output with positive `beta` must have a positive
price.

`CETSpec` is used through the `output_spec` keyword of the activity-demand
producer builder. It is mutually exclusive with `output_coefficients`.
"""
struct CETSpec{T<:Real} <: AbstractActivitySupplySpec
    beta::Vector{T}
    et::T
    alpha::T

    function CETSpec{T}(
        beta::Vector{T},
        et::T,
        alpha::T,
    ) where {T<:Real}
        isempty(beta) && throw(ArgumentError("beta cannot be empty."))
        all(isfinite, beta) || throw(ArgumentError(
            "beta must be finite.",
        ))
        all(x -> x >= zero(x), beta) || throw(ArgumentError(
            "beta cannot contain negative values.",
        ))
        any(x -> x > zero(x), beta) || throw(ArgumentError(
            "beta must contain at least one positive value.",
        ))
        isfinite(et) && et >= zero(et) || throw(ArgumentError(
            "et must be finite and nonnegative.",
        ))
        isfinite(alpha) && alpha > zero(alpha) || throw(ArgumentError(
            "alpha must be finite and positive.",
        ))
        return new{T}(beta, et, alpha)
    end
end

function CETSpec(
    beta::AbstractVector{<:Real};
    et::Real=1.0,
    alpha::Real=1.0,
)
    T = promote_type(Float64, eltype(beta), typeof(et), typeof(alpha))
    return CETSpec{T}(T.(beta), T(et), T(alpha))
end

function _validate_numeric_cet_prices(prices)
    all(p -> p isa Real, prices) || return nothing

    all(isfinite, prices) || throw(ArgumentError(
        "CET output prices must be finite for numeric evaluation.",
    ))
    all(p -> p >= zero(p), prices) || throw(ArgumentError(
        "CET output prices cannot be negative.",
    ))
    return nothing
end

"""
    activity_supply(spec::CETSpec, activity, prices[, observed_values])

Compute conditional CET output quantities for an activity level and output
prices. `observed_values` is accepted for protocol consistency and is not used
by `CETSpec`.
"""
function activity_supply(
    spec::CETSpec,
    activity,
    prices,
    observed_values=Any[],
)
    length(prices) == length(spec.beta) || throw(DimensionMismatch(
        "CET output price length must equal spec.beta length.",
    ))

    if activity isa Real
        isfinite(activity) || throw(ArgumentError(
            "CET activity must be finite for numeric evaluation.",
        ))
        activity >= zero(activity) || throw(ArgumentError(
            "CET activity cannot be negative.",
        ))
    end

    _validate_numeric_cet_prices(prices)

    if iszero(spec.et)
        return [
            (activity / spec.alpha) * spec.beta[i]
            for i in eachindex(spec.beta)
        ]
    end

    revenue_power_sum = sum(
        spec.beta[i] * prices[i]^(one(spec.et) + spec.et)
        for i in eachindex(spec.beta)
    )

    if revenue_power_sum isa Real
        revenue_power_sum > zero(revenue_power_sum) || throw(ArgumentError(
            "CET requires at least one positive-price output with positive beta " *
            "when et > 0.",
        ))
    end

    scale =
        (activity / spec.alpha) *
        revenue_power_sum^(-spec.et / (one(spec.et) + spec.et))

    return [
        scale * spec.beta[i] * prices[i]^spec.et
        for i in eachindex(spec.beta)
    ]
end
