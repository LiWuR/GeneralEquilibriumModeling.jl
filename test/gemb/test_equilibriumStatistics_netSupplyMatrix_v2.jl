# ================================================================
# test_equilibriumStatistics_netSupplyMatrix_v2.jl
#
# Focused regression tests for GEMB equilibrium statistics STEP 1.
#
# V2 fixes module-name collisions when this file is included inside the
# package-level GEMBTests module. It deliberately uses fully qualified
# GeneralEquilibriumModeling.GEM / GEMB names instead of assigning local
# aliases named GEM or GEMB.
#
# The tests deliberately avoid PATH. They construct a GEMBModel and a
# lightweight GEM.EquilibriumResult containing known local net supplies,
# then verify the global commodity-by-agent matrix assembly.
# ================================================================

using Test
using GeneralEquilibriumModeling


@testset "GEMB equilibrium statistics: net-supply matrix" begin

    model =
        GeneralEquilibriumModeling.GEMB.GEMBModel(
            [:product, :labor, :land];
            numeraire=:product,
        )

    GeneralEquilibriumModeling.GEMB.add_agent!(
        model,
        GeneralEquilibriumModeling.GEMB.CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        name=:firm,
    )

    GeneralEquilibriumModeling.GEMB.add_agent!(
        model,
        GeneralEquilibriumModeling.GEMB.CESSpec([1.0]);
        demands=:product,
        endowments=:land,
        endowment_quantities=[7.0],
        name=:consumer,
    )

    @test model.commodity_names ==
          [:product, :labor, :land]

    @test length(model.agents) == 2

    @test GeneralEquilibriumModeling.GEM.agent_commodity_indices(
        model.agents[1],
    ) == [1, 2]

    @test GeneralEquilibriumModeling.GEM.agent_commodity_indices(
        model.agents[2],
    ) == [1, 3]

    result =
        GeneralEquilibriumModeling.GEM.EquilibriumResult(
            (
                agent_net_supplies=[
                    [10.0, -5.0],
                    [-10.0, 7.0],
                ],
            ),
        )

    N =
        GeneralEquilibriumModeling.GEMB.net_supply_matrix(
            model,
            result,
        )

    expected =
        [
            10.0 -10.0
            -5.0   0.0
             0.0   7.0
        ]

    @test size(N) == (3, 2)
    @test N == expected

    # Column order must remain identical to model.agents / model.agent_refs.
    @test model.agent_refs[1] ==
          GeneralEquilibriumModeling.GEMB.AgentRef(:firm)

    @test model.agent_refs[2] ==
          GeneralEquilibriumModeling.GEMB.AgentRef(:consumer)

    @test N[:, 1] == [10.0, -5.0, 0.0]
    @test N[:, 2] == [-10.0, 0.0, 7.0]

    # A result from a different agent count must be rejected.
    bad_agent_count =
        GeneralEquilibriumModeling.GEM.EquilibriumResult(
            (
                agent_net_supplies=[
                    [10.0, -5.0],
                ],
            ),
        )

    @test_throws DimensionMismatch GeneralEquilibriumModeling.GEMB.net_supply_matrix(
        model,
        bad_agent_count,
    )

    # A malformed local net-supply vector must be rejected.
    bad_local_length =
        GeneralEquilibriumModeling.GEM.EquilibriumResult(
            (
                agent_net_supplies=[
                    [10.0],
                    [-10.0, 7.0],
                ],
            ),
        )

    @test_throws DimensionMismatch GeneralEquilibriumModeling.GEMB.net_supply_matrix(
        model,
        bad_local_length,
    )
end

println("GEMB equilibrium-statistics STEP 1 tests passed.")
