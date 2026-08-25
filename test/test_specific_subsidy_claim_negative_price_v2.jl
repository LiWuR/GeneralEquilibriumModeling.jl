# ================================================================
# test_specific_subsidy_claim_negative_price_v2.jl
#
# Minimal general-equilibrium test for a specific subsidy represented
# by a claim commodity whose equilibrium price is a free negative
# variable.
#
# Commodities:
#   1 product
#   2 labor        (numeraire, p_l = 1)
#   3 subsidy_claim
#
# Agents:
#   1. Firm: one unit of labor produces one unit of product.
#      The specific tax/subsidy rate is t = -0.2 per unit of output.
#      The firm purchases c units of subsidy claims. The settlement rule is
#
#          p_c * c = t * z,
#
#      where z is firm activity. Since t < 0, a positive claim quantity c
#      requires a negative equilibrium claim price p_c.
#
#      The firm's zero-profit condition is
#
#          p_l + t - p_x = 0.
#
#   2. Worker: owns 80 units of labor and spends all labor income on product.
#
#   3. Claim issuer: owns 20 units of labor and supplies 20 subsidy claims.
#      At the analytic equilibrium its endowment value is
#
#          20 * p_l + 20 * p_c = 20 - 20 = 0,
#
#      so the labor endowment exactly finances the subsidy liability.
#
# Price bounds:
#   product:       [0, Inf]
#   labor:         [0, Inf], fixed to 1 as numeraire
#   subsidy_claim: (-Inf, Inf), a true free price variable
#
# Analytic equilibrium:
#
#   t      = -0.2
#   z*     = 100
#   c*     = 20
#   p_l*   = 1
#   p_x*   = 1 + t = 0.8
#   p_c*   = t * z* / c* = -1
#
# Markets:
#   product:  firm supplies 100; worker demands 80 / 0.8 = 100
#   labor:    worker + issuer supply 80 + 20 = 100; firm demands 100
#   claim:    issuer supplies 20; firm demands 20
# ================================================================

using Test
using GEMB

#include(joinpath(@__DIR__, "equilibrium_models_v21.jl"))
#using .EquilibriumModelsV21

const SPECIFIC_SUBSIDY_RATE = -0.20
const WORKER_LABOR = 80.0
const ISSUER_LABOR = 20.0
const CLAIM_SUPPLY = 20.0

# ----------------------------------------------------------------
# 1. Firm
# ----------------------------------------------------------------
#
# Local variables:
#   z = activity/output
#   c = subsidy-claim quantity purchased
#
# Net supply:
#   +z product
#   -z labor
#   -c subsidy claims
#
# Structural conditions:
#   1. zero unit loss: p_l + t - p_x = 0 when z > 0
#   2. subsidy settlement: p_c*c - t*z = 0 when c > 0
#
# The second condition avoids dividing by p_c. This is useful because
# p_c is intentionally a free variable and may be negative.
# ----------------------------------------------------------------

firm_net_supply = function (local_variables, local_prices)
    z = local_variables[1]
    c = local_variables[2]

    return [
        z,
        -z,
        -c,
    ]
end

firm_conditions = ExplicitAgentConditions(
    function (local_variables, local_prices, net_supply)
        z = local_variables[1]
        c = local_variables[2]

        p_product = local_prices[1]
        p_labor = local_prices[2]
        p_claim = local_prices[3]

        unit_loss =
            p_labor + SPECIFIC_SUBSIDY_RATE - p_product

        settlement_gap =
            p_claim * c - SPECIFIC_SUBSIDY_RATE * z

        return [
            unit_loss,
            settlement_gap,
        ]
    end,
)

firm = NetSupplyAgent(
    [1, 2, 3],
    firm_net_supply;
    variable_names = [:activity, :claim_quantity],
    variable_lower_bounds = [0.0, 0.0],
    variable_upper_bounds = [Inf, Inf],
    variable_start = [90.0, 18.0],
    condition_rule = firm_conditions,
    name = :firm,
)

# ----------------------------------------------------------------
# 2. Worker
# ----------------------------------------------------------------
#
# The worker owns WORKER_LABOR units of labor and consumes only product.
# Demand is therefore
#
#     x = WORKER_LABOR * p_l / p_x.
# ----------------------------------------------------------------

worker_net_supply = function (local_variables, local_prices)
    p_product = local_prices[1]
    p_labor = local_prices[2]

    income = WORKER_LABOR * p_labor
    product_demand = income / p_product

    return [
        -product_demand,
        WORKER_LABOR,
    ]
end

worker = NetSupplyConsumerAgent(
    [1, 2],
    worker_net_supply;
    name = :worker,
)

# ----------------------------------------------------------------
# 3. Subsidy-claim issuer
# ----------------------------------------------------------------
#
# The issuer supplies both the remaining labor and the fixed quantity of
# subsidy claims. At equilibrium the value of this endowment is zero.
# ----------------------------------------------------------------

issuer_net_supply = function (local_variables, local_prices)
    return [
        ISSUER_LABOR,
        CLAIM_SUPPLY,
    ]
end

issuer = NetSupplyConsumerAgent(
    [2, 3],
    issuer_net_supply;
    name = :claim_issuer,
)

# ----------------------------------------------------------------
# 4. Equilibrium model
# ----------------------------------------------------------------

model = NetSupplyEquilibriumModel(
    AbstractNetSupplyAgent[
        firm,
        worker,
        issuer,
    ],
    [:product, :labor, :subsidy_claim];
    numeraire_index = 2,
    numeraire_value = 1.0,
    price_lower_bounds = [0.0, 0.0, -Inf],
    price_upper_bounds = [Inf, Inf, Inf],
)

# Start the free claim price away from its analytic value. Because the
# settlement condition contains no division by p_claim, the formulation is
# well defined even if an iteration approaches zero.
result = solve_equilibrium_model_mcp_jump(
    model;
    p0 = [1.0, 1.0, -0.5],
    residual_tol = 1.0e-8,
    silent = true,
)

# ----------------------------------------------------------------
# 5. Analytic benchmark
# ----------------------------------------------------------------

expected_activity = WORKER_LABOR + ISSUER_LABOR
expected_claim_quantity = CLAIM_SUPPLY
expected_product_price = 1.0 + SPECIFIC_SUBSIDY_RATE
expected_claim_price =
    SPECIFIC_SUBSIDY_RATE * expected_activity / expected_claim_quantity

firm_activity = result.agent_variable_values[1][1]
firm_claim_quantity = result.agent_variable_values[1][2]
product_price = result.prices[1]
labor_price = result.prices[2]
claim_price = result.prices[3]

firm_condition_values = result.agent_conditions[1]

firm_claim_expenditure = claim_price * firm_claim_quantity
expected_total_subsidy = SPECIFIC_SUBSIDY_RATE * firm_activity
issuer_endowment_value =
    ISSUER_LABOR * labor_price + CLAIM_SUPPLY * claim_price

# ----------------------------------------------------------------
# 6. Tests
# ----------------------------------------------------------------

@testset "Specific subsidy claim with free negative price" begin
    @test result.solved
    @test result.mcp_solved
    @test result.all_markets_clear

    # The claim price must be a true free variable in the MCP.
    @test result.price_lower_bounds[3] == -Inf
    @test result.price_upper_bounds[3] == Inf

    # Negative specific tax rate means a subsidy.
    @test SPECIFIC_SUBSIDY_RATE < 0.0

    # Analytic equilibrium prices.
    @test isapprox(
        product_price,
        expected_product_price;
        atol = 1.0e-8,
        rtol = 1.0e-8,
    )
    @test isapprox(labor_price, 1.0; atol = 1.0e-10, rtol = 0.0)
    @test claim_price < 0.0
    @test isapprox(
        claim_price,
        expected_claim_price;
        atol = 1.0e-8,
        rtol = 1.0e-8,
    )

    # Analytic equilibrium quantities.
    @test isapprox(
        firm_activity,
        expected_activity;
        atol = 1.0e-8,
        rtol = 1.0e-8,
    )
    @test isapprox(
        firm_claim_quantity,
        expected_claim_quantity;
        atol = 1.0e-8,
        rtol = 1.0e-8,
    )

    # The claim market clears through the firm's positive claim demand.
    @test firm_claim_quantity > 0.0
    @test isapprox(
        firm_claim_quantity,
        CLAIM_SUPPLY;
        atol = 1.0e-8,
        rtol = 1.0e-8,
    )

    # The claim transaction exactly delivers the specific subsidy.
    @test firm_claim_expenditure < 0.0
    @test isapprox(
        firm_claim_expenditure,
        expected_total_subsidy;
        atol = 1.0e-8,
        rtol = 1.0e-8,
    )

    # The issuer's labor endowment exactly finances the claim liability.
    @test isapprox(
        issuer_endowment_value,
        0.0;
        atol = 1.0e-8,
        rtol = 0.0,
    )

    # Both structural firm conditions are active equalities.
    @test firm_activity > 0.0
    @test firm_claim_quantity > 0.0
    @test maximum(abs, firm_condition_values) <= 1.0e-8

    # All three markets clear, including the free-price claim market.
    @test maximum(abs, result.total_net_supply) <= 1.0e-8
    @test abs(result.omitted_market_residual) <= 1.0e-8
    @test abs(result.walras_value) <= 1.0e-8
    @test result.max_natural_residual <= 1.0e-8

    @test result.condition_methods[1] == :explicit_numeric_operator
end

println("========== Specific subsidy claim test ==========")
println("Solved: ", result.solved)
println("Prices: ", result.prices)
println("Expected prices: ", [expected_product_price, 1.0, expected_claim_price])
println("Firm activity: ", firm_activity)
println("Expected activity: ", expected_activity)
println("Firm claim quantity: ", firm_claim_quantity)
println("Claim supply: ", CLAIM_SUPPLY)
println("Specific subsidy rate: ", SPECIFIC_SUBSIDY_RATE)
println("Claim expenditure: ", firm_claim_expenditure)
println("Expected total subsidy: ", expected_total_subsidy)
println("Issuer endowment value: ", issuer_endowment_value)
println("Firm conditions: ", firm_condition_values)
println("Total net supply: ", result.total_net_supply)
println("Max natural residual: ", result.max_natural_residual)
println("Price lower bounds: ", result.price_lower_bounds)
println("Price upper bounds: ", result.price_upper_bounds)
println("Condition methods: ", result.condition_methods)
println("==================================================")
