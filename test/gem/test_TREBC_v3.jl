# ================================================================
# test_TREBC_v3.jl
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM

@testset "TotalRevenueExpenditureBalanceConditions single activity" begin
    firm = ProducerAgent(
        [1, 2],
        (variables, prices) -> begin
            z = variables[1]
            [z, -(z^2)]
        end;
        variable_names=[:activity],
        variable_start=[2.0],
        condition_rule=TotalRevenueExpenditureBalanceConditions(),
        name=:firm,
    )

    household = ConsumerAgent(
        [1, 2],
        (variables, prices) -> [-2.0, 4.0];
        name=:household,
    )

    model = EquilibriumModel(
        [firm, household],
        [:product, :labor];
        numeraire_index=2,
    )

    result = solve_equilibrium_model_mcp_jump(
        model;
        p0=[2.0, 1.0],
        residual_tol=1.0e-8,
        silent=true,
    )

    @test result.solved
    @test result.prices ≈ [2.0, 1.0] atol=1.0e-7 rtol=1.0e-7
    @test result.agent_variable_values[1] ≈ [2.0] atol=1.0e-7 rtol=1.0e-7
    @test result.agent_conditions[1] ≈ [0.0] atol=1.0e-7 rtol=1.0e-7
end


@testset "TotalRevenueExpenditureBalanceConditions separable multi activity" begin
    firm = ProducerAgent(
        [1, 2, 3],
        (variables, prices) -> begin
            z1 = variables[1]
            z2 = variables[2]

            [
                z1,
                z2,
                -(z1^2 + z2^2),
            ]
        end;
        variable_names=[:activity_1, :activity_2],
        variable_start=[1.0, 2.0],
        condition_rule=TotalRevenueExpenditureBalanceConditions(),
        name=:composite_firm,
    )

    household = ConsumerAgent(
        [1, 2, 3],
        (variables, prices) -> [-1.0, -2.0, 5.0];
        name=:household,
    )

    model = EquilibriumModel(
        [firm, household],
        [:product_1, :product_2, :labor];
        numeraire_index=3,
    )

    result = solve_equilibrium_model_mcp_jump(
        model;
        p0=[1.0, 2.0, 1.0],
        residual_tol=1.0e-8,
        silent=true,
    )

    @test result.solved
    @test result.prices ≈ [1.0, 2.0, 1.0] atol=1.0e-7 rtol=1.0e-7
    @test result.agent_variable_values[1] ≈ [1.0, 2.0] atol=1.0e-7 rtol=1.0e-7
    @test result.agent_conditions[1] ≈ [0.0, 0.0] atol=1.0e-7 rtol=1.0e-7
    @test maximum(abs, result.total_net_supply) <= 1.0e-7
    @test result.max_natural_residual <= 1.0e-8
end

println("TotalRevenueExpenditureBalanceConditions V3 regression tests passed.")
