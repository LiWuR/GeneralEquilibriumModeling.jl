# gemb_conditionRule_unitProfit_nc2_na2_v2

Source file: `examples/gemb_conditionRule_unitProfit_nc2_na2_v2.jl`

````julia
# ================================================================
# gemb_conditionRule_unitProfit_nc2_na2_v2.jl
#
# Standard GEMB example for UnitProfitConditions, including a
# research override to TotalProfitConditions.
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
# Hence the firm's net supply is linear and homogeneous in activity:
#
#     s(z,p) = z * [1, -1].
#
# GEMB therefore selects UnitProfitConditions by default.
#
# This example then rebuilds the same producer with
#
#     condition_rule=TotalProfitConditions()
#
# to show that researchers may override the GEMB default.
#
# At a positive-activity equilibrium, the two formulations imply the
# same zero-profit equality. At the corner z = 0, however, their
# complementarity mappings differ.
#
# Positive-activity equilibrium:
#
#     p_product = 1
#     p_labor   = 1
#     z         = 5
#     utility   = 5
# ================================================================

using GEM
using GEMB


# ----------------------------------------------------------------
# 1. Household
#
# The household owns 5 units of labor and consumes only product.
# Its activity variable is utility.
# ----------------------------------------------------------------

household = build_agent(
    CESSpec([1.0]);
    demand_indices=[1],
    endowment_indices=[2],
    endowment_quantities=[5.0],
    activity_start=5.0,
    name=:household,
)


# ================================================================
# Part A. GEMB default: UnitProfitConditions
# ================================================================

# ----------------------------------------------------------------
# 2. Producer with the default condition rule
#
# CESSpec([1.0]) with one labor input gives
#
#     x_labor(z,p) = z.
#
# The producer has no fixed endowment, so GEMB defaults to
#
#     UnitProfitConditions().
#
# For one activity variable, the unit-profit residual is
#
#     F_U(p)
#       = -p' * s(1,p)
#       = -(p_product - p_labor)
#       = p_labor - p_product.
#
# The complementarity condition is
#
#     0 <= F_U(p)  _|_  z >= 0.
# ----------------------------------------------------------------

firm_unit = build_agent(
    CESSpec([1.0]);
    output_indices=[1],
    demand_indices=[2],
    activity_start=5.0,
    name=:firm_unit,
)

@assert agent_condition_rule(firm_unit) isa UnitProfitConditions


# ----------------------------------------------------------------
# 3. Solve the UnitProfitConditions model
#
# Product is the numeraire:
#
#     p_product = 1.
# ----------------------------------------------------------------

model_unit = EquilibriumModel(
    [firm_unit, household],
    [:product, :labor],
)

result_unit = solve_equilibrium_model_mcp_jump(
    model_unit;
    p0=[1.0, 1.0],
    residual_tol=1.0e-8,
    silent=true,
)

unit_activity = result_unit.agent_variable_values[1][1]
unit_utility = result_unit.agent_variable_values[2][1]

println("========== Default UnitProfitConditions ==========")
println("Solved:               ", result_unit.solved)
println("Prices:               ", result_unit.prices)
println("Firm activity:        ", unit_activity)
println("Household utility:    ", unit_utility)
println("Firm condition rule:  ", typeof(agent_condition_rule(firm_unit)))
println("Total net supply:     ", result_unit.total_net_supply)
println("Max natural residual: ", result_unit.max_natural_residual)
println("==================================================")

@assert result_unit.solved
@assert isapprox(
    result_unit.prices,
    [1.0, 1.0];
    atol=1.0e-7,
    rtol=1.0e-7,
)
@assert isapprox(
    unit_activity,
    5.0;
    atol=1.0e-7,
    rtol=1.0e-7,
)
@assert isapprox(
    unit_utility,
    5.0;
    atol=1.0e-7,
    rtol=1.0e-7,
)
@assert maximum(abs, result_unit.total_net_supply) <= 1.0e-7


# ================================================================
# Part B. Research override: TotalProfitConditions
# ================================================================

# ----------------------------------------------------------------
# 4. Rebuild the same producer with an explicit rule override
#
# Although GEMB would normally select UnitProfitConditions for this
# CES producer, the user may override the default:
#
#     condition_rule=TotalProfitConditions()
#
# For one activity variable, the total-profit residual is
#
#     F_T(z,p)
#       = -p' * s(z,p)
#       = -z * (p_product - p_labor)
#       = z * (p_labor - p_product).
#
# The complementarity condition is
#
#     0 <= F_T(z,p)  _|_  z >= 0.
# ----------------------------------------------------------------

firm_total = build_agent(
    CESSpec([1.0]);
    output_indices=[1],
    demand_indices=[2],
    activity_start=5.0,
    condition_rule=TotalProfitConditions(),
    name=:firm_total,
)

@assert agent_condition_rule(firm_total) isa TotalProfitConditions


# ----------------------------------------------------------------
# 5. Solve the TotalProfitConditions model
# ----------------------------------------------------------------

model_total = EquilibriumModel(
    [firm_total, household],
    [:product, :labor],
)

result_total = solve_equilibrium_model_mcp_jump(
    model_total;
    p0=[1.0, 1.0],
    residual_tol=1.0e-8,
    silent=true,
)

total_activity = result_total.agent_variable_values[1][1]
total_utility = result_total.agent_variable_values[2][1]

println()
println("========== Override TotalProfitConditions ==========")
println("Solved:               ", result_total.solved)
println("Prices:               ", result_total.prices)
println("Firm activity:        ", total_activity)
println("Household utility:    ", total_utility)
println("Firm condition rule:  ", typeof(agent_condition_rule(firm_total)))
println("Total net supply:     ", result_total.total_net_supply)
println("Max natural residual: ", result_total.max_natural_residual)
println("====================================================")

@assert result_total.solved
@assert isapprox(
    result_total.prices,
    [1.0, 1.0];
    atol=1.0e-7,
    rtol=1.0e-7,
)
@assert isapprox(
    total_activity,
    5.0;
    atol=1.0e-7,
    rtol=1.0e-7,
)
@assert isapprox(
    total_utility,
    5.0;
    atol=1.0e-7,
    rtol=1.0e-7,
)
@assert maximum(abs, result_total.total_net_supply) <= 1.0e-7


# ================================================================
# Part C. Why Unit and Total are not the same at z = 0
# ================================================================

# ----------------------------------------------------------------
# 6. Compare the two residuals at a hypothetical corner
#
# Take:
#
#     p_product = 1.0
#     p_labor   = 0.8.
#
# At one unit of activity:
#
#     profit = 1.0 - 0.8 = 0.2,
#
# so the UnitProfitConditions residual is
#
#     F_U = -0.2.
#
# This violates the required nonnegativity of the residual at z = 0,
# so UnitProfitConditions does not permit shutdown when a profitable
# unit activity is available.
#
# Under TotalProfitConditions, however,
#
#     s(0,p) = [0, 0],
#
# and therefore
#
#     F_T(0,p) = 0
#
# regardless of the positive unit profit. Thus z = 0 does not by itself
# impose the unit-profit inequality.
#
# This corner difference is why UnitProfitConditions is the natural
# default for a linear and homogeneous constant-returns activity, while
# GEMB still allows researchers to override that default.
# ----------------------------------------------------------------

corner_prices = [1.0, 0.8]

unit_supply_at_one = agent_net_supply(
    firm_unit,
    [1.0],
    corner_prices,
)

total_supply_at_zero = agent_net_supply(
    firm_total,
    [0.0],
    corner_prices,
)

unit_residual_at_corner =
    -sum(corner_prices .* unit_supply_at_one)

total_residual_at_corner =
    -sum(corner_prices .* total_supply_at_zero)

println()
println("========== Corner comparison ==========")
println("Hypothetical prices:              ", corner_prices)
println("Unit residual at z = 0:           ", unit_residual_at_corner)
println("Total residual evaluated at z=0:  ", total_residual_at_corner)
println("=======================================")

@assert isapprox(
    unit_residual_at_corner,
    -0.2;
    atol=1.0e-12,
    rtol=0.0,
)

@assert isapprox(
    total_residual_at_corner,
    0.0;
    atol=1.0e-12,
    rtol=0.0,
)


# ----------------------------------------------------------------
# 7. Final comparison
#
# At the positive-activity equilibrium:
#
#     z > 0
#
# both formulations imply
#
#     p_product = p_labor,
#
# so they produce the same equilibrium in this example.
#
# Their difference appears at the shutdown corner z = 0.
# ----------------------------------------------------------------

println()
println("Positive-activity equilibria are identical:")
println("  Unit prices:    ", result_unit.prices)
println("  Total prices:   ", result_total.prices)
println("  Unit activity:  ", unit_activity)
println("  Total activity: ", total_activity)

````
