# ================================================================
# demand_modifiers_v4.jl
#
# Generic modifiers that augment base activity demand without changing the
# underlying behavioral specification. _ClaimRateModifier is the current
# built-in modifier.
#
# This file is included directly into module GEMB.
# ================================================================


"""
    _AbstractDemandModifier

Abstract supertype for mechanisms that augment an agent's base commodity
requirements after `activity_demand` has been evaluated.
"""
abstract type _AbstractDemandModifier end

"""
    _ClaimRateModifier(tau)

Add one claim commodity whose signed expenditure equals `tau` times the value
of ordinary base demand. If base demand has value `B` and the claim price is
`p_claim`, the required claim quantity is

    q_claim = tau * B / p_claim.

`tau` must be finite and greater than `-1`. The sign of `tau` determines the direction of the proportional value transfer;
in that case equilibrium normally gives the claim a negative price so the claim
quantity remains nonnegative.
"""
struct _ClaimRateModifier{T<:Real} <: _AbstractDemandModifier
    tau::T

    function _ClaimRateModifier{T}(tau::T) where {T<:Real}
        isfinite(tau) || throw(ArgumentError("tau must be finite."))
        tau > -one(tau) || throw(ArgumentError("tau must be greater than -1."))
        return new{T}(tau)
    end
end

function _ClaimRateModifier(tau::Real)
    T = promote_type(Float64, typeof(tau))
    return _ClaimRateModifier{T}(T(tau))
end

function _normalize_demand_modifier(
    claim_rate,
    claim_index,
    demand_indices,
    output_indices,
)
    if claim_rate === nothing
        claim_index === nothing || throw(ArgumentError(
            "claim_index requires claim_rate to be specified.",
        ))
        return nothing, nothing
    end

    claim_rate isa Real || throw(ArgumentError(
        "claim_rate must be a real number.",
    ))

    # The claim-rate modifier is private. The public builder
    # API exposes only claim_rate and claim_index.
    modifier = _ClaimRateModifier(claim_rate)

    claim_index === nothing && throw(ArgumentError(
        "claim_index must be supplied when claim_rate is specified.",
    ))
    claim_index isa Integer || throw(ArgumentError(
        "claim_index must be a positive integer commodity index.",
    ))

    index = Int(claim_index)

    index >= 1 || throw(ArgumentError(
        "claim_index must be a positive integer commodity index.",
    ))
    index in demand_indices && throw(ArgumentError(
        "claim_index must not also appear in demand_indices; demand_indices " *
        "contain only ordinary base-demand commodities.",
    ))
    index in output_indices && throw(ArgumentError(
        "claim_index must not also appear in output_indices for an agent that " *
        "uses the claim as a demand modifier.",
    ))

    return modifier, index
end

function _claim_quantity(
    claim::_ClaimRateModifier,
    base_demand,
    base_prices,
    claim_price,
)
    base_value = sum(
        base_prices[k] * base_demand[k]
        for k in eachindex(base_demand)
    )

    # tau == 0 should reduce exactly to the no-claim quantity even when the
    # claim price happens to be zero.
    iszero(claim.tau) && return zero(base_value)

    iszero(claim_price) && throw(ArgumentError(
        "A nonzero claim rate cannot be evaluated at claim price zero.",
    ))

    return claim.tau * base_value / claim_price
end

_claim_cost_factor(claim::_ClaimRateModifier) = one(claim.tau) + claim.tau
