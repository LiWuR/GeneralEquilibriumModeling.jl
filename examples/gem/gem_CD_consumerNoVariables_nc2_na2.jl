# ================================================================
# gem_CD_consumerNoVariables_nc2_na2.jl
#
# Two-commodity, two-agent Cobb-Douglas general equilibrium.
#
# The producer has one activity variable.
# The consumer has no agent variables. Consumer demand is computed
# directly from prices and endowment income.
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
# Cobb-Douglas unit demand coefficients
#
#     f(x) = alpha * prod(x .^ beta)
#
# CD_A gives the cost-minimizing input coefficients required for
# one unit of output or utility.
# ----------------------------------------------------------------

function CD_A(alpha, beta, p)
    unit_cost = prod((p ./ beta) .^ beta) / alpha

    return beta .* unit_cost ./ p
end


# ----------------------------------------------------------------
# 1. Firm
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
# 2. Laborer
#
# Preferences:
#
#     u = prod^0.8 * lab^0.2
#
# Endowment:
#
#     omega = [0, 100]
#
# The laborer has no agent variables.
#
# Income is determined directly from prices:
#
#     income = p' * omega
#
# Cobb-Douglas Marshallian demand is then
#
#     x_i = beta_i * income / p_i
# ----------------------------------------------------------------

function laborer_net_supply(z, p)
    beta = [0.8, 0.2]
    endowment = [0.0, 100.0]

    income = sum(p .* endowment)

    demand = beta .* income ./ p

    return endowment .- demand
end


laborer = ConsumerAgent(
    [1, 2],
    laborer_net_supply;
    name = :laborer,
)


# ----------------------------------------------------------------
# 3. Equilibrium model
# ----------------------------------------------------------------

model = EquilibriumModel(
    [firm, laborer],
    [:prod, :lab];
    numeraire_index = 1,
    numeraire_value = 1.0,
)


# ----------------------------------------------------------------
# 4. Solve
# ----------------------------------------------------------------

result = solve_equilibrium_model_mcp_jump(
    model;
    p0 = [1.0, 0.25],
    residual_tol = 1.0e-8,
    silent = true,
)


# ----------------------------------------------------------------
# 5. Results
# ----------------------------------------------------------------

print_equilibrium_model_result(result)

println()
println("Prices:        ", result.prices)
println("Firm activity: ", result.agent_variable_values[1][1])
println("Net supplies:  ", result.agent_net_supplies)
println("Total supply:  ", result.total_net_supply)