# ================================================================
# test_equilibriumStatistics_netSupplyValue_v3.jl
#
# Focused regression tests for GEMB equilibrium statistics STEP 2.
#
# V3 avoids GEM / GEMB alias assignments so it is safe when included
# inside the package-level GEMBTests module.
#
# No PATH solve is required. The tests use a known GEMBModel and a
# lightweight GEM.EquilibriumResult with known prices and net supplies.
# ================================================================

using Test
using GeneralEquilibriumModeling


@testset "GEMB equilibrium statistics: net-supply values" begin

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

    N =
        GeneralEquilibriumModeling.GEMB.net_supply_matrix(
            model,
            result,
        )

    expected_N =
        [
            10.0 -10.0
            -5.0   0.0
             0.0   7.0
        ]

    @test N == expected_N

    VN =
        GeneralEquilibriumModeling.GEMB.net_supply_value_matrix(
            model,
            result,
        )

    expected_VN =
        [
            20.0 -20.0
           -15.0   0.0
             0.0  28.0
        ]

    @test VN == expected_VN

    values =
        GeneralEquilibriumModeling.GEMB.agent_net_supply_values(
            model,
            result,
        )

    @test values == [5.0, 8.0]

    @test vec(sum(N; dims=2)) ==
          result.total_net_supply

    @test vec(sum(VN; dims=1)) ==
          values

    # Inconsistent stored total net supply must be rejected.
    inconsistent_total =
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
                    1.0,
                    -5.0,
                    7.0,
                ],
            ),
        )

    @test_throws ArgumentError GeneralEquilibriumModeling.GEMB.net_supply_matrix(
        model,
        inconsistent_total,
    )

    # Price vector length must match the commodity dimension.
    bad_prices =
        GeneralEquilibriumModeling.GEM.EquilibriumResult(
            (
                prices=[
                    2.0,
                    3.0,
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

    @test_throws DimensionMismatch GeneralEquilibriumModeling.GEMB.net_supply_value_matrix(
        model,
        bad_prices,
    )
end

println("GEMB equilibrium-statistics STEP 2 tests passed.")
