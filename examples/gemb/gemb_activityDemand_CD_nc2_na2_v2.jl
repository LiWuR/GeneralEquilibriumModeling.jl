# ================================================================
# gemb_activityDemand_CD_nc2_na2_v2.jl
#
# GEMB ActivityDemand example with Cobb--Douglas compensated demand.
#
# Commodities:
#   1. prod
#   2. lab
#
# Agents:
#   1. firm
#   2. laborer
#
# Numeraire:
#   p_prod = 1
#
# This example rewrites gem_CD_explicitConditions_nc2_na2.jl using
# ActivityDemandSpec.
#
# Both agents are represented by compensated demand conditional on one
# activity variable:
#
#     demand = D(activity, prices).
#
# For the firm, activity is production level.
# For the laborer, activity is utility level.
#
# Cobb--Douglas compensated demand is obtained directly from CES_input
# with es = 1, so no separate Cobb--Douglas demand helper is needed.
# ================================================================

using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


# ----------------------------------------------------------------
# 1. Firm
#
# Technology:
#
#     y = prod^0.5 * lab^0.5
#
# Given production activity z and prices p, cost-minimizing input demand
# is obtained from the CES compensated-input function with es = 1:
#
#     x_f(z,p) = CES_input(
#         [0.5, 0.5],
#         z,
#         p;
#         es = 1,
#         alpha = 1,
#     )
#
# Gross output per unit activity is one unit of prod.
#
# Because output_indices is supplied, build_agent interprets the local
# activity variable as production activity.
# ----------------------------------------------------------------

firm = build_agent(
    ActivityDemandSpec(
        (activity, prices) ->
            GEMB.CES_input(
                [0.5, 0.5],
                activity,
                prices;
                es=1.0,
                alpha=1.0,
            );
    );
    output_indices=[1],
    output_coefficients=[1.0],
    demand_indices=[1, 2],
    activity_start=40.0,
    activity_lower_bound=0.0,
    activity_upper_bound=Inf,
    name=:firm,
)


# ----------------------------------------------------------------
# 2. Laborer
#
# Utility function:
#
#     u = prod^0.8 * lab^0.2
#
# Endowment:
#
#     [0, 100]
#
# Given utility level u and prices p, compensated consumption demand is
#
#     x_c(u,p) = CES_input(
#         [0.8, 0.2],
#         u,
#         p;
#         es = 1,
#         alpha = 1,
#     )
#
# Because output_indices is omitted, build_agent interprets the local
# activity variable as consumer utility and automatically pairs it with
# expenditure minus endowment income.
# ----------------------------------------------------------------

laborer = build_agent(
    ActivityDemandSpec(
        (utility, prices) ->
            GEMB.CES_input(
                [0.8, 0.2],
                utility,
                prices;
                es=1.0,
                alpha=1.0,
            );
    );
    demand_indices=[1, 2],
    endowment_indices=[2],
    endowment_quantities=[100.0],
    activity_start=20.0,
    activity_lower_bound=0.0,
    activity_upper_bound=Inf,
    name=:laborer,
)


# ----------------------------------------------------------------
# 3. General-equilibrium model
# ----------------------------------------------------------------

model = NetSupplyEquilibriumModel(
    AbstractNetSupplyAgent[
        firm,
        laborer,
    ],
    [:prod, :lab];
    numeraire_index=1,
    numeraire_value=1.0,
)


# ----------------------------------------------------------------
# 4. Solve
# ----------------------------------------------------------------

result = solve_equilibrium_model_mcp_jump(
    model;
    p0=[1.0, 0.25],
    residual_tol=1.0e-8,
    silent=true,
)


# ----------------------------------------------------------------
# 5. Results
# ----------------------------------------------------------------

firm_activity =
    result.agent_variable_values[1][1]

laborer_utility =
    result.agent_variable_values[2][1]

println("======= GEMB ActivityDemand Cobb--Douglas =======")
println("Solved:          ", result.solved)
println("Prices:          ", result.prices)
println("Firm activity:   ", firm_activity)
println("Laborer utility: ", laborer_utility)
println("Firm net supply: ", result.agent_net_supplies[1])
println("Laborer supply:  ", result.agent_net_supplies[2])
println("Total supply:    ", result.total_net_supply)
println("Max residual:    ", result.max_natural_residual)
println("=================================================")


# ----------------------------------------------------------------
# 6. Analytical-equilibrium checks
#
# With p_prod = 1, the firm's Cobb--Douglas unit cost is
#
#     c(p) = 2 * sqrt(p_prod * p_lab).
#
# The zero-profit condition therefore gives
#
#     2 * sqrt(p_lab) = 1,
#
# and hence
#
#     p_lab = 0.25.
#
# At p = [1, 0.25]:
#
#     firm input demand per unit activity = [0.5, 2.0]
#     laborer demand per unit utility      = [1.0, 1.0]
#
# The laborer's endowment income is
#
#     100 * 0.25 = 25,
#
# while expenditure per unit utility is 1.25. Therefore:
#
#     z_firm = 40
#     u      = 20
#
# Market clearing:
#
#     prod: 40 - 20 - 20 = 0
#     lab:  100 - 80 - 20 = 0
# ----------------------------------------------------------------

@assert result.solved
@assert result.mcp_solved

@assert isapprox(
    result.prices,
    [1.0, 0.25];
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert isapprox(
    firm_activity,
    40.0;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert isapprox(
    laborer_utility,
    20.0;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert isapprox(
    result.agent_net_supplies[1],
    [20.0, -80.0];
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert isapprox(
    result.agent_net_supplies[2],
    [-20.0, 80.0];
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert maximum(abs, result.total_net_supply) <= 1.0e-7
@assert result.max_natural_residual <= 1.0e-8
