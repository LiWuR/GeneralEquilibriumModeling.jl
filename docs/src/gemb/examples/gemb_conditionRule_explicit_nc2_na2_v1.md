# gemb_conditionRule_explicit_nc2_na2_v1

Source file: `examples/gemb_conditionRule_explicit_nc2_na2_v1.jl`

````julia
# ================================================================
# gemb_conditionRule_explicit_nc2_na2_v1.jl
#
# Standard GEMB example for ExplicitAgentConditions.
#
# Commodities:
#   1. product
#   2. labor
#
# Agents:
#   1. firm
#   2. household
#
# Technology:
#
#     1 unit of activity produces 1 unit of product
#     and requires 1 unit of labor.
#
# Unlike the UnitRevenueExpenditureBalanceConditions example, the producer condition is
# supplied explicitly by the researcher through
# producer_condition_function.
#
# The explicit residual is
#
#     F = -p' * s(z,p).
#
# GEMB therefore uses ExplicitAgentConditions by default for this
# ActivityDemandSpec.
#
# Equilibrium:
#
#     p_product = 1
#     p_labor   = 1
#     z         = 5
#     utility   = 5
# ================================================================

using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


# ----------------------------------------------------------------
# 1. Producer
#
# Conditional labor demand:
#
#     x_labor(z,p) = z.
#
# The producer_condition_function receives:
#
#     variables   local endogenous variables
#     prices      local commodity prices
#     net_supply  the producer's local net-supply vector
#
# Here the researcher explicitly imposes total accounting balance:
#
#     F = -p' * net_supply.
#
# Because producer_condition_function is supplied, GEMB defaults to
# ExplicitAgentConditions.
# ----------------------------------------------------------------

producer_spec = ActivityDemandSpec(
    (activity, prices) -> [activity];
    producer_condition_function=
        (variables, prices, net_supply) -> [
            -sum(prices .* net_supply),
        ],
)

firm = build_agent(
    producer_spec;
    output_indices=[1],
    demand_indices=[2],
    activity_start=5.0,
    name=:firm,
)

@assert agent_condition_rule(firm) isa ExplicitAgentConditions


# ----------------------------------------------------------------
# 2. Household
# ----------------------------------------------------------------

household = build_agent(
    CESSpec([1.0]);
    demand_indices=[1],
    endowment_indices=[2],
    endowment_quantities=[5.0],
    activity_start=5.0,
    name=:household,
)


# ----------------------------------------------------------------
# 3. Equilibrium model
# ----------------------------------------------------------------

model = EquilibriumModel(
    [firm, household],
    [:product, :labor],
)


# ----------------------------------------------------------------
# 4. Solve
# ----------------------------------------------------------------

result = solve_equilibrium_model_mcp_jump(
    model;
    p0=[1.0, 1.0],
    residual_tol=1.0e-8,
    silent=true,
)


# ----------------------------------------------------------------
# 5. Results and analytical checks
#
# The explicit producer condition is
#
#     F = -(p_product * z - p_labor * z).
#
# For z > 0 this gives p_product = p_labor.
# Product is the numeraire, so both prices equal one.
#
# Labor-market clearing then gives z = 5.
# ----------------------------------------------------------------

firm_activity = result.agent_variable_values[1][1]
household_utility = result.agent_variable_values[2][1]

println("========== GEMB ExplicitAgentConditions ==========")
println("Solved:               ", result.solved)
println("Prices:               ", result.prices)
println("Firm activity:        ", firm_activity)
println("Household utility:    ", household_utility)
println("Firm condition rule:  ", typeof(agent_condition_rule(firm)))
println("Total net supply:     ", result.total_net_supply)
println("Max natural residual: ", result.max_natural_residual)
println("==================================================")

@assert result.solved
@assert isapprox(result.prices, [1.0, 1.0]; atol=1.0e-7, rtol=1.0e-7)
@assert isapprox(firm_activity, 5.0; atol=1.0e-7, rtol=1.0e-7)
@assert isapprox(household_utility, 5.0; atol=1.0e-7, rtol=1.0e-7)
@assert maximum(abs, result.total_net_supply) <= 1.0e-7

````
