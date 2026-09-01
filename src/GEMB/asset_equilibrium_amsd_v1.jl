# ================================================================
# asset_equilibrium_amsd_v1.jl
#
# High-level asset-exchange equilibrium solver for additive
# mean-standard-deviation (AMSD) preferences.
#
# This file is included directly into module GEMB.
#
# Public API:
#
#   solve_asset_equilibrium_amsd(; Supply, gamma, PMP, PSD, Cor, ...)
#
# Core economic inputs:
#
#   Supply : n x m initial asset endowments
#   gamma  : length-m risk-aversion vector
#   PMP    : n x m subjective expected payoffs
#   PSD    : n x m subjective payoff standard deviations
#   Cor    : n x n payoff correlation matrix
#
# Rows are assets and columns are investors. The final asset is the
# default numeraire, but numeraire_index can be changed by the user.
# ================================================================

export solve_asset_equilibrium_amsd


# ----------------------------------------------------------------
# 1. Input validation
# ----------------------------------------------------------------

function _validate_asset_equilibrium_amsd_inputs(
    Supply,
    gamma,
    PMP,
    PSD,
    Cor,
    x0,
    lambda0,
    demand_upper_bounds,
    numeraire_index,
    numeraire_value,
    epsilon_sd,
    residual_tol,
    holding_tol,
    kkt_tol,
)
    n, m = size(Supply)

    n >= 2 || throw(ArgumentError(
        "Supply must contain at least two assets.",
    ))
    m >= 1 || throw(ArgumentError(
        "Supply must contain at least one investor.",
    ))

    size(PMP) == (n, m) || throw(DimensionMismatch(
        "PMP must have the same dimensions as Supply.",
    ))
    size(PSD) == (n, m) || throw(DimensionMismatch(
        "PSD must have the same dimensions as Supply.",
    ))
    size(Cor) == (n, n) || throw(DimensionMismatch(
        "Cor must be an n x n matrix, where n is the number of assets.",
    ))
    length(gamma) == m || throw(DimensionMismatch(
        "gamma length must equal the number of investors.",
    ))
    size(x0) == (n, m) || throw(DimensionMismatch(
        "x0 must have the same dimensions as Supply.",
    ))
    length(lambda0) == m || throw(DimensionMismatch(
        "lambda0 length must equal the number of investors.",
    ))
    length(demand_upper_bounds) == n || throw(DimensionMismatch(
        "demand_upper_bounds length must equal the number of assets.",
    ))

    all(isfinite, Supply) && all(Supply .>= 0) || throw(ArgumentError(
        "Supply must contain only finite nonnegative values.",
    ))
    all(isfinite, PMP) || throw(ArgumentError(
        "PMP must contain only finite values.",
    ))
    all(isfinite, PSD) && all(PSD .>= 0) || throw(ArgumentError(
        "PSD must contain only finite nonnegative values.",
    ))
    all(isfinite, Cor) || throw(ArgumentError(
        "Cor must contain only finite values.",
    ))
    all(isfinite, gamma) && all(gamma .>= 0) || throw(ArgumentError(
        "gamma must contain only finite nonnegative values.",
    ))
    all(isfinite, x0) && all(x0 .>= 0) || throw(ArgumentError(
        "x0 must contain only finite nonnegative values.",
    ))
    all(isfinite, lambda0) && all(lambda0 .>= 0) || throw(ArgumentError(
        "lambda0 must contain only finite nonnegative values.",
    ))
    all(isfinite, demand_upper_bounds) &&
        all(demand_upper_bounds .> 0) || throw(ArgumentError(
        "demand_upper_bounds must contain only finite positive values.",
    ))

    upper = reshape(Float64.(demand_upper_bounds), :, 1)
    all(x0 .<= upper) || throw(ArgumentError(
        "x0 cannot exceed demand_upper_bounds.",
    ))

    1 <= numeraire_index <= n || throw(ArgumentError(
        "numeraire_index must identify one of the assets.",
    ))
    isfinite(numeraire_value) && numeraire_value > 0 || throw(ArgumentError(
        "numeraire_value must be finite and positive.",
    ))
    isfinite(epsilon_sd) && epsilon_sd > 0 || throw(ArgumentError(
        "epsilon_sd must be finite and positive.",
    ))
    isfinite(residual_tol) && residual_tol > 0 || throw(ArgumentError(
        "residual_tol must be finite and positive.",
    ))
    isfinite(holding_tol) && holding_tol >= 0 || throw(ArgumentError(
        "holding_tol must be finite and nonnegative.",
    ))
    isfinite(kkt_tol) && kkt_tol >= 0 || throw(ArgumentError(
        "kkt_tol must be finite and nonnegative.",
    ))

    return nothing
end


# ----------------------------------------------------------------
# 2. Model construction
# ----------------------------------------------------------------

function _build_asset_equilibrium_amsd_model(
    Supply,
    gamma,
    PMP,
    PSD,
    Cor;
    x0,
    lambda0,
    epsilon_sd,
    demand_upper_bounds,
    numeraire_index,
    numeraire_value,
)
    n, m = size(Supply)
    asset_indices = collect(1:n)
    investors = GEM.AbstractNetSupplyAgent[]

    for i in 1:m
        utility_spec = MeanStandardDeviationMarginalUtilitySpec(
            PMP[:, i],
            PSD[:, i],
            Cor,
            gamma[i];
            epsilon_sd=epsilon_sd,
        )

        investor = build_agent(
            utility_spec;
            demand_indices=asset_indices,
            endowment_indices=asset_indices,
            endowment_quantities=Supply[:, i],
            demand_start=x0[:, i],
            demand_lower_bounds=zeros(n),
            demand_upper_bounds=Float64.(demand_upper_bounds),
            multiplier_start=lambda0[i],
            multiplier_lower_bound=0.0,
            name=Symbol(:investor_, i),
        )

        push!(investors, investor)
    end

    asset_names = [
        Symbol(:asset_, j)
        for j in 1:n
    ]

    return GEM.NetSupplyEquilibriumModel(
        investors,
        asset_names;
        numeraire_index=numeraire_index,
        numeraire_value=numeraire_value,
    )
end


# ----------------------------------------------------------------
# 3. AMSD diagnostics
# ----------------------------------------------------------------

function _asset_equilibrium_amsd_diagnostics(
    prices,
    D,
    lambda,
    Supply,
    gamma,
    PMP,
    PSD,
    Cor;
    epsilon_sd,
    holding_tol,
    kkt_tol,
)
    n, m = size(D)

    MU = Matrix{Float64}(undef, n, m)
    portfolio_sd = Vector{Float64}(undef, m)

    for i in 1:m
        spec = MeanStandardDeviationMarginalUtilitySpec(
            PMP[:, i],
            PSD[:, i],
            Cor,
            gamma[i];
            epsilon_sd=epsilon_sd,
        )

        MU[:, i] .= Float64.(marginal_utility(spec, D[:, i]))

        scaled_holding = PSD[:, i] .* D[:, i]
        variance = sum(
            scaled_holding[j] *
            Cor[j, k] *
            scaled_holding[k]
            for j in 1:n, k in 1:n
        )

        portfolio_sd[i] = sqrt(max(
            variance + Float64(epsilon_sd)^2,
            0.0,
        ))
    end

    positive_price_mask = prices .> 0.0
    VMU = fill(NaN, n, m)

    for j in 1:n
        positive_price_mask[j] || continue
        VMU[j, :] .= MU[j, :] ./ prices[j]
    end

    positive_multiplier_mask = lambda .> 0.0
    R = fill(NaN, n, m)

    for i in 1:m
        positive_multiplier_mask[i] || continue
        R[:, i] .= VMU[:, i] ./ lambda[i]
    end

    kkt_slack = [
        lambda[i] * prices[j] - MU[j, i]
        for j in 1:n, i in 1:m
    ]

    complementarity_product = D .* kkt_slack

    wealth = [
        sum(prices .* Supply[:, i])
        for i in 1:m
    ]

    expenditure = [
        sum(prices .* D[:, i])
        for i in 1:m
    ]

    budget_slack = wealth - expenditure
    budget_complementarity_product = lambda .* budget_slack

    aggregate_supply = vec(sum(Supply; dims=2))
    aggregate_demand = vec(sum(D; dims=2))
    market_residual = aggregate_supply - aggregate_demand

    positive_holding_mask = D .> holding_tol
    zero_holding_mask = .!positive_holding_mask

    positive_holding_vmu_error = fill(NaN, n, m)
    zero_holding_vmu_violation = fill(NaN, n, m)

    for j in 1:n, i in 1:m
        positive_price_mask[j] || continue

        gap = lambda[i] - VMU[j, i]

        if positive_holding_mask[j, i]
            positive_holding_vmu_error[j, i] = abs(gap)
        else
            zero_holding_vmu_violation[j, i] = max(-gap, 0.0)
        end
    end

    finite_max(values) = begin
        finite_values = filter(isfinite, vec(values))
        isempty(finite_values) ? 0.0 : maximum(finite_values)
    end

    max_positive_holding_vmu_error =
        finite_max(positive_holding_vmu_error)

    max_zero_holding_vmu_violation =
        finite_max(zero_holding_vmu_violation)

    max_stationarity_violation =
        maximum(max.(-kkt_slack, 0.0); init=0.0)

    max_complementarity_error =
        maximum(abs.(complementarity_product); init=0.0)

    max_holding_nonnegativity_violation =
        maximum(max.(-D, 0.0); init=0.0)

    max_multiplier_nonnegativity_violation =
        maximum(max.(-lambda, 0.0); init=0.0)

    max_budget_violation =
        maximum(max.(-budget_slack, 0.0); init=0.0)

    max_budget_complementarity_error =
        maximum(abs.(budget_complementarity_product); init=0.0)

    prices_strictly_positive = all(positive_price_mask)
    multipliers_strictly_positive = all(positive_multiplier_mask)

    consumer_kkt_passed =
        max_holding_nonnegativity_violation <= kkt_tol &&
        max_multiplier_nonnegativity_violation <= kkt_tol &&
        max_stationarity_violation <= kkt_tol &&
        max_complementarity_error <= kkt_tol &&
        max_budget_violation <= kkt_tol &&
        max_budget_complementarity_error <= kkt_tol

    value_marginal_utility_conditions_passed =
        prices_strictly_positive &&
        max_positive_holding_vmu_error <= kkt_tol &&
        max_zero_holding_vmu_violation <= kkt_tol

    return (
        wealth=wealth,
        expenditure=expenditure,
        portfolio_sd=portfolio_sd,
        aggregate_supply=aggregate_supply,
        aggregate_demand=aggregate_demand,
        market_residual=market_residual,
        MU=MU,
        VMU=VMU,
        R=R,
        kkt_slack=kkt_slack,
        complementarity_product=complementarity_product,
        budget_slack=budget_slack,
        budget_complementarity_product=budget_complementarity_product,
        positive_holding_mask=positive_holding_mask,
        zero_holding_mask=zero_holding_mask,
        positive_holding_vmu_error=positive_holding_vmu_error,
        zero_holding_vmu_violation=zero_holding_vmu_violation,
        prices_strictly_positive=prices_strictly_positive,
        multipliers_strictly_positive=multipliers_strictly_positive,
        max_positive_holding_vmu_error=max_positive_holding_vmu_error,
        max_zero_holding_vmu_violation=max_zero_holding_vmu_violation,
        max_stationarity_violation=max_stationarity_violation,
        max_complementarity_error=max_complementarity_error,
        max_holding_nonnegativity_violation=
            max_holding_nonnegativity_violation,
        max_multiplier_nonnegativity_violation=
            max_multiplier_nonnegativity_violation,
        max_budget_violation=max_budget_violation,
        max_budget_complementarity_error=
            max_budget_complementarity_error,
        holding_tol=Float64(holding_tol),
        kkt_tol=Float64(kkt_tol),
        consumer_kkt_passed=consumer_kkt_passed,
        value_marginal_utility_conditions_passed=
            value_marginal_utility_conditions_passed,
        kkt_passed=consumer_kkt_passed,
    )
end


# ----------------------------------------------------------------
# 4. Public solver
# ----------------------------------------------------------------

"""
    solve_asset_equilibrium_amsd(;
        Supply,
        gamma,
        PMP,
        PSD,
        Cor,
        kwargs...,
    )

Solve a pure asset-exchange equilibrium with additive
mean-standard-deviation (AMSD) preferences.

Rows of `Supply`, `PMP`, and `PSD` are assets and columns are investors.

Required economic inputs:

- `Supply`: initial asset endowments;
- `gamma`: investor risk-aversion coefficients;
- `PMP`: subjective expected asset payoffs;
- `PSD`: subjective payoff standard deviations;
- `Cor`: payoff correlation matrix shared by the investors.

Optional arguments:

- `numeraire_index`: index of the numeraire asset; defaults to the final asset.
- `numeraire_value`: price of the numeraire asset; default `1.0`.
- `p0`: initial asset-price vector; defaults to a vector of ones.
- `x0`: initial asset-holding matrix for numerical solution; defaults to `Supply`.
- `lambda0`: initial budget-multiplier vector; defaults to a vector of ones.
- `demand_upper_bounds`: upper bounds on asset holdings; defaults to aggregate asset supplies.
- `price_floor`: lower bound on asset prices.
- `price_upper_bound`: upper bound on asset prices.
- `residual_tol`: equilibrium residual tolerance.
- `holding_tol`: tolerance used to identify positive holdings.
- `kkt_tol`: tolerance for KKT diagnostics.
- `silent`: suppress solver output when `true`.
- `path_options`: additional PATH solver options.

Investor `i` is represented internally by

    MeanStandardDeviationMarginalUtilitySpec(
        PMP[:, i],
        PSD[:, i],
        Cor,
        gamma[i];
        epsilon_sd=epsilon_sd,
    )

Short selling is excluded by default. Each investor's holding upper bound
for asset `j` defaults to the total economy-wide supply of that asset.

The final asset is the default numeraire. Use `numeraire_index` to choose
another asset.

The returned `GEM.EquilibriumResult` retains all ordinary GEM result fields
and additionally provides:

    p
    D
    lambda
    wealth
    expenditure
    portfolio_sd
    aggregate_supply
    aggregate_demand
    market_residual
    MU
    VMU
    R
    kkt_passed

where `D` is the equilibrium holding matrix and `lambda` contains the
investors' budget multipliers.

Reference:
Nakamura, Yutaka (2015). Mean-Variance Utility. Journal of Economic Theory, 160: 536-556.
"""
function solve_asset_equilibrium_amsd(;
    Supply::AbstractMatrix,
    gamma::AbstractVector,
    PMP::AbstractMatrix,
    PSD::AbstractMatrix,
    Cor::AbstractMatrix,
    numeraire_index::Integer=size(Supply, 1),
    numeraire_value::Real=1.0,
    p0::AbstractVector=ones(size(Supply, 1)),
    x0::AbstractMatrix=Supply,
    lambda0::AbstractVector=ones(size(Supply, 2)),
    epsilon_sd::Real=1.0e-8,
    demand_upper_bounds::AbstractVector=
        vec(sum(Supply; dims=2)),
    price_floor::Union{Real,AbstractVector}=1.0e-10,
    price_upper_bound::Union{Real,AbstractVector}=10.0,
    residual_tol::Real=1.0e-8,
    holding_tol::Real=1.0e-8,
    kkt_tol::Real=max(1.0e-7, 10 * Float64(residual_tol)),
    silent::Bool=false,
    path_options::NamedTuple=NamedTuple(),
)
    _validate_asset_equilibrium_amsd_inputs(
        Supply,
        gamma,
        PMP,
        PSD,
        Cor,
        x0,
        lambda0,
        demand_upper_bounds,
        numeraire_index,
        numeraire_value,
        epsilon_sd,
        residual_tol,
        holding_tol,
        kkt_tol,
    )

    n, m = size(Supply)

    model = _build_asset_equilibrium_amsd_model(
        Supply,
        gamma,
        PMP,
        PSD,
        Cor;
        x0=x0,
        lambda0=lambda0,
        epsilon_sd=epsilon_sd,
        demand_upper_bounds=demand_upper_bounds,
        numeraire_index=numeraire_index,
        numeraire_value=numeraire_value,
    )

    result = GEM.solve_equilibrium_model_mcp_jump(
        model;
        p0=Float64.(p0),
        price_floor=price_floor,
        price_upper_bound=price_upper_bound,
        residual_tol=residual_tol,
        silent=silent,
        path_options=path_options,
    )

    length(result.agent_variable_values) == m || throw(DimensionMismatch(
        "The solver result investor count does not match Supply.",
    ))

    for i in 1:m
        length(result.agent_variable_values[i]) == n + 1 ||
            throw(DimensionMismatch(
                "Investor $(i) must have n holdings plus one budget multiplier.",
            ))
    end

    D = hcat([
        Float64.(result.agent_variable_values[i][1:n])
        for i in 1:m
    ]...)

    lambda = Float64[
        result.agent_variable_values[i][n + 1]
        for i in 1:m
    ]

    prices = Float64.(result.prices)

    diagnostics = _asset_equilibrium_amsd_diagnostics(
        prices,
        D,
        lambda,
        Float64.(Supply),
        Float64.(gamma),
        Float64.(PMP),
        Float64.(PSD),
        Float64.(Cor);
        epsilon_sd=epsilon_sd,
        holding_tol=holding_tol,
        kkt_tol=kkt_tol,
    )

    asset_summary = merge(
        (
            p=copy(prices),
            D=D,
            lambda=lambda,
            Supply=Matrix{Float64}(Supply),
            gamma=Float64.(gamma),
            PMP=Matrix{Float64}(PMP),
            PSD=Matrix{Float64}(PSD),
            Cor=Matrix{Float64}(Cor),
            epsilon_sd=Float64(epsilon_sd),
        ),
        diagnostics,
    )

    return GEM.EquilibriumResult(
        merge(
            GEM.raw_result(result),
            asset_summary,
            (
                asset_summary=asset_summary,
                amsd_diagnostics=diagnostics,
            ),
        ),
    )
end
