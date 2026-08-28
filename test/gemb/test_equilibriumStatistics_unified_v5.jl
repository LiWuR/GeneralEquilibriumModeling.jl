# ================================================================
# test_equilibriumStatistics_unified_v5.jl
#
# Regression tests for the unified GEMB equilibrium-statistics interface.
#
# Tests the unified equilibrium_statistics(model, result) interface.
# No PATH solve is required.
# ================================================================

using Test
using GeneralEquilibriumModeling


@testset "GEMB equilibrium statistics: unified interface" begin

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

    result =
        GeneralEquilibriumModeling.GEM.EquilibriumResult(
            (
                prices=[
                    2.0,
                    3.0,
                    4.0,
                ],
                agent_net_supplies=[
                    [10.0, -5.0],
                    [-10.0, 7.0],
                ],
                total_net_supply=[
                    0.0,
                    -5.0,
                    7.0,
                ],
            ),
        )

    stats =
        GeneralEquilibriumModeling.GEMB.equilibrium_statistics(
            model,
            result,
        )

    expected_N =
        [
            10.0 -10.0
            -5.0   0.0
             0.0   7.0
        ]

    expected_VN =
        [
            20.0 -20.0
           -15.0   0.0
             0.0  28.0
        ]

    @test stats.prices ==
          [2.0, 3.0, 4.0]

    @test isempty(stats.agent_levels)
    @test isempty(stats.agent_level_refs)

    @test stats.net_supply_matrix ==
          expected_N

    @test stats.net_supply_value_matrix ==
          expected_VN

    @test stats.total_net_supply ==
          [0.0, -5.0, 7.0]

    @test stats.agent_net_supply_values ==
          [5.0, 8.0]

    @test stats.commodity_names ==
          [:product, :labor, :land]

    @test stats.agent_refs ==
          model.agent_refs

    @test propertynames(stats) ==
          (
              :prices,
              :agent_levels,
              :agent_level_refs,
              :net_supply_matrix,
              :net_supply_value_matrix,
              :total_net_supply,
              :agent_net_supply_values,
              :commodity_names,
              :agent_refs,
          )

    # Unified values must agree with the standalone public helpers.
    @test stats.net_supply_matrix ==
          GeneralEquilibriumModeling.GEMB.net_supply_matrix(
              model,
              result,
          )

    @test stats.net_supply_value_matrix ==
          GeneralEquilibriumModeling.GEMB.net_supply_value_matrix(
              model,
              result,
          )

    @test stats.agent_net_supply_values ==
          GeneralEquilibriumModeling.GEMB.agent_net_supply_values(
              model,
              result,
          )

    # Returned metadata vectors are copies, so mutating the statistics object
    # must not mutate the model or the original result.
    stats.prices[1] = 99.0
    stats.commodity_names[1] = :changed

    @test result.prices[1] == 2.0
    @test model.commodity_names[1] == :product
end

println("GEMB equilibrium-statistics unified V5 tests passed.")
