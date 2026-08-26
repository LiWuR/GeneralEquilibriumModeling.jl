# ================================================================
# Von Neumann equilibrium with one firm and multiple activities
#
# 2 commodities, 1 firm, 2 production activities.
# The firm has two complementary activity variables z1 and z2.
#
# Analytic equilibrium:
#   rho = 1.2
#   p   = [1.0, 1.0]
#   z   = [0.5, 0.5]
#
# Normalizations:
#   p[2] = 1
#   z1 + z2 = 1
# ================================================================

using GeneralEquilibriumModeling.GEM

# ----------------------------------------------------------------
# 1. Technology matrices
#
# Columns correspond to production activities.
# A[:, j]: unit input vector of activity j
# B[:, j]: unit joint-output vector of activity j
# ----------------------------------------------------------------

A = [
    1.40  0.40
    0.28  1.64
]

B = [
    1.00  0.50
    0.40  1.20
]

# ----------------------------------------------------------------
# 2. Endogenous von Neumann expansion factor
# ----------------------------------------------------------------

rho = GEM.AuxiliaryVariable(
    :rho;
    start = 1.1,
    lower_bound = 0.0,
    upper_bound = Inf,
)

# ----------------------------------------------------------------
# 3. One firm with two activity levels
#
# z = [z1, z2]
#
# Aggregate net supply of the firm:
#
#     s_f = (rho * B - A) * z
#
# Each column of (rho * B - A) is the unit net-supply vector of
# the corresponding activity.
#
# Because and no explicit condition_rule
# is supplied, GEM constructs one automatic profit condition for each
# activity variable.
# ----------------------------------------------------------------

firm = GEM.ProducerAgent(
    [1, 2],
    function (variables, prices, observed_values)
        z = variables
        rho_value = observed_values[1]

        return (rho_value * B - A) * z
    end;
    variable_names = [:activity1, :activity2],
    variable_lower_bounds = [0.0, 0.0],
    variable_upper_bounds = [Inf, Inf],
    variable_start = [1, 1],
    observed_variables = [
        GEM.AuxiliaryVariableRef(:rho),
    ],
    name = :firm,
)

# ----------------------------------------------------------------
# 4. Activity-scale normalization
#
# The activity vector is homogeneous in the von Neumann model, so use
#
#     z1 + z2 = 1
#
# as the scale normalization. The equation is paired with rho.
# ----------------------------------------------------------------

activity_normalization = GEM.AuxiliaryEquation(
    :activity_normalization,
    :rho,
    values -> values[1] + values[2] - 1.0;
    observed_variables = [
        GEM.AgentVariableRef(:firm, :activity1),
        GEM.AgentVariableRef(:firm, :activity2),
    ],
)

# ----------------------------------------------------------------
# 5. Equilibrium model
#
# Commodity 2 is the numeraire:
#
#     p2 = 1
# ----------------------------------------------------------------

model = GEM.NetSupplyEquilibriumModel(
    [firm],
    [:commodity1, :commodity2];
    auxiliary_variables = [rho],
    auxiliary_equations = [activity_normalization],
    numeraire_index = 2,
    numeraire_value = 1.0,
    price_lower_bounds = [0.0, 0.0],
    price_upper_bounds = [Inf, Inf],
)

# ----------------------------------------------------------------
# 6. Solve
# ----------------------------------------------------------------

result = GEM.solve_equilibrium_model_mcp_jump(
    model;
    p0 = [0.9, 1.0],
    auxiliary0 = [1.1],
    residual_tol = 1.0e-8,
    silent = true,
)

# ----------------------------------------------------------------
# 7. Extract solution
# ----------------------------------------------------------------

p = result.prices
z = result.agent_variable_values[1]
rho_star = result.auxiliary_values[:rho]

# ----------------------------------------------------------------
# 8. Direct verification of the von Neumann conditions
# ----------------------------------------------------------------

unit_losses = A' * p - rho_star * (B' * p)
market_surplus = (rho_star * B - A) * z

println()
println("========== Von Neumann equilibrium ==========")
println("Solved: ", result.solved)
println("rho: ", rho_star)
println("Prices: ", p)
println("Activities: ", z)
println("Unit losses: ", unit_losses)
println("Market surplus: ", market_surplus)
println(
    "Activity normalization residual: ",
    result.auxiliary_equation_values[:activity_normalization],
)
println("Total GEM net supply: ", result.total_net_supply)
println("Max natural residual: ", result.max_natural_residual)
println("Max market residual: ", result.max_market_residual)
println("=============================================")

# ----------------------------------------------------------------
# 9. Analytic-solution checks
# ----------------------------------------------------------------

@assert result.solved

@assert isapprox(
    rho_star,
    1.2;
    atol = 1.0e-7,
    rtol = 1.0e-7,
)

@assert isapprox(
    p,
    [1.0, 1.0];
    atol = 1.0e-7,
    rtol = 1.0e-7,
)

@assert isapprox(
    z,
    [0.5, 0.5];
    atol = 1.0e-7,
    rtol = 1.0e-7,
)

@assert maximum(abs, unit_losses) <= 1.0e-7
@assert maximum(abs, market_surplus) <= 1.0e-7
