# gemb_CES_CET_nc4_na2_v2

Source file: `examples/gemb_CES_CET_nc4_na2_v2.jl`

````julia
# ================================================================
# gemb_CES_CET_nc4_na2_v2.jl
#
# GEMB general-equilibrium example with CES input demand and CET
# output supply.
#
# Commodities:
#   1. good_1
#   2. good_2
#   3. labor
#   4. capital
#
# Agents:
#   1. firm
#   2. household
#
# Numeraire:
#   p_labor = 1
#
# Firm input technology:
#   Cobb--Douglas CES with beta = [0.5, 0.5], es = 1, alpha = 2.
#   Its unit cost is
#
#       c(p_labor, p_capital) = sqrt(p_labor * p_capital).
#
# Firm output transformation:
#   CET with beta = [0.5, 0.5], et = 1, alpha = 1.
#   Its unit revenue is
#
#       r(p_1, p_2) = sqrt(0.5 * p_1^2 + 0.5 * p_2^2).
#
#   Conditional output supply satisfies
#
#       y_1 / y_2 = p_1 / p_2.
#
# Household endowment:
#   50 units of labor and 50 units of capital.
#
# Two equilibria are solved:
#
#   A. Symmetric expenditure shares [0.5, 0.5]
#      Expected equilibrium:
#          p = [1, 1, 1, 1]
#          z = 100
#          y = [50, 50]
#
#   B. Good-1-biased expenditure shares [0.8, 0.2]
#      Expected equilibrium:
#          p_1 / p_2 = 2
#          z = 100
#          y_1 / y_2 = 2
#
# This second equilibrium demonstrates the economic role of CET:
# the relative output price changes the firm's output composition.
#
# V2 uses only positional behavior-specification dispatch. The household's
# Marshall demand is explicitly wrapped in MarshallDemandConsumerSpec.
# ================================================================

using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


# ----------------------------------------------------------------
# 1. Model builder
# ----------------------------------------------------------------

function make_ces_cet_model(good_1_share::Real)
    0.0 < good_1_share < 1.0 || throw(ArgumentError(
        "good_1_share must lie strictly between 0 and 1.",
    ))

    input_spec = CESSpec(
        [0.5, 0.5];
        es=1.0,
        alpha=2.0,
    )

    output_spec = CETSpec(
        [0.5, 0.5];
        et=1.0,
        alpha=1.0,
    )

    firm = build_agent(
        input_spec;
        output_indices=[1, 2],
        output_spec=output_spec,
        demand_indices=[3, 4],
        activity_start=100.0,
        name=:firm,
    )

    household_spec =
        MarshallDemandConsumerSpec(
            (income, prices) -> [
                good_1_share * income / prices[1],
                (1.0 - good_1_share) * income / prices[2],
            ],
        )

    household = build_agent(
        household_spec;
        demand_indices=[1, 2],
        endowment_indices=[3, 4],
        endowment_quantities=[50.0, 50.0],
        name=:household,
    )

    model = EquilibriumModel(
        [firm, household],
        [:good_1, :good_2, :labor, :capital];
        numeraire_index=3,
        numeraire_value=1.0,
        price_lower_bounds=[1.0e-8, 1.0e-8, 1.0e-8, 1.0e-8],
        price_upper_bounds=[Inf, Inf, Inf, Inf],
    )

    return (
        model=model,
        firm=firm,
        household=household,
        input_spec=input_spec,
        output_spec=output_spec,
        household_spec=household_spec,
    )
end


# ----------------------------------------------------------------
# 2. Symmetric benchmark
# ----------------------------------------------------------------

symmetric = make_ces_cet_model(0.5)

symmetric_result = solve_equilibrium_model_mcp_jump(
    symmetric.model;
    p0=[1.0, 1.0, 1.0, 1.0],
    residual_tol=1.0e-8,
    silent=true,
)

symmetric_activity = symmetric_result.agent_variable_values[1][1]
symmetric_firm_supply = symmetric_result.agent_net_supplies[1]


# ----------------------------------------------------------------
# 3. Good-1-biased benchmark
# ----------------------------------------------------------------

biased = make_ces_cet_model(0.8)

biased_result = solve_equilibrium_model_mcp_jump(
    biased.model;
    p0=[1.25, 0.65, 1.0, 1.0],
    residual_tol=1.0e-8,
    silent=true,
)

biased_activity = biased_result.agent_variable_values[1][1]
biased_firm_supply = biased_result.agent_net_supplies[1]


# ----------------------------------------------------------------
# 4. Analytical benchmark values for the biased equilibrium
# ----------------------------------------------------------------
#
# Factor-market clearing implies
#
#     p_capital = 1,
#     z = 100.
#
# Household demand and CET supply imply
#
#     (p_1 / p_2)^2 = 0.8 / 0.2 = 4,
#
# hence p_1 / p_2 = 2. Zero profit then requires
#
#     0.5 * p_1^2 + 0.5 * p_2^2 = 1.
#
# Therefore
#
#     p_2 = sqrt(2 / 5),
#     p_1 = 2 * sqrt(2 / 5).
# ----------------------------------------------------------------

expected_biased_p2 = sqrt(2.0 / 5.0)
expected_biased_p1 = 2.0 * expected_biased_p2
expected_biased_prices = [
    expected_biased_p1,
    expected_biased_p2,
    1.0,
    1.0,
]


# ----------------------------------------------------------------
# 5. Results
# ----------------------------------------------------------------

println("============ GEMB CES input + CET output ============")
println("Symmetric equilibrium")
println("  Solved:             ", symmetric_result.solved)
println("  Prices:             ", symmetric_result.prices)
println("  Firm activity:      ", symmetric_activity)
println("  Firm net supply:    ", symmetric_firm_supply)
println("  Total net supply:   ", symmetric_result.total_net_supply)
println()
println("Good-1-biased equilibrium")
println("  Solved:             ", biased_result.solved)
println("  Prices:             ", biased_result.prices)
println("  Firm activity:      ", biased_activity)
println("  Firm net supply:    ", biased_firm_supply)
println("  Total net supply:   ", biased_result.total_net_supply)
println("  p1 / p2:            ", biased_result.prices[1] / biased_result.prices[2])
println("  y1 / y2:            ", biased_firm_supply[1] / biased_firm_supply[2])
println("======================================================")


# ----------------------------------------------------------------
# 6. Analytical checks
# ----------------------------------------------------------------

@assert symmetric_result.solved
@assert isapprox(
    symmetric_result.prices,
    [1.0, 1.0, 1.0, 1.0];
    atol=1.0e-7,
    rtol=1.0e-7,
)
@assert isapprox(symmetric_activity, 100.0; atol=1.0e-7, rtol=1.0e-7)
@assert isapprox(
    symmetric_firm_supply,
    [50.0, 50.0, -50.0, -50.0];
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert biased_result.solved
@assert isapprox(
    biased_result.prices,
    expected_biased_prices;
    atol=1.0e-7,
    rtol=1.0e-7,
)
@assert isapprox(biased_activity, 100.0; atol=1.0e-7, rtol=1.0e-7)
@assert isapprox(
    biased_result.prices[1] / biased_result.prices[2],
    2.0;
    atol=1.0e-7,
    rtol=1.0e-7,
)
@assert isapprox(
    biased_firm_supply[1] / biased_firm_supply[2],
    2.0;
    atol=1.0e-7,
    rtol=1.0e-7,
)

````
