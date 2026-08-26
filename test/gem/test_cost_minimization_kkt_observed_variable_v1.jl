# ================================================================
# test_cost_minimization_kkt_observed_variable_v1.jl
#
# Regression test for a cost-minimization KKT producer that observes
# another producer's endogenous activity.
# ================================================================

module TestCostMinimizationKKTObservedVariableV1

using Test
using GeneralEquilibriumModeling.GEM

function production(x, observed_values)
    A = 1.0 + observed_values[1]
    return A * (x[1] + 2.0 * x[2])
end

function marginal_product(x, observed_values)
    A = 1.0 + observed_values[1]
    return [A, 2.0 * A]
end

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

cost_min_firm = ProducerAgent(
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
    variable_start=[5.8, 2.9, 0.05, 0.5],
    observed_variables=[
        AgentVariableRef(:driver, :activity),
    ],
    condition_rule=firm_conditions,
    name=:cost_min_firm,
)

driver = ProducerAgent(
    [2, 4],
    (variables, prices) -> begin
        z = variables[1]
        [-z, z]
    end;
    variable_names=[:activity],
    variable_start=[1.0],
    name=:driver,
)

x2_conversion = ProducerAgent(
    [1, 3],
    (variables, prices) -> begin
        z = variables[1]
        [-z, z / 6.0]
    end;
    variable_names=[:activity],
    variable_start=[2.0],
    name=:x2_conversion,
)

household = ConsumerAgent(
    [1, 2, 3, 4],
    function (variables, prices)
        income = 4.0 * prices[2]
        return [
            -0.50 * income / prices[1],
            4.0,
            -0.25 * income / prices[3],
            -0.25 * income / prices[4],
        ]
    end;
    name=:household,
)

model = EquilibriumModel(
    [cost_min_firm, driver, x2_conversion, household],
    [:product, :input_1, :input_2, :signal];
    numeraire_index=2,
    numeraire_value=1.0,
)

result = solve_equilibrium_model_mcp_jump(
    model;
    p0=[0.5, 1.0, 3.0, 1.0],
    residual_tol=1.0e-8,
    silent=true,
)

@testset "Cost-min KKT observed variable" begin
    @test result.solved
    @test result.all_markets_clear
    @test result.prices ≈ [0.5, 1.0, 3.0, 1.0] atol=1.0e-8 rtol=1.0e-8

    driver_activity = result.agent_variable_values[2][1]
    values = result.agent_variable_values[1]
    conditions = result.agent_conditions[1]

    @test driver_activity ≈ 1.0 atol=1.0e-8 rtol=1.0e-8
    @test result.observed_variable_values[1][1] ≈
        driver_activity atol=1.0e-10 rtol=1.0e-10

    @test values[1] ≈ 6.0 atol=1.0e-8 rtol=1.0e-8
    @test values[2] ≈ 3.0 atol=1.0e-8 rtol=1.0e-8
    @test abs(values[3]) <= 1.0e-10
    @test values[4] ≈ 0.5 atol=1.0e-8 rtol=1.0e-8

    @test abs(conditions[1]) <= 1.0e-8
    @test abs(conditions[2]) <= 1.0e-8
    @test conditions[3] ≈ 1.0 atol=1.0e-8 rtol=1.0e-8
    @test abs(conditions[4]) <= 1.0e-8

    @test maximum(abs, result.total_net_supply) <= 1.0e-8
    @test result.max_natural_residual <= 1.0e-8
end

end # module TestCostMinimizationKKTObservedVariableV1
