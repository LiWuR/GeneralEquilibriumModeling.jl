# gem_CD_specificSubsidyClaim_consumerNoVariables_nc3_na2

Source file: `examples/gem_CD_specificSubsidyClaim_consumerNoVariables_nc3_na2.jl`

````julia
# ================================================================
# gem_CD_specificSubsidyClaim_consumerNoVariables_nc3_na2.jl
#
# Cobb-Douglas general equilibrium with a specific subsidy claim.
#
# Commodities:
#   1. prod
#   2. lab
#   3. subsidy_claim
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
#      20 units of subsidy claims
#
# Specific subsidy:
#
#     t = -0.2 per unit of firm activity
#
# Claim settlement:
#
#     p_claim * c = t * z
#
# Since t < 0 and c > 0, the equilibrium claim price is negative.
#
# Numeraire:
#
#     p_prod = 1
# ================================================================

using GeneralEquilibriumModeling.GEM


# ----------------------------------------------------------------
# Parameters
# ----------------------------------------------------------------

specific_subsidy_rate = -0.2
labor_endowment = 100.0
claim_supply = 20.0

beta_firm = [0.5, 0.5]
beta_consumer = [0.8, 0.2]


# ----------------------------------------------------------------
# Cobb-Douglas unit input coefficients
# ----------------------------------------------------------------

function CD_A(alpha, beta, p)
    unit_cost = prod((p ./ beta) .^ beta) / alpha
    return beta .* unit_cost ./ p
end


# ----------------------------------------------------------------
# 1. Firm
#
# Agent variables:
#
#     z[1] = activity
#     z[2] = claim quantity
#
# The firm uses prod and lab as physical inputs and purchases subsidy
# claims. The claim settlement condition is written directly as
#
#     p_claim * claim_quantity - t * activity = 0
#
# rather than dividing by p_claim. This is preferable because the
# claim price is a free variable and may be negative or approach zero.
# ----------------------------------------------------------------

function firm_net_supply(z, p)
    activity = z[1]
    claim_quantity = z[2]

    a = CD_A(
        1.0,
        beta_firm,
        p[1:2],
    )

    input = activity .* a

    return [
        activity - input[1],
        -input[2],
        -claim_quantity,
    ]
end


firm_conditions = ExplicitAgentConditions(
    function (z, p, net_supply)
        activity = z[1]
        claim_quantity = z[2]

        a = CD_A(
            1.0,
            beta_firm,
            p[1:2],
        )

        unit_input_cost =
            sum(p[1:2] .* a)

        unit_loss =
            unit_input_cost +
            specific_subsidy_rate -
            p[1]

        settlement_gap =
            p[3] * claim_quantity -
            specific_subsidy_rate * activity

        return [
            unit_loss,
            settlement_gap,
        ]
    end,
)


firm = NetSupplyAgent(
    [1, 2, 3],
    firm_net_supply;
    variable_names = [
        :activity,
        :claim_quantity,
    ],
    variable_lower_bounds = [
        0.0,
        0.0,
    ],
    variable_upper_bounds = [
        Inf,
        Inf,
    ],
    variable_start = [
        50.0,
        20.0,
    ],
    condition_rule = firm_conditions,
    name = :firm,
)


# ----------------------------------------------------------------
# 2. Consumer
#
# The consumer has no agent variables.
#
# Income is the market value of the labor and claim endowments:
#
#     income = 100 * p_lab + 20 * p_claim
#
# Cobb-Douglas Marshallian demands are
#
#     x_prod = 0.8 * income / p_prod
#     x_lab  = 0.2 * income / p_lab
# ----------------------------------------------------------------

function consumer_net_supply(z, p)
    income =
        labor_endowment * p[2] +
        claim_supply * p[3]

    demand_prod =
        beta_consumer[1] * income / p[1]

    demand_lab =
        beta_consumer[2] * income / p[2]

    return [
        -demand_prod,
        labor_endowment - demand_lab,
        claim_supply,
    ]
end


consumer = ConsumerAgent(
    [1, 2, 3],
    consumer_net_supply;
    name = :consumer,
)


# ----------------------------------------------------------------
# 3. Equilibrium model
#
# The subsidy-claim price is a free price because a subsidy requires
# a negative equilibrium claim price.
# ----------------------------------------------------------------

model = EquilibriumModel(
    [firm, consumer],
    [:prod, :lab, :subsidy_claim];
    numeraire_index = 1,
    numeraire_value = 1.0,
    price_lower_bounds = [
        0.0,
        0.0,
        -Inf,
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
    p0 = [
        1.0,
        0.36,
        -0.5,
    ],
    residual_tol = 1.0e-8,
    silent = true,
)


# ----------------------------------------------------------------
# 5. Results
# ----------------------------------------------------------------

print_equilibrium_model_result(result)

println()
println("Prices:              ", result.prices)
println("Firm activity:       ", result.agent_variable_values[1][1])
println("Firm claim quantity: ", result.agent_variable_values[1][2])
println("Agent net supplies:  ", result.agent_net_supplies)
println("Total net supply:    ", result.total_net_supply)
````
