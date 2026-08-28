# gem_CD_costMinKKT_nc2_na2

Source file: `examples/gem_CD_costMinKKT_nc2_na2.jl`

````julia
# ================================================================
# gem_CD_costMinKKT_nc2_na2.jl
#
# Two-commodity, two-agent Cobb-Douglas general equilibrium.
#
# The producer uses cost-minimization KKT conditions.
# The consumer has no agent variables and uses analytical
# Marshallian demand.
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
# 1. Firm production technology
#
#     y = prod^0.5 * lab^0.5
#
# The firm's local variables are ordered as
#
#     [activity, input_prod, input_lab, production_multiplier]
# ----------------------------------------------------------------

function firm_production(x)
    prod_input = x[1]
    lab_input  = x[2]

    return sqrt(prod_input * lab_input)
end


# A scaled marginal-product function is used here.
#
# The exact marginal products are multiplied by the common positive factor
# 2 * sqrt(prod_input * lab_input), giving the simpler expressions below.
# This does not change the stationary solution because the production
# multiplier adjusts inversely to the common scaling.

function firm_marginal_product(x)
    prod_input = x[1]
    lab_input  = x[2]

    return [
        lab_input,
        prod_input,
    ]
end


# ----------------------------------------------------------------
# Production net supply
#
# Output:
#   commodity 1 (:prod), coefficient = 1
#
# Inputs:
#   commodity 1 (:prod)
#   commodity 2 (:lab)
#
# Hence
#
#   net_supply_prod = activity - input_prod
#   net_supply_lab  = -input_lab
#
# Notice that :prod is both an output and an input.
# ----------------------------------------------------------------

firm_net_supply = ProductionNetSupply(
    [1],          # output commodity
    [1.0],        # output coefficient
    [1, 2],       # input commodities
)


# ----------------------------------------------------------------
# Cost-minimization KKT conditions
#
# The input price positions are obtained from firm_net_supply.
#
# Conditions are paired with:
#
#   activity               <-> total loss
#   input_prod             <-> p_prod - lambda * MP_prod
#   input_lab              <-> p_lab  - lambda * MP_lab
#   production_multiplier  <-> production - activity
# ----------------------------------------------------------------

# Either condition rule can be used for this producer.
#
# `CostMinimizationKKTConditions` represents cost-minimization KKT
# conditions, while `ProductionStationarityConditions` represents the
# stationary marginal-pricing conditions p_i = lambda * MP_i.
# Both give the same equilibrium in this Cobb-Douglas example.

firm_conditions = CostMinimizationKKTConditions(
# firm_conditions = ProductionStationarityConditions(
    firm_production,
    firm_marginal_product,
    firm_net_supply.input_positions,
)


firm = ProducerAgent(
    firm_net_supply.local_indices,
    firm_net_supply;
    variable_names = [
        :activity,
        :input_prod,
        :input_lab,
        :production_multiplier,
    ],
    variable_lower_bounds = [
        0.0,
        0.0,
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
        40.0,
        20.0,
        80.0,
        1.0,
    ],
    condition_rule = firm_conditions,
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
# The consumer has no agent variables.
# Marshallian demand is computed directly from prices.
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
println("Prices:             ", result.prices)
println("Firm variables:     ", result.agent_variable_values[1])
println("Consumer variables: ", result.agent_variable_values[2])
println("Agent net supplies: ", result.agent_net_supplies)
println("Total net supply:   ", result.total_net_supply)
````
