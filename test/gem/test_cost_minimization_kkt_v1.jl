# ================================================================
# test_cost_minimization_kkt_v1.jl
#
# Regression tests for cost-minimization KKT production:
#   1. interior Cobb-Douglas solution
#   2. corner solution
# ================================================================

module TestCostMinimizationKKTV1

using Test
using GeneralEquilibriumModeling.GEM

function solve_interior_model(rule_type)
    production(x) = sqrt(x[1] * x[2])

    marginal_product(x) = [
        0.5 * sqrt(x[2] / x[1]),
        0.5 * sqrt(x[1] / x[2]),
    ]

    firm_net_supply = ProductionNetSupply(
        [1],
        [1.0],
        [2, 3],
    )

    firm_conditions = rule_type(
        production,
        marginal_product,
        firm_net_supply.input_positions,
    )

    multiplier_lower_bound =
        rule_type === CostMinimizationKKTConditions ? 0.0 : -Inf

    firm = ProducerAgent(
        firm_net_supply.local_indices,
        firm_net_supply;
        variable_names=[
            :activity,
            :input_capital,
            :input_labor,
            :production_multiplier,
        ],
        variable_lower_bounds=[0.0, 0.0, 0.0, multiplier_lower_bound],
        variable_upper_bounds=[Inf, Inf, Inf, Inf],
        variable_start=[95.0, 95.0, 105.0, 2.0],
        condition_rule=firm_conditions,
        name=:firm,
    )

    household = ConsumerAgent(
        [1, 2, 3],
        function (variables, prices)
            income = 100.0 * prices[2] + 100.0 * prices[3]
            product_demand = income / prices[1]
            return [-product_demand, 100.0, 100.0]
        end;
        name=:household,
    )

    model = EquilibriumModel(
        [firm, household],
        [:product, :capital, :labor];
        numeraire_index=3,
        numeraire_value=1.0,
    )

    return solve_equilibrium_model_mcp_jump(
        model;
        p0=[1.8, 1.0, 1.0],
        residual_tol=1.0e-8,
        silent=true,
    )
end

@testset "Cost-min KKT interior consistency" begin
    stationary = solve_interior_model(ProductionStationarityConditions)
    cost_min = solve_interior_model(CostMinimizationKKTConditions)

    @test stationary.solved
    @test cost_min.solved
    @test stationary.all_markets_clear
    @test cost_min.all_markets_clear

    @test stationary.prices ≈ cost_min.prices atol=1.0e-9 rtol=1.0e-9
    @test stationary.agent_variable_values[1] ≈
        cost_min.agent_variable_values[1] atol=1.0e-9 rtol=1.0e-9

    @test cost_min.prices ≈ [2.0, 1.0, 1.0] atol=1.0e-8 rtol=1.0e-8
    @test cost_min.agent_variable_values[1] ≈ [
        100.0,
        100.0,
        100.0,
        2.0,
    ] atol=1.0e-8 rtol=1.0e-8

    @test maximum(abs, cost_min.agent_conditions[1]) <= 1.0e-8
    @test maximum(abs, cost_min.total_net_supply) <= 1.0e-8
    @test cost_min.max_natural_residual <= 1.0e-8
end

@testset "Cost-min KKT corner solution" begin
    production(x) = x[1] + 2.0 * x[2]
    marginal_product(x) = [1.0, 2.0]

    firm_net_supply = ProductionNetSupply(
        [1],
        [1.0],
        [2, 3],
    )

    firm_conditions = CostMinimizationKKTConditions(
        production,
        marginal_product,
        firm_net_supply.input_positions,
    )

    firm = ProducerAgent(
        firm_net_supply.local_indices,
        firm_net_supply;
        variable_names=[
            :activity,
            :input_1,
            :input_2,
            :production_multiplier,
        ],
        variable_lower_bounds=[0.0, 0.0, 0.0, 0.0],
        variable_upper_bounds=[Inf, Inf, Inf, Inf],
        variable_start=[2.0, 1.8, 0.1, 1.0],
        condition_rule=firm_conditions,
        name=:firm,
    )

    conversion = ProducerAgent(
        [1, 3],
        (variables, prices) -> begin
            z = variables[1]
            [-z, z / 3.0]
        end;
        variable_names=[:activity],
        variable_start=[1.0],
        name=:input_2_conversion,
    )

    household = ConsumerAgent(
        [1, 2, 3],
        function (variables, prices)
            income = 2.0 * prices[2]
            return [
                -0.5 * income / prices[1],
                2.0,
                -0.5 * income / prices[3],
            ]
        end;
        name=:household,
    )

    model = EquilibriumModel(
        [firm, conversion, household],
        [:product, :input_1, :input_2];
        numeraire_index=2,
        numeraire_value=1.0,
    )

    result = solve_equilibrium_model_mcp_jump(
        model;
        p0=[1.0, 1.0, 3.0],
        residual_tol=1.0e-8,
        silent=true,
    )

    @test result.solved
    @test result.all_markets_clear
    @test result.prices ≈ [1.0, 1.0, 3.0] atol=1.0e-8 rtol=1.0e-8

    values = result.agent_variable_values[1]
    conditions = result.agent_conditions[1]

    @test values[1] ≈ 2.0 atol=1.0e-8 rtol=1.0e-8
    @test values[2] ≈ 2.0 atol=1.0e-8 rtol=1.0e-8
    @test abs(values[3]) <= 1.0e-10
    @test values[4] ≈ 1.0 atol=1.0e-8 rtol=1.0e-8

    @test abs(conditions[1]) <= 1.0e-8
    @test abs(conditions[2]) <= 1.0e-8
    @test conditions[3] ≈ 1.0 atol=1.0e-8 rtol=1.0e-8
    @test abs(conditions[4]) <= 1.0e-8
    @test values[3] * conditions[3] ≈ 0.0 atol=1.0e-8

    @test maximum(abs, result.total_net_supply) <= 1.0e-8
    @test result.max_natural_residual <= 1.0e-8
end

end # module TestCostMinimizationKKTV1
