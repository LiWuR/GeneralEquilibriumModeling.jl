# ================================================================
# test_pollution_externality_negative_price_v2.jl
#
# Regression test for the current GEM public API.
#
# This test combines:
#   1. a consumer observing another agent's endogenous activity;
#   2. a pollution commodity with a free equilibrium price;
#   3. a negative equilibrium pollution price;
#   4. simultaneous production, cleanup, consumption, and market clearing.
#
# Commodities:
#   1. product
#   2. labor      (numeraire, p_labor = 1)
#   3. pollution  (free price)
#
# Polluting firm, activity z:
#   +1 product
#   -1 labor
#   +1 pollution
#
# Cleanup activity, level y:
#   -1 labor
#   -1 pollution
#
# Consumer:
#   labor endowment W = 9
#   demands product x_product and labor x_labor
#   observes the polluting firm's activity z
#
# Marginal utilities:
#   MU_product = (1 - kappa*z) / x_product
#   MU_labor   = 1 / x_labor
#
# with kappa = 0.1.
#
# Analytic equilibrium:
#
#   p_product   = 2
#   p_labor     = 1
#   p_pollution = -1
#
#   z = 2
#   y = 2
#
#   x_product = 2
#   x_labor   = 5
#   lambda    = 0.2
# ================================================================

module TestPollutionExternalityNegativePriceV2

using Test
using GeneralEquilibriumModeling.GEM

const LABOR_ENDOWMENT = 9.0
const KAPPA = 0.1
const ATOL = 1.0e-8
const RTOL = 1.0e-8


# ----------------------------------------------------------------
# 1. Polluting firm
# ----------------------------------------------------------------

function polluting_firm_net_supply(variables, prices)
    z = variables[1]

    return [
        z,      # product supply
        -z,     # labor demand
        z,      # pollution supply
    ]
end

polluting_firm = ProducerAgent(
    [1, 2, 3],
    polluting_firm_net_supply;
    variable_names=[:activity],
    variable_lower_bounds=[0.0],
    variable_upper_bounds=[Inf],
    variable_start=[1.5],
    name=:polluting_firm,
)


# ----------------------------------------------------------------
# 2. Cleanup activity
# ----------------------------------------------------------------

function cleanup_net_supply(variables, prices)
    y = variables[1]

    return [
        -y,     # labor demand
        -y,     # pollution absorption
    ]
end

cleanup = ProducerAgent(
    [2, 3],
    cleanup_net_supply;
    variable_names=[:activity],
    variable_lower_bounds=[0.0],
    variable_upper_bounds=[Inf],
    variable_start=[1.0],
    name=:cleanup,
)


# ----------------------------------------------------------------
# 3. Consumer
#
# Consumer variables:
#
#   [x_product, x_labor, budget_multiplier]
#
# The consumer observes the polluting firm's activity. The production
# externality lowers the marginal utility of product:
#
#   MU_product = (1 - kappa*z) / x_product.
# ----------------------------------------------------------------

function consumer_net_supply(variables, prices)
    x_product = variables[1]
    x_labor = variables[2]

    return [
        -x_product,
        LABOR_ENDOWMENT - x_labor,
    ]
end

function consumer_marginal_utility(demand, observed_values)
    x_product = demand[1]
    x_labor = demand[2]
    z_polluting = observed_values[1]

    return [
        (1.0 - KAPPA * z_polluting) / x_product,
        1.0 / x_labor,
    ]
end

consumer_conditions = MarginalUtilityConsumerConditions(
    consumer_marginal_utility,
    [1, 2],
    [1, 2],
    3,
)

consumer = NetSupplyAgent(
    [1, 2],
    consumer_net_supply;
    variable_names=[
        :product_demand,
        :labor_demand,
        :budget_multiplier,
    ],
    variable_lower_bounds=[
        1.0e-8,
        1.0e-8,
        0.0,
    ],
    variable_upper_bounds=[
        Inf,
        Inf,
        Inf,
    ],
    variable_start=[
        2.1,
        4.8,
        0.2,
    ],
    observed_variables=[
        AgentVariableRef(:polluting_firm, :activity),
    ],
    condition_rule=consumer_conditions,
    name=:consumer,
)


# ----------------------------------------------------------------
# 4. Equilibrium model
#
# Pollution is assigned a free price so the equilibrium price may be
# negative.
# ----------------------------------------------------------------

model = EquilibriumModel(
    [polluting_firm, cleanup, consumer],
    [:product, :labor, :pollution];
    numeraire_index=2,
    numeraire_value=1.0,
    price_lower_bounds=[
        0.0,
        0.0,
        -Inf,
    ],
    price_upper_bounds=[
        Inf,
        Inf,
        Inf,
    ],
)


# ----------------------------------------------------------------
# 5. Solve
# ----------------------------------------------------------------

result = solve_equilibrium_model_mcp_jump(
    model;
    p0=[1.5, 1.0, 0.0],
    residual_tol=1.0e-8,
    silent=true,
)


# ----------------------------------------------------------------
# 6. Regression checks
# ----------------------------------------------------------------

@testset "Pollution externality with negative free price" begin
    @test result.solved
    @test result.all_markets_clear

    # Pollution must be represented by a true free price.
    @test result.price_lower_bounds[3] == -Inf
    @test result.price_upper_bounds[3] == Inf

    # Analytic equilibrium prices.
    @test isapprox(
        result.prices,
        [2.0, 1.0, -1.0];
        atol=ATOL,
        rtol=RTOL,
    )
    @test result.prices[3] < 0.0

    # Production and cleanup activities.
    z_polluting = result.agent_variable_values[1][1]
    y_cleanup = result.agent_variable_values[2][1]

    @test isapprox(z_polluting, 2.0; atol=ATOL, rtol=RTOL)
    @test isapprox(y_cleanup, 2.0; atol=ATOL, rtol=RTOL)

    # Consumer allocation and budget multiplier.
    consumer_values = result.agent_variable_values[3]

    @test isapprox(
        consumer_values,
        [2.0, 5.0, 0.2];
        atol=ATOL,
        rtol=RTOL,
    )

    # The consumer must observe the polluting firm's actual equilibrium
    # activity.
    @test agent_observed_variable_count(consumer) == 1
    @test agent_observed_variables(consumer)[1] ==
        AgentVariableRef(:polluting_firm, :activity)

    @test isapprox(
        result.observed_variable_values[3][1],
        z_polluting;
        atol=1.0e-10,
        rtol=1.0e-10,
    )

    # Active producer activities satisfy their zero-profit conditions.
    @test z_polluting > 0.0
    @test y_cleanup > 0.0
    @test abs(result.agent_conditions[1][1]) <= ATOL
    @test abs(result.agent_conditions[2][1]) <= ATOL

    # All commodity markets clear and the MCP residual is small.
    @test maximum(abs, result.total_net_supply) <= ATOL
    @test result.max_natural_residual <= ATOL
end

end # module TestPollutionExternalityNegativePriceV2
