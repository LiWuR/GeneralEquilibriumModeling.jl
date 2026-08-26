# ================================================================
# gem_CD_adValoremClaim_consumerNoVariables_nc3_na2.jl
#
# Commodities:
#   1. prod
#   2. lab
#   3. claim
#
# Agents:
#   1. firm
#   2. consumer
#
# Firm technology:
#
#     y = prod^0.5 * lab^0.5
#
# Consumer preferences:
#
#     u = prod^0.8 * lab^0.2
#
# Consumer endowment:
#
#     100 units of labor
#     1 unit of claim
#
# Ad valorem tax:
#
#     p_claim * claim_demand = tau * base_cost
#
# where tau = 1.5.
#
# Numeraire:
#
#     p_prod = 1
#
# Expected equilibrium:
#
#     prices       = [1.0, 0.04, 6.0]
#     firm activity = 10.0
# ================================================================

using GeneralEquilibriumModeling.GEM


# ----------------------------------------------------------------
# Parameters
# ----------------------------------------------------------------

tau = 1.5  # Use -1/6 for the subsidy case; choose a positive initial claim price for tau > 0 and a negative initial claim price for tau < 0.

beta_firm = [0.5, 0.5]
beta_consumer = [0.8, 0.2]


# ----------------------------------------------------------------
# Cobb-Douglas unit demand coefficients
# ----------------------------------------------------------------

function CD_A(alpha, beta, p)
    unit_cost = prod((p ./ beta) .^ beta) / alpha
    return beta .* unit_cost ./ p
end


# ----------------------------------------------------------------
# 1. Firm
# ----------------------------------------------------------------

function firm_net_supply(z, p)
    activity = z[1]

    p_physical = p[1:2]
    p_claim = p[3]

    a = CD_A(
        1.0,
        beta_firm,
        p_physical,
    )

    input = activity .* a

    base_cost =
        sum(p_physical .* input)

    claim_demand =
        tau * base_cost / p_claim

    return [
        activity - input[1],
        -input[2],
        -claim_demand,
    ]
end


firm = ProducerAgent(
    [1, 2, 3],
    firm_net_supply;
    variable_names = [:activity],
    variable_start = [10.0],
    name = :firm,
)


# ----------------------------------------------------------------
# 2. Consumer
#
# The consumer has no agent variables.
#
# Income:
#
#     income = 100 * p_lab + p_claim
#
# Cobb-Douglas Marshallian demand:
#
#     x_i = beta_i * income / p_i
# ----------------------------------------------------------------

function consumer_net_supply(z, p)
    endowment = [0.0, 100.0, 1.0]

    income =
        sum(p .* endowment)

    demand_prod =
        beta_consumer[1] * income / p[1]

    demand_lab =
        beta_consumer[2] * income / p[2]

    return [
        -demand_prod,
        100.0 - demand_lab,
        1.0,
    ]
end


consumer = ConsumerAgent(
    [1, 2, 3],
    consumer_net_supply;
    name = :consumer,
)


# ----------------------------------------------------------------
# 3. Equilibrium model
# ----------------------------------------------------------------

model = EquilibriumModel(
    [firm, consumer],
    [:prod, :lab, :claim];
    numeraire_index = 1,
    numeraire_value = 1.0,
    price_lower_bounds = [
        0.0,    # prod
        0.0,    # lab
        -Inf,   # claim: free price
    ],
    price_upper_bounds = [
        Inf,
        Inf,
        Inf,
    ],
)


# ----------------------------------------------------------------
# 4. Solve
# ----------------------------------------------------------------

result = solve_equilibrium_model_mcp_jump(
    model;
    p0 = [1.0, 0.04, 6.0],  # For tau > 0; use p0 = [1.0, 0.04, -6.0] for tau < 0.
    residual_tol = 1.0e-8,
    silent = true,
)


# ----------------------------------------------------------------
# 5. Results
# ----------------------------------------------------------------

print_equilibrium_model_result(result)

println()
println("Prices:          ", result.prices)
println("Firm activity:   ", result.agent_variable_values[1][1])
println("Net supplies:    ", result.agent_net_supplies)
println("Total net supply:", result.total_net_supply)