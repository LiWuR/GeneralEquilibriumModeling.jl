# ================================================================
# test_demandSupplyMatrices_step6_v1.jl
#
# STEP 6: model-wide gross demand / gross supply matrices.
# ================================================================

using Test
using GeneralEquilibriumModeling


@testset "GEMB demand/supply matrices STEP 6" begin
    GEMB =
        GeneralEquilibriumModeling.GEMB

    GEM =
        GeneralEquilibriumModeling.GEM

    # ------------------------------------------------------------
    # 1. Arbitrary-state matrix assembly
    # ------------------------------------------------------------

    model =
        GEMB.GEMBModel(
            [:product, :labor, :land];
            numeraire=:product,
        )

    GEMB.add_agent!(
        model,
        GEMB.CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        activity_start=100.0,
        name=:firm,
    )

    GEMB.add_agent!(
        model,
        GEMB.CESSpec([1.0]);
        demands=:product,
        endowments=:land,
        endowment_quantities=7.0,
        activity_start=100.0,
        name=:consumer,
    )

    matrices =
        GEMB.demand_supply_matrices(
            model,
            [
                [10.0],
                [10.0],
            ],
            [1.0, 1.0, 1.0],
        )

    expected_D =
        [
             0.0  10.0
            10.0   0.0
             0.0   0.0
        ]

    expected_S =
        [
            10.0  0.0
             0.0  0.0
             0.0  7.0
        ]

    expected_N =
        expected_S - expected_D

    @test matrices.demand ≈
          expected_D

    @test matrices.supply ≈
          expected_S

    @test matrices.net_supply ≈
          expected_N

    @test matrices.supply - matrices.demand ≈
          matrices.net_supply

    @test size(matrices.demand) ==
          (3, 2)

    @test model.commodity_names ==
          [:product, :labor, :land]

    @test model.agent_refs ==
          [
              GEMB.AgentRef(:firm),
              GEMB.AgentRef(:consumer),
          ]


    # ------------------------------------------------------------
    # 2. EquilibriumResult convenience method
    # ------------------------------------------------------------

    result =
        GEM.EquilibriumResult(
            (
                prices=[
                    1.0,
                    1.0,
                    1.0,
                ],
                agent_variable_values=[
                    [10.0],
                    [10.0],
                ],
                observed_variable_values=[
                    Any[],
                    Any[],
                ],
                agent_net_supplies=[
                    [10.0, -10.0],
                    [-10.0, 7.0],
                ],
                total_net_supply=[
                     0.0,
                   -10.0,
                     7.0,
                ],
            ),
        )

    equilibrium_matrices =
        GEMB.demand_supply_matrices(
            model,
            result,
        )

    @test equilibrium_matrices.demand ≈
          expected_D

    @test equilibrium_matrices.supply ≈
          expected_S

    @test equilibrium_matrices.net_supply ≈
          expected_N

    @test equilibrium_matrices.net_supply ≈
          GEMB.net_supply_matrix(
              model,
              result,
          )


    # ------------------------------------------------------------
    # 3. Observed-variable values are model-state inputs
    # ------------------------------------------------------------

    observed_model =
        GEMB.GEMBModel(
            [:product, :labor];
            numeraire=:product,
        )

    GEMB.add_agent!(
        observed_model,
        GEMB.CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        activity_start=100.0,
        name=:driver,
    )

    observed_spec =
        GEMB.ActivityDemandSpec(
            (activity, prices, observed_values) -> [
                activity * observed_values[1],
            ],
        )

    GEMB.add_agent!(
        observed_model,
        observed_spec;
        outputs=:product,
        demands=:labor,
        observed_variables=[
            GEM.AgentVariableRef(
                :driver,
                :activity,
            ),
        ],
        activity_start=100.0,
        name=:observer,
    )

    @test_throws ArgumentError GEMB.demand_supply_matrices(
        observed_model,
        [
            [2.0],
            [3.0],
        ],
        [1.0, 1.0],
    )

    observed_matrices =
        GEMB.demand_supply_matrices(
            observed_model,
            [
                [2.0],
                [3.0],
            ],
            [1.0, 1.0];
            observed_values=[
                Any[],
                [2.0],
            ],
        )

    # driver demand = 2 labor; observer demand = 3*2 = 6 labor
    @test observed_matrices.demand ≈
          [
            0.0  0.0
            2.0  6.0
        ]

    @test observed_matrices.supply ≈
          [
            2.0  3.0
            0.0  0.0
        ]

    @test observed_matrices.net_supply ≈
          observed_matrices.supply -
          observed_matrices.demand


    # ------------------------------------------------------------
    # 4. Result convenience uses stored observed-variable values
    # ------------------------------------------------------------

    observed_result =
        GEM.EquilibriumResult(
            (
                prices=[
                    1.0,
                    1.0,
                ],
                agent_variable_values=[
                    [2.0],
                    [3.0],
                ],
                observed_variable_values=[
                    Any[],
                    [2.0],
                ],
                agent_net_supplies=[
                    [2.0, -2.0],
                    [3.0, -6.0],
                ],
                total_net_supply=[
                     5.0,
                    -8.0,
                ],
            ),
        )

    observed_equilibrium_matrices =
        GEMB.demand_supply_matrices(
            observed_model,
            observed_result,
        )

    @test observed_equilibrium_matrices.demand ≈
          observed_matrices.demand

    @test observed_equilibrium_matrices.supply ≈
          observed_matrices.supply

    @test observed_equilibrium_matrices.net_supply ≈
          observed_matrices.net_supply


    # ------------------------------------------------------------
    # 5. NetSupplyOnly agents remain unsupported for gross matrices
    # ------------------------------------------------------------

    custom_model =
        GEMB.GEMBModel(
            [:product];
            numeraire=:product,
        )

    GEMB.add_net_supply_agent!(
        custom_model,
        (variables, prices) -> [0.0];
        commodities=:product,
        name=:custom,
    )

    @test_throws ArgumentError GEMB.demand_supply_matrices(
        custom_model,
        [
            Float64[],
        ],
        [1.0],
    )


    # ------------------------------------------------------------
    # 6. Dimension checks
    # ------------------------------------------------------------

    @test_throws DimensionMismatch GEMB.demand_supply_matrices(
        model,
        [
            [10.0],
        ],
        [1.0, 1.0, 1.0],
    )

    @test_throws DimensionMismatch GEMB.demand_supply_matrices(
        model,
        [
            [10.0],
            [10.0],
        ],
        [1.0, 1.0],
    )
end

println("GEMB demand/supply matrices STEP 6 tests passed.")
@testset "GEMB demand/supply value matrices" begin
    GEMB =
        GeneralEquilibriumModeling.GEMB

    model =
        GEMB.GEMBModel(
            [:product, :labor];
            numeraire=:product,
        )

    GEMB.add_agent!(
        model,
        GEMB.CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        activity_start=100.0,
        name=:firm,
    )

    GEMB.add_agent!(
        model,
        GEMB.CESSpec([1.0]);
        demands=:product,
        endowments=:labor,
        endowment_quantities=10.0,
        activity_start=100.0,
        name=:consumer,
    )

    prices =
        [2.0, 3.0]

    flows =
        GEMB.demand_supply_matrices(
            model,
            [
                [4.0],
                [5.0],
            ],
            prices,
        )

    D =
        [
            0.0  5.0
            4.0  0.0
        ]

    S =
        [
            4.0   0.0
            0.0  10.0
        ]

    DV =
        [
             0.0  10.0
            12.0   0.0
        ]

    SV =
        [
            8.0   0.0
            0.0  30.0
        ]

    @test flows.demand ≈ D
    @test flows.supply ≈ S

    @test flows.demand_value ≈ DV
    @test flows.supply_value ≈ SV

    # D and S: economically meaningful commodity totals only.
    @test flows.total_demand ≈
          [5.0, 4.0]

    @test flows.total_supply ≈
          [4.0, 10.0]

    # DV and SV: both commodity totals and agent totals are meaningful.
    @test flows.total_demand_value ≈
          [10.0, 12.0]

    @test flows.total_supply_value ≈
          [8.0, 30.0]

    @test flows.agent_expenditure ≈
          [12.0, 10.0]

    @test flows.agent_revenue ≈
          [8.0, 30.0]

    # Value matrices are simply price-weighted quantity matrices.
    price_column =
        reshape(
            prices,
            :,
            1,
        )

    @test flows.demand_value ≈
          price_column .* flows.demand

    @test flows.supply_value ≈
          price_column .* flows.supply
end

