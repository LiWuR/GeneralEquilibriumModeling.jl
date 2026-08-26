# ================================================================
# test_byPeriod_step7a_v2.jl
#
# STEP 7A:
# explicit period-varying template values.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "ByPeriod STEP 7A" begin

    # ------------------------------------------------------------
    # 1. Plain values remain plain values.
    # ------------------------------------------------------------

    plain_vector =
        [10.0, 20.0]

    @test GEMB._materialize_template_value(
        plain_vector;
        period=3,
        position=2,
        periods=[1, 3],
    ) === plain_vector


    # ------------------------------------------------------------
    # 2. Vector provider follows template position, not period label.
    # ------------------------------------------------------------

    vector_values =
        ByPeriod([
            100.0,
            300.0,
            500.0,
        ])

    @test GEMB._materialize_template_value(
        vector_values;
        period=3,
        position=2,
        periods=[1, 3, 5],
    ) == 300.0

    @test_throws DimensionMismatch GEMB._materialize_template_value(
        ByPeriod([
            1.0,
            2.0,
        ]);
        period=3,
        position=2,
        periods=[1, 3, 5],
    )


    # ------------------------------------------------------------
    # 3. Mapping provider follows actual period labels.
    # ------------------------------------------------------------

    mapped_values =
        ByPeriod(
            1 => 0.10,
            3 => 0.30,
            5 => 0.50,
        )

    @test GEMB._materialize_template_value(
        mapped_values;
        period=3,
        periods=[1, 3, 5],
    ) == 0.30

    @test_throws ArgumentError GEMB._materialize_template_value(
        mapped_values;
        period=2,
        periods=[1, 2, 3],
    )


    # ------------------------------------------------------------
    # 4. Function provider receives the actual period.
    # ------------------------------------------------------------

    functional_values =
        ByPeriod(
            t -> 0.05 * t,
        )

    @test GEMB._materialize_template_value(
        functional_values;
        period=4,
        periods=1:4,
    ) == 0.20


    # ------------------------------------------------------------
    # 5. ByPeriod requires repeated-template context.
    # ------------------------------------------------------------

    @test_throws ArgumentError GEMB._materialize_template_value(
        ByPeriod([
            1.0,
        ]);
        period=1,
        position=1,
        periods=nothing,
    )

    @test_throws ArgumentError ByPeriod(
        0 => 1.0,
    )

    @test_throws ArgumentError ByPeriod(
        1 => 1.0,
        1 => 2.0,
    )

    @test_throws ArgumentError ByPeriod(
        1.0,
    )


    # ------------------------------------------------------------
    # 6. Period-varying endowment quantities are materialized before
    #    ordinary endowment-vector expansion.
    # ------------------------------------------------------------

    product =
        CommoditySpec(
            :product;
            axes=(
                period=1:2,
            ),
            price_lower_bound=1.0e-10,
        )

    labor =
        CommoditySpec(
            :labor;
            axes=(
                period=1:2,
            ),
            price_lower_bound=1.0e-10,
        )

    model =
        GEMBModel(
            [
                product,
                labor,
            ];
            numeraire=CommodityRef(
                :product;
                period=1,
            ),
        )

    household =
        AgentTemplate(
            :household,
            CESSpec([1.0]);
            periods=1:2,
            demands=[
                CommodityRef(
                    :product;
                    period=RelativePeriod(0),
                ),
            ],
            endowments=[
                CommodityRef(
                    :labor;
                    period=RelativePeriod(0),
                ) =>
                    ByPeriod([
                        100.0,
                        200.0,
                    ]),
            ],
            activity_start=10.0,
        )

    agents =
        add_agents!(
            model,
            household,
        )

    @test length(agents) == 2

    @test GEM.agent_commodity_indices(
        agents[1],
    ) == [
        1,
        3,
    ]

    @test GEM.agent_commodity_indices(
        agents[2],
    ) == [
        2,
        4,
    ]

    supply1 =
        GEM.agent_net_supply(
            agents[1],
            [10.0],
            ones(2),
        )

    supply2 =
        GEM.agent_net_supply(
            agents[2],
            [10.0],
            ones(2),
        )

    @test supply1 ≈ [
        -10.0,
        100.0,
    ] atol=1.0e-10 rtol=1.0e-10

    @test supply2 ≈ [
        -10.0,
        200.0,
    ] atol=1.0e-10 rtol=1.0e-10


    # ------------------------------------------------------------
    # 7. A ByPeriod error during repeated expansion rolls the model back.
    # ------------------------------------------------------------

    rollback_model =
        GEMBModel(
            [
                product,
                labor,
            ];
            numeraire=CommodityRef(
                :product;
                period=1,
            ),
        )

    bad_household =
        AgentTemplate(
            :badHousehold,
            CESSpec([1.0]);
            periods=1:2,
            demands=[
                CommodityRef(
                    :product;
                    period=RelativePeriod(0),
                ),
            ],
            endowments=[
                CommodityRef(
                    :labor;
                    period=RelativePeriod(0),
                ) =>
                    ByPeriod([
                        100.0,
                    ]),
            ],
            activity_start=10.0,
        )

    @test_throws DimensionMismatch add_agents!(
        rollback_model,
        bad_household,
    )

    @test isempty(rollback_model.agents)
    @test isempty(rollback_model.agent_refs)
end

println("ByPeriod STEP 7A tests passed.")
