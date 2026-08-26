# gem_CD_externality_observedVariable_consumerNoVariables_nc2_na2

Source file: `examples/gem_CD_externality_observedVariable_consumerNoVariables_nc2_na2.jl`

````julia
# ================================================================
# gem_CD_externality_observedVariable_consumerNoVariables_nc2_na2.jl
#
# Cobb-Douglas general equilibrium with a production externality.
#
# Commodities:
#   1. prod
#   2. lab
#
# Agents:
#   1. firm
#   2. consumer
#
# Firm technology:
#
#     y = prod^0.5 * lab^0.5
#
# Consumer preferences are Cobb-Douglas, but the expenditure share
# on prod depends negatively on the firm's activity:
#
#     beta_prod(z) = 0.8 / (1 + 0.05 * z)
#
# The consumer observes the firm's endogenous activity through
# `AgentVariableRef`.
#
# The consumer has no agent variables. Its Marshallian demand is
# computed directly from prices and the observed firm activity.
#
# Consumer endowment:
#
#     100 units of labor
#
# Numeraire:
#
#     p_prod = 1
#
# Analytic equilibrium:
#
#     p_prod = 1
#     p_lab  = 0.25
#     firm activity = 20
#
#     beta_prod(20) = 0.4
#
# Firm net supply:
#
#     [10, -40]
#
# Consumer net supply:
#
#     [-10, 40]
# ================================================================

using GeneralEquilibriumModeling.GEM


# ----------------------------------------------------------------
# Parameters
# ----------------------------------------------------------------

labor_endowment = 100.0

beta_firm = [0.5, 0.5]


# ----------------------------------------------------------------
# Cobb-Douglas unit demand coefficients
#
#     f(x) = alpha * prod(x .^ beta)
#
# CD_A returns the cost-minimizing physical inputs required for
# one unit of output.
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
# The firm has one endogenous activity variable.
# ----------------------------------------------------------------

function firm_net_supply(z, p)
    activity = z[1]

    a = CD_A(
        1.0,
        beta_firm,
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
    variable_start = [20.0],
    name = :firm,
)


# ----------------------------------------------------------------
# 2. Consumer
#
# The consumer observes the firm's activity level.
#
# The production externality reduces the Cobb-Douglas expenditure
# share on prod:
#
#     beta_prod(z) = 0.8 / (1 + 0.05 * z)
#
# and
#
#     beta_lab(z) = 1 - beta_prod(z).
#
# The chosen functional form keeps both expenditure shares positive
# for every nonnegative firm activity.
#
# The consumer has no endogenous agent variables.
# ----------------------------------------------------------------

function consumer_net_supply(
    local_variables,
    p,
    observed_values,
)
    firm_activity = observed_values[1]

    beta_prod =
        0.8 / (1.0 + 0.05 * firm_activity)

    beta_lab =
        1.0 - beta_prod

    income =
        labor_endowment * p[2]

    demand_prod =
        beta_prod * income / p[1]

    demand_lab =
        beta_lab * income / p[2]

    return [
        -demand_prod,
        labor_endowment - demand_lab,
    ]
end


consumer = ConsumerAgent(
    [1, 2],
    consumer_net_supply;
    observed_variables = [
        AgentVariableRef(:firm, :activity),
    ],
    name = :consumer,
)


# ----------------------------------------------------------------
# 3. Equilibrium model
# ----------------------------------------------------------------

model = EquilibriumModel(
    [firm, consumer],
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
println("Prices:                    ", result.prices)
println("Firm activity:             ", result.agent_variable_values[1][1])
println("Consumer observed activity:", result.observed_variable_values[2][1])
println("Agent net supplies:        ", result.agent_net_supplies)
println("Total net supply:          ", result.total_net_supply)
````
