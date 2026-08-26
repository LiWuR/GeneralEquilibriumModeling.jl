# ================================================================
# test_condition_agent_v1.jl
#
# Focused regression tests for GEMB ConditionAgentSpec.
#
# Coverage:
#
#   1. single endogenous variable;
#   2. identically zero net supply;
#   3. multiple endogenous variables and multiple conditions;
#   4. observing an equilibrium price;
#   5. observing another agent variable;
#   6. forward AgentVariableRef resolution;
#   7. rejection of real commodity mappings.
#
# The tests use only the public GEMB high-level interface.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "GEMB ConditionAgentSpec v1" begin

    # ------------------------------------------------------------
    # 1. Single variable
    #
    #     x - 2 = 0
    #
    # The condition agent has no economic net supply.
    # ------------------------------------------------------------

    @testset "single variable and zero net supply" begin
        model = GEMBModel(
            [:anchor];
            numeraire=:anchor,
            numeraire_value=1.0,
        )

        add_agent!(
            model,
            ConditionAgentSpec(
                (variables, observed_values) -> [
                    variables[1] - 2.0,
                ],
            );
            variable_names=:x,
            variable_start=1.0,
            name=:conditionAgent,
        )

        result = solve(
            model;
            p0=[1.0],
            residual_tol=1.0e-10,
            silent=true,
        )

        @test result.solved
        @test result.mcp_solved
        @test result.all_markets_clear

        @test isapprox(
            result.agent_variable_values[1][1],
            2.0;
            atol=1.0e-9,
            rtol=1.0e-9,
        )

        @test length(
            result.agent_net_supplies[1],
        ) == 1

        @test iszero(
            result.agent_net_supplies[1][1],
        )

        @test iszero(
            result.total_net_supply[1],
        )

        @test result.max_natural_residual <= 1.0e-9
    end


    # ------------------------------------------------------------
    # 2. Multiple variables
    #
    #     x + y - 3 = 0
    #     x - y - 1 = 0
    #
    # gives
    #
    #     x = 2
    #     y = 1.
    # ------------------------------------------------------------

    @testset "multiple variables and conditions" begin
        model = GEMBModel(
            [:anchor];
            numeraire=:anchor,
            numeraire_value=1.0,
        )

        add_agent!(
            model,
            ConditionAgentSpec(
                (variables, observed_values) -> begin
                    x = variables[1]
                    y = variables[2]

                    return [
                        x + y - 3.0,
                        x - y - 1.0,
                    ]
                end,
            );
            variable_names=[
                :x,
                :y,
            ],
            variable_start=[
                1.5,
                1.5,
            ],
            name=:conditionAgent,
        )

        result = solve(
            model;
            p0=[1.0],
            residual_tol=1.0e-10,
            silent=true,
        )

        @test result.solved

        @test isapprox(
            result.agent_variable_values[1],
            [
                2.0,
                1.0,
            ];
            atol=1.0e-9,
            rtol=1.0e-9,
        )

        @test maximum(
            abs,
            result.agent_net_supplies[1],
        ) <= 1.0e-12

        @test result.max_natural_residual <= 1.0e-9
    end


    # ------------------------------------------------------------
    # 3. Observe an equilibrium price
    #
    #     x - p_anchor = 0
    #
    # with the numeraire fixed at
    #
    #     p_anchor = 2,
    #
    # so
    #
    #     x = 2.
    # ------------------------------------------------------------

    @testset "observed price" begin
        model = GEMBModel(
            [:anchor];
            numeraire=:anchor,
            numeraire_value=2.0,
        )

        add_agent!(
            model,
            ConditionAgentSpec(
                (variables, observed_values) -> begin
                    x = variables[1]
                    p_anchor = observed_values[1]

                    return [
                        x - p_anchor,
                    ]
                end,
            );
            variable_names=:x,
            variable_start=1.0,
            observed_variables=[
                PriceVariableRef(:anchor),
            ],
            name=:priceObserver,
        )

        result = solve(
            model;
            p0=[2.0],
            residual_tol=1.0e-10,
            silent=true,
        )

        @test result.solved

        @test isapprox(
            result.prices[1],
            2.0;
            atol=1.0e-12,
            rtol=1.0e-12,
        )

        @test isapprox(
            result.agent_variable_values[1][1],
            2.0;
            atol=1.0e-9,
            rtol=1.0e-9,
        )

        @test iszero(
            result.agent_net_supplies[1][1],
        )
    end


    # ------------------------------------------------------------
    # 4. Observe another agent variable with a forward reference
    #
    # follower is added BEFORE leader:
    #
    #     follower:  y - z = 0
    #     leader:    z - 3 = 0
    #
    # so
    #
    #     y = z = 3.
    #
    # This verifies that ConditionAgentSpec works with GEMB's existing
    # structured AgentVariableRef materialization and forward references.
    # ------------------------------------------------------------

    @testset "observed agent variable and forward reference" begin
        model = GEMBModel(
            [:anchor];
            numeraire=:anchor,
            numeraire_value=1.0,
        )

        add_agent!(
            model,
            ConditionAgentSpec(
                (variables, observed_values) -> begin
                    y = variables[1]
                    z = observed_values[1]

                    return [
                        y - z,
                    ]
                end,
            );
            variable_names=:copy,
            variable_start=2.0,
            observed_variables=[
                agent_variable_ref(
                    :leader,
                    :level,
                ),
            ],
            name=:follower,
        )

        add_agent!(
            model,
            ConditionAgentSpec(
                (variables, observed_values) -> [
                    variables[1] - 3.0,
                ],
            );
            variable_names=:level,
            variable_start=2.0,
            name=:leader,
        )

        result = solve(
            model;
            p0=[1.0],
            residual_tol=1.0e-10,
            silent=true,
        )

        @test result.solved

        @test isapprox(
            result.agent_variable_values[1][1],
            3.0;
            atol=1.0e-9,
            rtol=1.0e-9,
        )

        @test isapprox(
            result.agent_variable_values[2][1],
            3.0;
            atol=1.0e-9,
            rtol=1.0e-9,
        )

        @test maximum(
            abs,
            result.total_net_supply,
        ) <= 1.0e-12

        @test result.max_natural_residual <= 1.0e-9
    end


    # ------------------------------------------------------------
    # 5. A ConditionAgentSpec must not acquire an economic commodity
    #    mapping through the public high-level API.
    # ------------------------------------------------------------

    @testset "reject commodity mappings" begin
        model = GEMBModel(
            [:anchor];
            numeraire=:anchor,
            numeraire_value=1.0,
        )

        spec = ConditionAgentSpec(
            (variables, observed_values) -> [
                variables[1] - 1.0,
            ],
        )

        @test_throws ArgumentError add_agent!(
            model,
            spec;
            outputs=:anchor,
            variable_names=:x,
            name=:invalidConditionAgent,
        )
    end


    # ------------------------------------------------------------
    # 6. Basic validation checks
    # ------------------------------------------------------------

    @testset "argument validation" begin
        model = GEMBModel(
            [:anchor];
            numeraire=:anchor,
            numeraire_value=1.0,
        )

        spec = ConditionAgentSpec(
            (variables, observed_values) -> variables,
        )

        @test_throws ArgumentError add_agent!(
            model,
            spec;
            variable_names=[
                :x,
                :x,
            ],
            name=:duplicateVariableNames,
        )

        @test_throws DimensionMismatch add_agent!(
            model,
            spec;
            variable_names=[
                :x,
                :y,
            ],
            variable_start=[1.0],
            name=:wrongStartLength,
        )

        @test_throws ArgumentError add_agent!(
            model,
            spec;
            variable_names=:x,
            variable_start=2.0,
            variable_lower_bounds=3.0,
            variable_upper_bounds=4.0,
            name=:startOutsideBounds,
        )
    end
end


println()
println(
    "ConditionAgentSpec focused regression tests completed.",
)
