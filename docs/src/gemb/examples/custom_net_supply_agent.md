# Custom net-supply agent

This example demonstrates how a standard high-level GEMB agent and a custom
net-supply agent can be used in the same `GEMBModel`.

The producer is constructed from `ProductionFunctionSpec` with stationary
production conditions. The consumer is constructed with
`add_net_supply_agent!` and `ExplicitAgentConditions`.

```julia
# GEMB high-level framework:
# firm uses ProductionStationarityConditions;
# consumer uses ExplicitAgentConditions.
using GeneralEquilibriumModeling

alpha = 2.0
omega = 100.0
beta = [0.5, 0.5]

# Cobb-Douglas production:
# y = alpha * sqrt(x_product * x_labor)
production_function = x -> alpha * sqrt(x[1] * x[2])

marginal_product_function = x -> [
    0.5 * alpha * sqrt(x[2] / x[1]),
    0.5 * alpha * sqrt(x[1] / x[2]),
]

model = GEMB.GEMBModel(
    [:product, :labor];
    numeraire=:product,
    numeraire_value=1.0,
)

# Firm: ProductionFunctionSpec with behavior=:stationary constructs
# ProductionStationarityConditions.
GEMB.add_agent!(
    model,
    GEMB.ProductionFunctionSpec(
        production_function,
        marginal_product_function;
        behavior=:stationary,
    );
    outputs=:product,
    demands=[:product, :labor],
    activity_start=100.0,
    demand_start=[100.0, 100.0],
    demand_lower_bounds=[1.0e-10, 1.0e-10],
    production_multiplier_start=1.0,
    name=:firm,
)

# Consumer variables are
# [product consumption, labor consumption, budget multiplier].
consumer_net_supply = function (
    local_variables,
    local_prices,
    observed_values=Any[],
)
    x_product = local_variables[1]
    x_labor = local_variables[2]

    return [
        -x_product,
        omega - x_labor,
    ]
end

# Cobb-Douglas first-order conditions and budget balance.
consumer_conditions = function (
    local_variables,
    local_prices,
    net_supply,
)
    x_product = local_variables[1]
    x_labor = local_variables[2]
    mu = local_variables[3]

    p_product = local_prices[1]
    p_labor = local_prices[2]
    income = omega * p_labor

    return [
        mu * p_product - beta[1] / x_product,
        mu * p_labor - beta[2] / x_labor,
        income - p_product * x_product - p_labor * x_labor,
    ]
end

# Custom high-level consumer:
# commodity names are resolved by GEMB and registration is automatic.
GEMB.add_net_supply_agent!(
    model,
    consumer_net_supply;
    commodities=[:product, :labor],
    variable_names=[:demand_product, :demand_labor, :budget_multiplier],
    variable_lower_bounds=[1.0e-10, 1.0e-10, 0.0],
    variable_upper_bounds=[Inf, Inf, Inf],
    variable_start=[100.0, 100.0, 0.01],
    condition_rule=GEM.ExplicitAgentConditions(consumer_conditions),
    name=:consumer,
)

result = GEMB.solve(
    model;
    p0=[1.0, 2.0],
    residual_tol=1.0e-8,
    silent=true,
)

prices = result.prices

firm_variables = result.agent_variable_values[1]
output = firm_variables[1]
firm_inputs = firm_variables[2:3]
production_multiplier = firm_variables[4]

consumer_variables = result.agent_variable_values[2]
consumption = consumer_variables[1:2]
budget_multiplier = consumer_variables[3]
utility = sqrt(prod(consumption))

println("GEMB high level: prices = ", prices,
        ", output = ", output,
        ", firm inputs = ", firm_inputs,
        ", production multiplier = ", production_multiplier,
        ", consumption = ", consumption,
        ", budget multiplier = ", budget_multiplier,
        ", utility = ", utility)

@assert GEM.agent_condition_rule(model.agents[1]) isa GEM.ProductionStationarityConditions
@assert GEM.agent_condition_rule(model.agents[2]) isa GEM.ExplicitAgentConditions

@assert result.solved
@assert isapprox(prices, [1.0, 1.0]; atol=1.0e-7)
@assert isapprox(output, 100.0; atol=1.0e-6)
@assert isapprox(firm_inputs, [50.0, 50.0]; atol=1.0e-6)
@assert isapprox(production_multiplier, 1.0; atol=1.0e-7)
@assert isapprox(consumption, [50.0, 50.0]; atol=1.0e-6)
@assert isapprox(budget_multiplier, 0.01; atol=1.0e-7)
@assert isapprox(utility, 50.0; atol=1.0e-7)
@assert isapprox(result.agent_net_supplies[1], [50.0, -50.0]; atol=1.0e-6)
@assert isapprox(result.agent_net_supplies[2], [-50.0, 50.0]; atol=1.0e-6)
@assert maximum(abs, result.agent_conditions[1]) <= 1.0e-7
@assert maximum(abs, result.agent_conditions[2]) <= 1.0e-7
@assert maximum(abs, result.total_net_supply) <= 1.0e-7

```
