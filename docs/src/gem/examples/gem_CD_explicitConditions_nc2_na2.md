# gem_CD_explicitConditions_nc2_na2

Source file: `examples/gem_CD_explicitConditions_nc2_na2.jl`

````julia
# ================================================================
# gem_cobb_douglas_nc2_na2.jl
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
# Cobb-Douglas demand coefficients
#
# f(x) = alpha * prod(x .^ beta)
#
# CD_A returns the cost-minimizing input coefficients required for
# one unit of activity.
# ----------------------------------------------------------------

function CD_A(alpha, beta, p)
    unit_cost =
        prod((p ./ beta) .^ beta) / alpha

    return beta .* unit_cost ./ p
end


# ----------------------------------------------------------------
# 1. Firm
#
# Production function:
#
#     y = prod^0.5 * lab^0.5
#
# Gross output per unit activity:
#
#     B_f = [1, 0]
#
# Input coefficients depend on prices.
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
# Utility function:
#
#     u = prod^0.8 * lab^0.2
#
# Endowment:
#
#     [0, 100]
#
# For a given utility/activity level z_c, CD_A gives the commodity
# bundle required per unit of utility.
# ----------------------------------------------------------------

function laborer_net_supply(z, p)
    utility = z[1]

    a = CD_A(
        1.0,
        [0.8, 0.2],
        p,
    )

    endowment = [0.0, 100.0]

    return endowment .- utility .* a
end


# The laborer's utility level is paired with the budget surplus:
#
#     p' * net_supply >= 0  ⟂  utility >= 0
#
# Since equilibrium utility is positive, the budget constraint binds.

laborer_conditions = ExplicitAgentConditions(
    (z, p, net_supply) -> [
        sum(p .* net_supply)
    ],
)


laborer = NetSupplyAgent(
    [1, 2],
    laborer_net_supply;
    variable_names = [:utility],
    variable_lower_bounds = [0.0],
    variable_upper_bounds = [Inf],
    variable_start = [20.0],
    condition_rule = laborer_conditions,
    name = :laborer,
)


# ----------------------------------------------------------------
# 3. General equilibrium model
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
println("Prices:          ", result.prices)
println("Firm activity:   ", result.agent_variable_values[1][1])
println("Laborer utility: ", result.agent_variable_values[2][1])
println("Net supplies:    ", result.agent_net_supplies)
println("Total supply:    ", result.total_net_supply)
````
