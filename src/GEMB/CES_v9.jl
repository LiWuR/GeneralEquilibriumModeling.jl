# ================================================================
# CES_v9.jl
#
# Claim-free CES/DCES numerical layer.
#
# V8 removes all CES/DCES-specific ad valorem claim functions and helpers.
# Claim behavior is now implemented generically in the agent-construction
# layer through claim-rate modifier, so this file contains only ordinary CES/DCES
# production, cost, and Marshallian-demand formulas.
#
# p, y, and w may be ordinary numbers or scalar expressions constructed
# by JuMP/Symbolics. beta, es, alpha, and xi are model parameters and are
# expected to be numerically determined when the model is constructed.
#
# For symbolic p, y, and w, value checks that cannot be decided at model
# construction time are skipped. Their domains must then be guaranteed by
# variable bounds or model constraints.
# ================================================================

const CES_V8_LOADED = true


"""
    DCES_input(beta, y, p; es=1, alpha=1, xi=zeros(length(beta)))

Compute compensated input demand for

    F(x) = alpha *
           (sum(beta[i]^(1 / es) *
                (x[i] - xi[i])^((es - 1) / es)))^
           (es / (es - 1)).

`beta` is the DCES share vector, `alpha > 0` is the efficiency parameter,
and every price in `p` must be strictly positive.
"""
function DCES_input(
    beta::AbstractVector,
    y,
    p::AbstractVector;
    es::Real = 1,
    alpha::Real = 1,
    xi::AbstractVector = zeros(length(beta))
)
    _check_DCES_arguments(beta, y, p, es, alpha, xi)

    unit_input = if isone(es)
        unit_cost = exp(sum(beta .* log.(p)))
        beta .* unit_cost ./ p
    else
        price_sum = sum(beta .* p .^ (one(es) - es))
        beta .* p .^ (-es) .* price_sum^(es / (one(es) - es))
    end

    return xi .+ (y / alpha) .* unit_input
end


"""
    DCES_cost(beta, y, p; es=1, alpha=1, xi=zeros(length(beta)))

Compute the minimum DCES cost

    C(p, y) = dot(p, xi) +
              (y / alpha) *
              (sum(beta[i] * p[i]^(1 - es)))^(1 / (1 - es)).
"""
function DCES_cost(
    beta::AbstractVector,
    y,
    p::AbstractVector;
    es::Real = 1,
    alpha::Real = 1,
    xi::AbstractVector = zeros(length(beta))
)
    _check_DCES_arguments(beta, y, p, es, alpha, xi)

    unit_cost = if isone(es)
        exp(sum(beta .* log.(p)))
    else
        sum(beta .* p .^ (one(es) - es))^(one(es) / (one(es) - es))
    end

    return sum(p .* xi) + (y / alpha) * unit_cost
end


"""
    DCES_demand(beta, w, p; es=1, alpha=1, xi=zeros(length(beta)))

Compute DCES Marshallian demand.

Let

    ID = w - dot(p, xi).

Then

    demand[i] = xi[i] +
                beta[i] * ID * p[i]^(-es) /
                sum(beta[j] * p[j]^(1 - es)
                    for j in eachindex(beta)).

All prices in `p` must be strictly positive.
"""
function DCES_demand(
    beta::AbstractVector,
    w,
    p::AbstractVector;
    es::Real = 1,
    alpha::Real = 1,
    xi::AbstractVector = zeros(length(beta))
)
    _check_DCES_arguments(beta, 0, p, es, alpha, xi)
    _require_when_decidable(
        () -> isfinite(w),
        "Income w must be finite."
    )

    disposable_income = w - sum(p .* xi)
    if _decidable_bool(() -> disposable_income < 0) === true
        @warn "Income w is insufficient to purchase the minimum-consumption vector xi." w minimum_expenditure=sum(p .* xi)
        return beta .* 0
    end

    price_sum = sum(beta .* p .^ (one(es) - es))
    return xi .+ beta .* disposable_income .* p .^ (-es) ./ price_sum
end


"""
    CES_input(beta, y, p; es=1, alpha=1)

Compute cost-minimizing input demand for the CES basic form

    f(x) = alpha *
           (sum(beta[i] * x[i]^((es - 1) / es)))^(es / (es - 1)).

When `es != 1`, the original `beta` coefficients are retained and are not
required to sum to one. `es == 0` uses the Leontief limit. `es == 1` uses
the Cobb--Douglas limit and requires `sum(beta) == 1`.
"""
function CES_input(
    beta::AbstractVector,
    y,
    p::AbstractVector;
    es::Real = 1,
    alpha::Real = 1
)
    _check_CES_arguments(beta, y, p, es, alpha)

    if iszero(es)
        input_per_active_good = y / alpha
        active = [iszero(b) ? zero(b) : one(b) for b in beta]
        return active .* input_per_active_good
    elseif isone(es)
        log_price_index = sum(
            iszero(b) ? 0 : b * (log(pi) - log(b))
            for (b, pi) in zip(beta, p)
        )
        unit_cost = exp(log_price_index) / alpha
        return y .* beta .* unit_cost ./ p
    else
        beta_power = beta .^ es
        price_sum = sum(beta_power .* p .^ (one(es) - es))
        unit_input = beta_power .* p .^ (-es) .*
                     price_sum^(es / (one(es) - es)) ./ alpha
        return y .* unit_input
    end
end


"""
    CES_demand(beta, w, p; es=1, alpha=1)

Compute CES Marshallian demand.

All prices in `p` must be strictly positive. The positive utility scale
parameter `alpha` does not affect Marshallian demand.
"""
function CES_demand(
    beta::AbstractVector,
    w,
    p::AbstractVector;
    es::Real = 1,
    alpha::Real = 1
)
    _check_CES_arguments(beta, 0, p, es, alpha)
    _require_when_decidable(
        () -> isfinite(w),
        "Income w must be finite."
    )

    if _decidable_bool(() -> w < 0) === true
        @warn "Income w cannot be negative; returning a zero vector." w
        return beta .* 0
    end

    if iszero(es)
        active_price_sum = sum(
            pi for (b, pi) in zip(beta, p) if b > 0
        )
        demand_per_active_good = w / active_price_sum
        active_coefficient = [iszero(b) ? zero(b) : one(b) for b in beta]
        return active_coefficient .* demand_per_active_good
    elseif isone(es)
        return beta .* w ./ p
    else
        beta_power = beta .^ es
        price_sum = sum(beta_power .* p .^ (one(es) - es))
        return beta_power .* w .* p .^ (-es) ./ price_sum
    end
end


"""
    CES_cost(beta, y, p; es=1, alpha=1)

Compute minimum cost for the CES basic form.
"""
function CES_cost(
    beta::AbstractVector,
    y,
    p::AbstractVector;
    es::Real = 1,
    alpha::Real = 1
)
    _check_CES_arguments(beta, y, p, es, alpha)

    unit_cost = if iszero(es)
        sum(pi for (b, pi) in zip(beta, p) if b > 0) / alpha
    elseif isone(es)
        log_price_index = sum(
            iszero(b) ? 0 : b * (log(pi) - log(b))
            for (b, pi) in zip(beta, p)
        )
        exp(log_price_index) / alpha
    else
        beta_power = beta .^ es
        price_sum = sum(beta_power .* p .^ (one(es) - es))
        price_sum^(one(es) / (one(es) - es)) / alpha
    end

    return y * unit_cost
end


# ----------------------------------------------------------------
# General CES/DCES argument validation
# ----------------------------------------------------------------

function _check_DCES_arguments(
    beta::AbstractVector,
    y,
    p::AbstractVector,
    es::Real,
    alpha::Real,
    xi::AbstractVector
)
    _check_common_arguments(beta, y, p, es)

    isfinite(alpha) || throw(ArgumentError(
        "Efficiency parameter alpha must be finite."
    ))
    alpha > 0 || throw(ArgumentError(
        "Efficiency parameter alpha must be greater than zero."
    ))

    length(xi) == length(beta) || throw(DimensionMismatch(
        "xi length must equal beta length."
    ))
    all(isfinite, xi) || throw(ArgumentError(
        "All xi elements must be finite."
    ))

    beta_sum = sum(beta)
    if !isapprox(beta_sum, one(beta_sum))
        @warn "The DCES beta vector should sum to one." beta_sum
    end

    return nothing
end


function _check_CES_arguments(
    beta::AbstractVector,
    y,
    p::AbstractVector,
    es::Real,
    alpha::Real
)
    _check_common_arguments(beta, y, p, es)

    isfinite(alpha) || throw(ArgumentError(
        "Efficiency parameter alpha must be finite."
    ))
    alpha > 0 || throw(ArgumentError(
        "Efficiency parameter alpha must be greater than zero."
    ))

    if isone(es)
        beta_sum = sum(beta)
        if !isapprox(beta_sum, one(beta_sum))
            @warn "When es == 1, the CES beta vector should sum to one." beta_sum
        end
    end

    return nothing
end


function _check_common_arguments(
    beta::AbstractVector,
    y,
    p::AbstractVector,
    es::Real
)
    isempty(beta) && throw(ArgumentError(
        "beta cannot be empty."
    ))
    length(p) == length(beta) || throw(DimensionMismatch(
        "p length must equal beta length."
    ))
    all(isfinite, beta) || throw(ArgumentError(
        "All beta elements must be finite."
    ))
    all(beta .>= 0) || throw(ArgumentError(
        "beta cannot contain negative elements."
    ))
    any(beta .> 0) || throw(ArgumentError(
        "beta must contain at least one positive element."
    ))

    _check_price_values(p)

    _require_when_decidable(
        () -> isfinite(y),
        "Output/activity level y must be finite."
    )
    _require_when_decidable(
        () -> y >= 0,
        "Output/activity level y cannot be negative."
    )
    isfinite(es) || throw(ArgumentError(
        "Elasticity es must be finite."
    ))
    es >= 0 || throw(ArgumentError(
        "Elasticity es cannot be negative."
    ))

    return nothing
end


# Try to decide a condition. Ordinary numerical conditions return Bool.
# Symbolic/JuMP conditions or unsupported predicates return nothing.
function _decidable_bool(condition::Function)
    result = try
        condition()
    catch
        return nothing
    end
    return result isa Bool ? result : nothing
end


# Enforce a check only when it can be decided at model-construction time.
function _require_when_decidable(
    condition::Function,
    message::AbstractString
)
    _decidable_bool(condition) === false && throw(ArgumentError(message))
    return nothing
end


# Ordinary CES/DCES prices must be strictly positive.
function _check_price_values(p::AbstractVector)
    for pi in p
        _require_when_decidable(
            () -> isfinite(pi),
            "All prices in p must be finite."
        )
        _require_when_decidable(
            () -> pi > 0,
            "All prices in p must be strictly positive."
        )
    end
    return nothing
end
