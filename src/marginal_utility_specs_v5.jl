# ================================================================
# marginal_utility_specs_v5.jl
#
# Analytical marginal-utility specifications for GEMB.
#
# This file defines reusable analytical marginal-utility specifications
# used by marginal-utility consumer builders and related high-level models.
#
# Public interface:
#
#   AbstractMarginalUtilitySpec
#   LinearMarginalUtilitySpec
#   CESMarginalUtilitySpec
#   QuadraticMarginalUtilitySpec
#   MeanStandardDeviationMarginalUtilitySpec
#   marginal_utility
#   marginal_utility_function
#
# This file is included directly into module GEMB. It intentionally does
# not define an additional nested module.
# ================================================================

using LinearAlgebra

export AbstractMarginalUtilitySpec,
       LinearMarginalUtilitySpec,
       CESMarginalUtilitySpec,
       QuadraticMarginalUtilitySpec,
       MeanStandardDeviationMarginalUtilitySpec,
       marginal_utility,
       marginal_utility_function


"""
    AbstractMarginalUtilitySpec

Abstract supertype for analytical marginal-utility specifications.
"""
abstract type AbstractMarginalUtilitySpec end


"""
    marginal_utility(spec, x)

Evaluate the marginal-utility vector of specification `spec` at bundle `x`.
"""
function marginal_utility end


"""
    marginal_utility_function(spec)

Return a one-argument function that evaluates `marginal_utility(spec, x)`.
"""
marginal_utility_function(spec::AbstractMarginalUtilitySpec) =
    x -> marginal_utility(spec, x)


# ----------------------------------------------------------------
# Validation helpers
# ----------------------------------------------------------------

function _check_weights(
    beta,
    name="beta",
)
    isempty(beta) &&
        throw(ArgumentError(
            "$(name) cannot be empty.",
        ))

    all(
        x -> x isa Real && isfinite(x),
        beta,
    ) || throw(ArgumentError(
        "$(name) must contain only finite real values.",
    ))

    all(
        x -> x >= 0,
        beta,
    ) || throw(ArgumentError(
        "$(name) cannot contain negative values.",
    ))

    any(
        x -> x > 0,
        beta,
    ) || throw(ArgumentError(
        "$(name) must contain at least one positive value.",
    ))

    return nothing
end


function _check_alpha(
    alpha,
)
    alpha isa Real &&
        isfinite(alpha) &&
        alpha > 0 ||
        throw(ArgumentError(
            "alpha must be a finite positive real value.",
        ))

    return nothing
end


function _check_x(
    x,
    n,
)
    x isa AbstractVector ||
        throw(ArgumentError(
            "x must be a vector.",
        ))

    length(x) == n ||
        throw(DimensionMismatch(
            "The length of x must equal $(n).",
        ))

    return nothing
end


# ----------------------------------------------------------------
# 1. Linear marginal utility
# ----------------------------------------------------------------

"""
    LinearMarginalUtilitySpec(beta; alpha=1.0)

Analytical marginal utility for the linear utility function

    V(x) = alpha * sum(beta[i] * x[i])

so that

    MU[i] = alpha * beta[i].

`beta` must be nonnegative and contain at least one positive entry.
`alpha` must be finite and strictly positive.
"""
struct LinearMarginalUtilitySpec{T<:Real} <:
       AbstractMarginalUtilitySpec
    beta::Vector{T}
    alpha::T
end


function LinearMarginalUtilitySpec(
    beta::AbstractVector{<:Real};
    alpha::Real=1.0,
)
    _check_weights(
        beta,
    )

    _check_alpha(
        alpha,
    )

    T =
        promote_type(
            Float64,
            eltype(beta),
            typeof(alpha),
        )

    return LinearMarginalUtilitySpec{T}(
        T.(beta),
        T(alpha),
    )
end


function marginal_utility(
    spec::LinearMarginalUtilitySpec,
    x::AbstractVector,
)
    _check_x(
        x,
        length(spec.beta),
    )

    return [
        spec.alpha *
        spec.beta[i]
        for i in eachindex(spec.beta)
    ]
end


# ----------------------------------------------------------------
# 2. CES marginal utility
# ----------------------------------------------------------------

"""
    CESMarginalUtilitySpec(beta; es=1.0)

Analytical marginal utility for an isoelastic/CES preference
representation with elasticity of substitution `es > 0`.

For `es != 1`, let

    rho = (es - 1) / es

and use the utility index

    V(x) = sum(beta[i] * x[i]^rho) / rho.

For `es == 1`, use the logarithmic limit

    V(x) = sum(beta[i] * log(x[i])).

Both representations give

    MU[i] = beta[i] * x[i]^(-1 / es).

The weights must be nonnegative with at least one positive entry and need
not sum to one. The nondifferentiable Leontief case `es == 0` is not
supported.
"""
struct CESMarginalUtilitySpec{T<:Real} <:
       AbstractMarginalUtilitySpec
    beta::Vector{T}
    es::T
end


function CESMarginalUtilitySpec(
    beta::AbstractVector{<:Real};
    es::Real=1.0,
)
    _check_weights(
        beta,
    )

    es isa Real &&
        isfinite(es) &&
        es > 0 ||
        throw(ArgumentError(
            "es must be a finite positive real value; " *
            "the nondifferentiable Leontief case es == 0 is not supported.",
        ))

    T =
        promote_type(
            Float64,
            eltype(beta),
            typeof(es),
        )

    return CESMarginalUtilitySpec{T}(
        T.(beta),
        T(es),
    )
end


function marginal_utility(
    spec::CESMarginalUtilitySpec,
    x::AbstractVector,
)
    _check_x(
        x,
        length(spec.beta),
    )

    exponent =
        -one(spec.es) /
        spec.es

    return [
        iszero(spec.beta[i]) ?
            zero(x[i]) :
            spec.beta[i] *
            x[i]^exponent
        for i in eachindex(spec.beta)
    ]
end


# ----------------------------------------------------------------
# 3. Quadratic marginal utility
# ----------------------------------------------------------------

"""
    QuadraticMarginalUtilitySpec(a, Q)

Analytical marginal utility for the quadratic utility function

    V(x) = dot(a, x) - 0.5 * x' * Q * x.

The symmetric part

    Qs = (Q + Q') / 2

is stored, giving

    MU = a - Qs * x.

Use a positive semidefinite `Q` when a concave utility function is required.
The constructor does not impose positive semidefiniteness because nonconcave
specifications may be useful in more general equilibrium experiments.
"""
struct QuadraticMarginalUtilitySpec{T<:Real} <:
       AbstractMarginalUtilitySpec
    a::Vector{T}
    Q::Matrix{T}
end


function QuadraticMarginalUtilitySpec(
    a::AbstractVector{<:Real},
    Q::AbstractMatrix{<:Real},
)
    isempty(a) &&
        throw(ArgumentError(
            "a cannot be empty.",
        ))

    all(
        isfinite,
        a,
    ) || throw(ArgumentError(
        "a must contain only finite values.",
    ))

    size(Q) == (
        length(a),
        length(a),
    ) || throw(DimensionMismatch(
        "Q dimensions must match the length of a.",
    ))

    all(
        isfinite,
        Q,
    ) || throw(ArgumentError(
        "Q must contain only finite values.",
    ))

    T =
        promote_type(
            Float64,
            eltype(a),
            eltype(Q),
        )

    aT =
        T.(a)

    QT =
        Matrix{T}(Q)

    Qs =
        (
            QT +
            QT'
        ) /
        2

    return QuadraticMarginalUtilitySpec{T}(
        aT,
        Matrix{T}(Qs),
    )
end


function marginal_utility(
    spec::QuadraticMarginalUtilitySpec,
    x::AbstractVector,
)
    n =
        length(spec.a)

    _check_x(
        x,
        n,
    )

    return [
        spec.a[i] -
        sum(
            spec.Q[i, j] *
            x[j]
            for j in 1:n
        )
        for i in 1:n
    ]
end


# ----------------------------------------------------------------
# 4. Mean-standard-deviation marginal utility
# ----------------------------------------------------------------

"""
    MeanStandardDeviationMarginalUtilitySpec(
        expected_payoff,
        payoff_sd,
        correlation,
        gamma;
        epsilon_sd=1.0e-8,
    )

Analytical marginal utility for mean-standard-deviation asset preferences.

Let

    D = Diagonal(payoff_sd)
    Sigma = D * correlation * D.

The smoothed utility is

    V(x) =
        dot(expected_payoff, x) -
        gamma * sqrt(x' * Sigma * x + epsilon_sd^2),

with marginal utility

    MU[i] =
        expected_payoff[i] -
        gamma * (Sigma * x)[i] /
        sqrt(x' * Sigma * x + epsilon_sd^2).

`gamma` must be nonnegative and `epsilon_sd` must be strictly positive.

`correlation` must

- match the payoff-vector dimensions,
- contain finite entries in `[-1, 1]`,
- be symmetric,
- have unit diagonal, and
- be positive semidefinite.

The positive-semidefinite check ensures that the implied covariance matrix
`Sigma` defines a nonnegative portfolio variance.
"""
struct MeanStandardDeviationMarginalUtilitySpec{T<:Real} <:
       AbstractMarginalUtilitySpec
    expected_payoff::Vector{T}
    payoff_sd::Vector{T}
    correlation::Matrix{T}
    gamma::T
    epsilon_sd::T
end


function MeanStandardDeviationMarginalUtilitySpec(
    expected_payoff::AbstractVector{<:Real},
    payoff_sd::AbstractVector{<:Real},
    correlation::AbstractMatrix{<:Real},
    gamma::Real;
    epsilon_sd::Real=1.0e-8,
)
    isempty(expected_payoff) &&
        throw(ArgumentError(
            "expected_payoff cannot be empty.",
        ))

    all(
        isfinite,
        expected_payoff,
    ) || throw(ArgumentError(
        "expected_payoff must contain only finite values.",
    ))

    n =
        length(
            expected_payoff,
        )

    length(payoff_sd) == n ||
        throw(DimensionMismatch(
            "The length of payoff_sd must equal the length of " *
            "expected_payoff ($(n)).",
        ))

    all(
        isfinite,
        payoff_sd,
    ) || throw(ArgumentError(
        "payoff_sd must contain only finite values.",
    ))

    all(
        x -> x >= 0,
        payoff_sd,
    ) || throw(ArgumentError(
        "payoff_sd cannot contain negative values.",
    ))

    size(correlation) == (
        n,
        n,
    ) || throw(DimensionMismatch(
        "correlation must be a $(n) x $(n) matrix.",
    ))

    all(
        isfinite,
        correlation,
    ) || throw(ArgumentError(
        "correlation must contain only finite values.",
    ))

    all(
        x -> -1 <= x <= 1,
        correlation,
    ) || throw(ArgumentError(
        "correlation coefficients must lie in [-1, 1].",
    ))

    isapprox(
        correlation,
        correlation';
        rtol=1.0e-10,
        atol=1.0e-12,
    ) || throw(ArgumentError(
        "correlation must be symmetric.",
    ))

    all(
        i -> isapprox(
            correlation[i, i],
            1;
            rtol=1.0e-10,
            atol=1.0e-12,
        ),
        1:n,
    ) || throw(ArgumentError(
        "The diagonal entries of correlation must equal 1.",
    ))

    gamma isa Real &&
        isfinite(gamma) &&
        gamma >= 0 ||
        throw(ArgumentError(
            "gamma must be a finite nonnegative real value.",
        ))

    epsilon_sd isa Real &&
        isfinite(epsilon_sd) &&
        epsilon_sd > 0 ||
        throw(ArgumentError(
            "epsilon_sd must be a finite positive real value.",
        ))

    T =
        promote_type(
            Float64,
            eltype(expected_payoff),
            eltype(payoff_sd),
            eltype(correlation),
            typeof(gamma),
            typeof(epsilon_sd),
        )

    expected_payoff_T =
        T.(expected_payoff)

    payoff_sd_T =
        T.(payoff_sd)

    correlation_T =
        Matrix{T}(
            correlation,
        )

    correlation_symmetric =
        (
            correlation_T +
            correlation_T'
        ) /
        2

    minimum_correlation_eigenvalue =
        eigmin(
            Symmetric(
                correlation_symmetric,
            ),
        )

    minimum_correlation_eigenvalue >= -1.0e-10 ||
        throw(ArgumentError(
            "correlation must be positive semidefinite.",
        ))

    return MeanStandardDeviationMarginalUtilitySpec{T}(
        expected_payoff_T,
        payoff_sd_T,
        Matrix{T}(
            correlation_symmetric,
        ),
        T(gamma),
        T(epsilon_sd),
    )
end


function marginal_utility(
    spec::MeanStandardDeviationMarginalUtilitySpec,
    x::AbstractVector,
)
    n =
        length(
            spec.expected_payoff,
        )

    _check_x(
        x,
        n,
    )

    # D * x
    scaled_x = [
        spec.payoff_sd[i] *
        x[i]
        for i in 1:n
    ]

    # correlation * (D * x)
    correlation_times_scaled_x = [
        sum(
            spec.correlation[i, j] *
            scaled_x[j]
            for j in 1:n
        )
        for i in 1:n
    ]

    # Sigma * x = D * correlation * D * x
    covariance_times_x = [
        spec.payoff_sd[i] *
        correlation_times_scaled_x[i]
        for i in 1:n
    ]

    # x' * Sigma * x
    variance =
        sum(
            scaled_x[i] *
            spec.correlation[i, j] *
            scaled_x[j]
            for i in 1:n, j in 1:n
        )

    portfolio_sd =
        sqrt(
            variance +
            spec.epsilon_sd^2,
        )

    return [
        spec.expected_payoff[i] -
        spec.gamma *
        covariance_times_x[i] /
        portfolio_sd
        for i in 1:n
    ]
end
