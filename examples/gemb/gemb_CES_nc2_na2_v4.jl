# ================================================================
# gemb_CES_nc2_na2_v4.jl
#
# GEMB example using built-in CESSpec.
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
# This example represents the same economy as
#
#     gem_CD_explicitConditions_nc2_na2.jl
#
# and
#
#     gemb_activityDemand_CD_nc2_na2_v2.jl,
#
# but uses the built-in CESSpec directly.
#
# Since CESSpec defaults to es = 1.0 and alpha = 1.0, both
# specifications below are Cobb--Douglas.
#
# The example intentionally omits optional arguments when their
# default values are appropriate. The relevant defaults are shown
# in comments next to each construction call.
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
# CESSpec defaults:
#
#     es    = 1.0
#     alpha = 1.0
#
# build_agent activity defaults:
#
#     activity_start       = 100.0
#     activity_lower_bound = 0.0
#     activity_upper_bound = Inf
#
# output_coefficients defaults to 1.0 for each output, so it can also
# be omitted here.
#
# Only activity_start is explicitly supplied because 40.0 is a
# convenient starting value for this example.
# ----------------------------------------------------------------

firm = build_agent(
    CESSpec([0.5, 0.5]);
    output_indices=[1],
    demand_indices=[1, 2],
    activity_start=40.0,
    name=:firm,
)


# ----------------------------------------------------------------
# 2. Laborer
#
# Utility:
#
#     u = prod^0.8 * lab^0.2
#
# Endowment:
#
#     [0, 100]
#
# CESSpec again uses its defaults:
#
#     es    = 1.0
#     alpha = 1.0
#
# Consumer activity defaults are the same:
#
#     activity_start       = 100.0
#     activity_lower_bound = 0.0
#     activity_upper_bound = Inf
#
# Only activity_start is overridden here.
# ----------------------------------------------------------------

laborer = build_agent(
    CESSpec([0.8, 0.2]);
    demand_indices=[1, 2],
    endowment_indices=[2],
    endowment_quantities=[100.0],
    activity_start=20.0,
    name=:laborer,
)


# ----------------------------------------------------------------
# 3. General-equilibrium model
#
# EquilibriumModel defaults:
#
#     numeraire_index  = 1
#     numeraire_value  = 1.0
#     price_lower_bounds = zeros(number_of_commodities)
#     price_upper_bounds = fill(Inf, number_of_commodities)
#
# Since the first commodity, prod, is the numeraire in this example
# and its normalized price is 1.0, these optional arguments can all
# be omitted.
#
# EquilibriumModel is the user-facing alias of NetSupplyEquilibriumModel.
# The constructor accepts an ordinary vector of agents and checks internally
# that every element is an AbstractNetSupplyAgent, so no explicit
# AbstractNetSupplyAgent[...] type annotation is needed.
# ----------------------------------------------------------------

model = EquilibriumModel(
    [firm, laborer],
    [:prod, :lab],
)


# ----------------------------------------------------------------
# 4. Solve
#
# Optional solver arguments shown here:
#
#     p0            = initial price vector
#     residual_tol  = equilibrium residual tolerance
#     silent        = suppress solver output
#
# These are supplied explicitly because they are useful for a
# reproducible example.
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

println("============ GEMB CES: 2 commodities, 2 agents ============")
println("Solved:          ", result.solved)
println("Prices:          ", result.prices)
println("Firm activity:   ", firm_activity)
println("Laborer utility: ", laborer_utility)
println("Firm net supply: ", result.agent_net_supplies[1])
println("Laborer supply:  ", result.agent_net_supplies[2])
println("Total supply:    ", result.total_net_supply)
println("Max residual:    ", result.max_natural_residual)
println("============================================================")


# ----------------------------------------------------------------
# 6. Analytical-equilibrium checks
#
# With p_prod = 1, the firm's Cobb--Douglas unit cost is
#
#     c(p) = 2 * sqrt(p_prod * p_lab).
#
# Zero profit implies
#
#     2 * sqrt(p_lab) = 1,
#
# hence
#
#     p_lab = 0.25.
#
# At p = [1, 0.25]:
#
#     firm input demand per unit activity = [0.5, 2.0]
#     laborer demand per unit utility      = [1.0, 1.0]
#
# Hence
#
#     firm activity   = 40
#     laborer utility = 20.
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
