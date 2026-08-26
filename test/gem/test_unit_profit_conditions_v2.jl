# ================================================================
# test_unit_profit_conditions_v2.jl
#
# Regression test for UnitProfitConditions after removal of
# activity_structure.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM

@testset "UnitProfitConditions V2" begin
    firm = ProducerAgent(
        [1, 2],
        (variables, prices) -> begin
            z = variables[1]
            [z, -z]
        end;
        variable_names=[:activity],
        variable_start=[4.0],
        condition_rule=UnitProfitConditions(),
        name=:firm,
    )

    household = ConsumerAgent(
        [1, 2],
        (variables, prices) -> begin
            income = 4.0 * prices[2]
            [
                -income / prices[1],
                4.0,
            ]
        end;
        name=:household,
    )

    model = EquilibriumModel(
        [firm, household],
        [:product, :labor];
        numeraire_index=2,
    )

    result = solve_equilibrium_model_mcp_jump(
        model;
        p0=[1.0, 1.0],
        residual_tol=1.0e-8,
        silent=true,
    )

    @test result.solved
    @test result.mcp_solved
    @test agent_condition_rule(firm) isa UnitProfitConditions
    @test agent_uses_automatic_conditions(firm)

    @test isapprox(
        result.prices,
        [1.0, 1.0];
        atol=1.0e-7,
        rtol=1.0e-7,
    )

    @test isapprox(
        result.agent_variable_values[1][1],
        4.0;
        atol=1.0e-7,
        rtol=1.0e-7,
    )

    @test isapprox(
        result.agent_conditions[1],
        [0.0];
        atol=1.0e-7,
        rtol=1.0e-7,
    )

    @test !hasproperty(result, :activity_structures)
    @test maximum(abs, result.total_net_supply) <= 1.0e-7
    @test result.max_natural_residual <= 1.0e-8
end

println("UnitProfitConditions V2 regression test passed.")
