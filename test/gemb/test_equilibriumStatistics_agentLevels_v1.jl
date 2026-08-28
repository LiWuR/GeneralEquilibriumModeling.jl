# ================================================================
# test_equilibriumStatistics_agentLevels_v1.jl
#
# Regression tests for:
#
#   stats.agent_levels
#   stats.agent_level_refs
#
# The test verifies:
#   - standard single activity;
#   - multiple activities belonging to one agent;
#   - utility level;
#   - exclusion of non-level endogenous variables;
#   - repeated AgentRef entries for multi-activity agents;
#   - display integration.
#
# No PATH solve is required.
# ================================================================

using Test
using GeneralEquilibriumModeling


@testset "GEMB equilibrium statistics: agent levels" begin

    model =
        GeneralEquilibriumModeling.GEMB.GEMBModel(
            [:product, :labor];
            numeraire=:product,
        )

    # Standard producer -> variable_names == [:activity].
    GeneralEquilibriumModeling.GEMB.add_agent!(
        model,
        GeneralEquilibriumModeling.GEMB.CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        name=:firm1,
    )

    # Custom multi-activity producer. The third endogenous variable is
    # deliberately not a level and must therefore be excluded.
    GeneralEquilibriumModeling.GEMB.add_net_supply_agent!(
        model,
        (local_variables, local_prices, observed_values=Any[]) ->
            zeros(length(local_prices));
        commodities=[:product, :labor],
        variable_names=[
            :activity_1,
            :activity_2,
            :claim_quantity,
        ],
        variable_lower_bounds=[
            0.0,
            0.0,
            0.0,
        ],
        variable_upper_bounds=[
            Inf,
            Inf,
            Inf,
        ],
        variable_start=[
            40.0,
            60.0,
            7.0,
        ],
        condition_rule=
            GeneralEquilibriumModeling.GEM.ExplicitAgentConditions(
                (local_variables, local_prices, net_supply) ->
                    zeros(length(local_variables)),
            ),
        name=:firm2,
    )

    # Standard compensated-demand consumer -> variable_names == [:utility].
    GeneralEquilibriumModeling.GEMB.add_agent!(
        model,
        GeneralEquilibriumModeling.GEMB.CESSpec([1.0]);
        demands=:product,
        endowments=:labor,
        endowment_quantities=[10.0],
        name=:consumer,
    )

    # Custom endogenous non-level variable: must not enter agent_levels.
    GeneralEquilibriumModeling.GEMB.add_net_supply_agent!(
        model,
        (local_variables, local_prices, observed_values=Any[]) ->
            zeros(length(local_prices));
        commodities=[:product],
        variable_names=[:auxiliary],
        variable_lower_bounds=[0.0],
        variable_upper_bounds=[Inf],
        variable_start=[3.0],
        condition_rule=
            GeneralEquilibriumModeling.GEM.ExplicitAgentConditions(
                (local_variables, local_prices, net_supply) ->
                    [local_variables[1]],
            ),
        name=:condition_like,
    )

    @test model.agents[1].variable_names == [:activity]
    @test model.agents[2].variable_names ==
          [:activity_1, :activity_2, :claim_quantity]
    @test model.agents[3].variable_names == [:utility]
    @test model.agents[4].variable_names == [:auxiliary]

    result =
        GeneralEquilibriumModeling.GEM.EquilibriumResult(
            (
                prices=[
                    1.0,
                    1.0,
                ],
                agent_variable_names=[
                    copy(agent.variable_names)
                    for agent in model.agents
                ],
                agent_variable_values=[
                    [100.0],
                    [40.0, 60.0, 7.0],
                    [12.5],
                    [3.0],
                ],
                agent_net_supplies=[
                    [0.0, 0.0],
                    [0.0, 0.0],
                    [0.0, 0.0],
                    [0.0],
                ],
                total_net_supply=[
                    0.0,
                    0.0,
                ],
            ),
        )

    stats =
        GeneralEquilibriumModeling.GEMB.equilibrium_statistics(
            model,
            result,
        )

    @test stats.agent_levels ==
          [100.0, 40.0, 60.0, 12.5]

    @test stats.agent_level_refs ==
          [
              GeneralEquilibriumModeling.GEMB.AgentRef(:firm1),
              GeneralEquilibriumModeling.GEMB.AgentRef(:firm2),
              GeneralEquilibriumModeling.GEMB.AgentRef(:firm2),
              GeneralEquilibriumModeling.GEMB.AgentRef(:consumer),
          ]

    @test length(stats.agent_levels) ==
          length(stats.agent_level_refs)

    # The custom non-level variables are excluded.
    @test 7.0 ∉ stats.agent_levels
    @test 3.0 ∉ stats.agent_levels

    # Multi-activity ownership is represented by repeating the same AgentRef.
    @test count(
        ==(
            GeneralEquilibriumModeling.GEMB.AgentRef(:firm2),
        ),
        stats.agent_level_refs,
    ) == 2

    io =
        IOBuffer()

    GeneralEquilibriumModeling.GEMB.print_equilibrium_statistics(
        io,
        model,
        result,
    )

    output =
        String(
            take!(
                io,
            ),
        )

    @test occursin(
        "Agent levels",
        output,
    )

    @test count(
        line -> occursin("firm2", line),
        split(output, '\n'),
    ) >= 2

    # Malformed metadata is rejected rather than silently misaligned.
    bad_result =
        GeneralEquilibriumModeling.GEM.EquilibriumResult(
            (
                prices=[
                    1.0,
                    1.0,
                ],
                agent_variable_names=[
                    [:activity],
                    [:activity_1, :activity_2],
                    [:utility],
                    [:auxiliary],
                ],
                agent_variable_values=[
                    [100.0],
                    [40.0],
                    [12.5],
                    [3.0],
                ],
                agent_net_supplies=[
                    [0.0, 0.0],
                    [0.0, 0.0],
                    [0.0, 0.0],
                    [0.0],
                ],
                total_net_supply=[
                    0.0,
                    0.0,
                ],
            ),
        )

    @test_throws DimensionMismatch GeneralEquilibriumModeling.GEMB.equilibrium_statistics(
        model,
        bad_result,
    )
end


println("GEMB equilibrium-statistics agent-level tests passed.")
