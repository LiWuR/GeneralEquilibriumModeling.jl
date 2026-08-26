# gem_pollution_negativePrice_nc3_na2

Source file: `examples/gem_pollution_negativePrice_nc3_na2.jl`

````julia
# ================================================================
# gem_pollution_negativePrice_nc3_na2.jl
#
# General equilibrium with pollution as a bad commodity.
#
# Commodities:
#   1. product
#   2. labor
#   3. pollution
#
# Agents:
#   1. polluting firm
#   2. consumer
#
# Firm:
#
#   One unit of activity produces one unit of product,
#   uses one unit of labor, and generates one unit of pollution.
#
# Consumer:
#
#   Labor endowment = 6
#
#   Utility:
#
#       U(x, l, q) = log(x) + log(l) - delta * q
#
#   where q is the amount of pollution accepted by the consumer.
#
# Because
#
#       MU_pollution = -delta < 0,
#
# pollution is a bad. Its equilibrium price is therefore allowed
# to be negative: accepting pollution compensates the consumer.
#
# Numeraire:
#
#   p_labor = 1
#
# Expected equilibrium for delta = 0.25:
#
#   prices = [2, 1, -1]
#   firm activity = 2
#   consumer demand = [2, 4, 2]
# ================================================================

using GeneralEquilibriumModeling.GEM


# ----------------------------------------------------------------
# Parameters
# ----------------------------------------------------------------

labor_endowment = 6.0
pollution_disutility = 0.25


# ----------------------------------------------------------------
# 1. Polluting firm
#
# Net supply per unit of activity:
#
#     +1 product
#     -1 labor
#     +1 pollution
#
# The standard ProducerAgent zero-profit condition is used.
# ----------------------------------------------------------------

function firm_net_supply(z, p)
    activity = z[1]

    return [
        activity,
        -activity,
        activity,
    ]
end


firm = ProducerAgent(
    [1, 2, 3],
    firm_net_supply;
    variable_names = [:activity],
    variable_start = [2.0],
    name = :firm,
)


# ----------------------------------------------------------------
# 2. Consumer
#
# Consumer variables:
#
#     v[1] = product demand
#     v[2] = labor demand
#     v[3] = pollution demand
#     v[4] = budget multiplier
#
# Net supply equals endowment minus demand.
# ----------------------------------------------------------------

function consumer_net_supply(v, p)
    product_demand = v[1]
    labor_demand = v[2]
    pollution_demand = v[3]

    return [
        -product_demand,
        labor_endowment - labor_demand,
        -pollution_demand,
    ]
end


# ----------------------------------------------------------------
# Marginal utilities:
#
#     MU_product   = 1 / x
#     MU_labor     = 1 / l
#     MU_pollution = -delta
#
# The negative marginal utility of pollution makes pollution a bad.
# ----------------------------------------------------------------

function consumer_marginal_utility(demand)
    product_demand = demand[1]
    labor_demand = demand[2]

    return [
        1.0 / product_demand,
        1.0 / labor_demand,
        -pollution_disutility,
    ]
end


consumer_conditions = MarginalUtilityConsumerConditions(
    consumer_marginal_utility,
    [1, 2, 3],   # demand-variable positions
    [1, 2, 3],   # corresponding price positions
    4,           # budget-multiplier position
)


consumer = NetSupplyAgent(
    [1, 2, 3],
    consumer_net_supply;
    variable_names = [
        :product_demand,
        :labor_demand,
        :pollution_demand,
        :budget_multiplier,
    ],
    variable_lower_bounds = [
        1.0e-8,
        1.0e-8,
        0.0,
        0.0,
    ],
    variable_upper_bounds = [
        Inf,
        Inf,
        Inf,
        Inf,
    ],
    variable_start = [
        2.0,
        4.0,
        2.0,
        0.25,
    ],
    condition_rule = consumer_conditions,
    name = :consumer,
)


# ----------------------------------------------------------------
# 3. Equilibrium model
#
# Pollution has a free price:
#
#     -Inf < p_pollution < Inf
#
# This allows the equilibrium pollution price to become negative.
# ----------------------------------------------------------------

model = EquilibriumModel(
    [firm, consumer],
    [:product, :labor, :pollution];
    numeraire_index = 2,
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
    p0 = [2.0, 1.0, -1.0],
    residual_tol = 1.0e-8,
    silent = true,
)


# ----------------------------------------------------------------
# 5. Results
# ----------------------------------------------------------------

print_equilibrium_model_result(result)

println()
println("Prices:           ", result.prices)
println("Firm activity:    ", result.agent_variable_values[1][1])
println("Consumer variables: ", result.agent_variable_values[2])
println("Agent net supplies: ", result.agent_net_supplies)
println("Total net supply:   ", result.total_net_supply)
````
