# gem_CD_marginalUtility_nc2_na2

Source file: `examples/gem_CD_marginalUtility_nc2_na2.jl`

````julia
# ================================================================
# gem_CD_marginalUtility_nc2_na2.jl
#
# Two-commodity, two-agent Cobb-Douglas general equilibrium.
#
# The producer is represented by a net-supply function with one
# activity variable.
#
# The consumer is represented by demand variables and marginal
# utility conditions rather than an analytical Marshall demand.
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
# ================================================================

using GeneralEquilibriumModeling.GEM


# ----------------------------------------------------------------
# 1. Cobb-Douglas unit demand coefficients
#
#     f(x) = alpha * prod(x .^ beta)
#
# CD_A gives the cost-minimizing input coefficients required for
# one unit of output.
# ----------------------------------------------------------------

function CD_A(alpha, beta, p)
    unit_cost = prod((p ./ beta) .^ beta) / alpha
    return beta .* unit_cost ./ p
end


# ----------------------------------------------------------------
# 2. Firm
#
# Production:
#
#     y = prod^0.5 * lab^0.5
#
# The firm has one activity variable.
# ----------------------------------------------------------------

function firm_net_supply(z, p)
    activity = z[1]

    a = CD_A(
        1.0,
        [0.5, 0.5],
        p,
    )

    return activity .* (
        [1.0, 0.0] .- a
    )
end


firm = ProducerAgent(
    [1, 2],
    firm_net_supply;
    variable_names = [:activity],
    variable_start = [40.0],
    name = :firm,
)


# ----------------------------------------------------------------
# 3. Laborer
#
# Preferences:
#
#     u(x_prod, x_lab)
#       = x_prod^0.8 * x_lab^0.2
#
# Endowment:
#
#     omega = [0, 100]
#
# Agent variables:
#
#     [x_prod, x_lab, lambda]
#
# where lambda is the multiplier of the budget constraint.
# ----------------------------------------------------------------

function laborer_net_supply(v, p)
    x_prod = v[1]
    x_lab  = v[2]

    return [
        -x_prod,
        100.0 - x_lab,
    ]
end


# ----------------------------------------------------------------
# Cobb-Douglas marginal utility
#
#     u = x_prod^0.8 * x_lab^0.2
#
# Therefore
#
#     MU_prod = 0.8 * x_prod^(-0.2) * x_lab^0.2
#
#     MU_lab  = 0.2 * x_prod^0.8 * x_lab^(-0.8)
# ----------------------------------------------------------------

function laborer_marginal_utility(x)
    x_prod = x[1]
    x_lab  = x[2]

    return [
        0.8 * x_prod^(-0.2) * x_lab^0.2,
        0.2 * x_prod^0.8 * x_lab^(-0.8),
    ]
end


laborer_conditions = MarginalUtilityConsumerConditions(
    laborer_marginal_utility,
    [1, 2],     # demand variable positions
    [1, 2],     # corresponding price positions
    3,          # budget multiplier position
)


laborer = NetSupplyAgent(
    [1, 2],
    laborer_net_supply;
    variable_names = [
        :demand_prod,
        :demand_lab,
        :budget_multiplier,
    ],
    variable_lower_bounds = [
        1.0e-8,
        1.0e-8,
        0.0,
    ],
    variable_upper_bounds = [
        Inf,
        Inf,
        Inf,
    ],
    variable_start = [
        20.0,
        20.0,
        0.8,
    ],
    condition_rule = laborer_conditions,
    name = :laborer,
)


# ----------------------------------------------------------------
# 4. Equilibrium model
# ----------------------------------------------------------------

model = EquilibriumModel(
    [firm, laborer],
    [:prod, :lab];
    numeraire_index = 1,
    numeraire_value = 1.0,
)


# ----------------------------------------------------------------
# 5. Solve
# ----------------------------------------------------------------

result = solve_equilibrium_model_mcp_jump(
    model;
    p0 = [1.0, 0.25],
    residual_tol = 1.0e-8,
    silent = true,
)


# ----------------------------------------------------------------
# 6. Results
# ----------------------------------------------------------------

print_equilibrium_model_result(result)

println()
println("Prices:                  ", result.prices)
println("Firm activity:           ", result.agent_variable_values[1][1])
println("Laborer variables:       ", result.agent_variable_values[2])
println("Agent net supplies:      ", result.agent_net_supplies)
println("Total net supply:        ", result.total_net_supply)
println("Max natural residual:    ", result.max_natural_residual)
````
