# ================================================================
# test_agentTemplate_step7c1_v1.jl
#
# STEP 7C1:
# strict AgentTemplate semantics and add_agents! expansion.
# ================================================================

using Test
using GEM
using GEMB


@testset "AgentTemplate STEP 7C1" begin

    product =
        CommoditySpec(
            :product;
            axes=(
                period=1:4,
            ),
            price_lower_bound=1.0e-10,
        )

    labor =
        CommoditySpec(
            :labor;
            axes=(
                period=1:3,
            ),
            price_lower_bound=1.0e-10,
        )

    claim =
        CommoditySpec(
            :claim;
            axes=(
                period=1:3,
            ),
            price_lower_bound=-Inf,
            price_upper_bound=Inf,
        )

    function fresh_model()
        return GEMBModel(
            [
                product,
                labor,
                claim,
            ];
            numeraire=CommodityRef(
                :product;
                period=1,
            ),
        )
    end


    # ------------------------------------------------------------
    # 1. AgentTemplate requires periods and forbids a base period.
    # ------------------------------------------------------------

    @test_throws UndefKeywordError AgentTemplate(
        :missingPeriods,
        CESSpec([1.0]);
        demands=[
            CommodityRef(
                :labor;
                period=1,
            ),
        ],
        outputs=[
            CommodityRef(
                :product;
                period=2,
            ),
        ],
    )

    @test_throws ArgumentError AgentTemplate(
        :nothingPeriods,
        CESSpec([1.0]);
        periods=nothing,
        demands=[
            CommodityRef(
                :labor;
                period=1,
            ),
        ],
        outputs=[
            CommodityRef(
                :product;
                period=2,
            ),
        ],
    )

    @test_throws ArgumentError AgentTemplate(
        AgentRef(
            :datedBase;
            period=1,
        ),
        CESSpec([1.0]);
        periods=1:2,
        demands=[
            CommodityRef(
                :labor;
                period=RelativePeriod(0),
            ),
        ],
        outputs=[
            CommodityRef(
                :product;
                period=RelativePeriod(1),
            ),
        ],
    )


    # ------------------------------------------------------------
    # 2. Repeated template expansion preserves non-period selectors.
    # ------------------------------------------------------------

    template =
        AgentTemplate(
            AgentRef(
                :producer;
                region=:east,
            ),
            CESSpec([1.0]);
            periods=1:3,
            demands=[
                CommodityRef(
                    :labor;
                    period=RelativePeriod(0),
                ),
            ],
            outputs=[
                CommodityRef(
                    :product;
                    period=RelativePeriod(1),
                ),
            ],
            claim=CommodityRef(
                :claim;
                period=RelativePeriod(0),
            ),
            claim_rate=ByPeriod([
                0.10,
                0.20,
                0.30,
            ]),
            activity_start=10.0,
        )

    model =
        fresh_model()

    agents =
        add_agents!(
            model,
            template,
        )

    @test length(agents) == 3

    @test model.agent_refs == [
        AgentRef(
            :producer;
            region=:east,
            period=1,
        ),
        AgentRef(
            :producer;
            region=:east,
            period=2,
        ),
        AgentRef(
            :producer;
            region=:east,
            period=3,
        ),
    ]

    @test GEM.agent_name.(agents) == [
        :producer__period_i_1__region_s_east,
        :producer__period_i_2__region_s_east,
        :producer__period_i_3__region_s_east,
    ]

    for (
        position,
        expected_rate,
    ) in enumerate([
        0.10,
        0.20,
        0.30,
    ])
        supply =
            GEM.agent_net_supply(
                agents[position],
                [10.0],
                ones(3),
            )

        @test supply ≈ [
            10.0,
            -10.0,
            -10.0 * expected_rate,
        ] atol=1.0e-10 rtol=1.0e-10
    end


    # ------------------------------------------------------------
    # 3. Non-consecutive periods use template position for vector ByPeriod.
    # ------------------------------------------------------------

    nonconsecutive_model =
        fresh_model()

    nonconsecutive_template =
        AgentTemplate(
            :nonconsecutive,
            CESSpec([1.0]);
            periods=[
                1,
                3,
            ],
            demands=[
                CommodityRef(
                    :labor;
                    period=RelativePeriod(0),
                ),
            ],
            outputs=[
                CommodityRef(
                    :product;
                    period=RelativePeriod(1),
                ),
            ],
            claim=CommodityRef(
                :claim;
                period=RelativePeriod(0),
            ),
            claim_rate=ByPeriod([
                0.11,
                0.33,
            ]),
            activity_start=10.0,
        )

    nonconsecutive =
        add_agents!(
            nonconsecutive_model,
            nonconsecutive_template,
        )

    @test GEM.agent_name.(nonconsecutive) == [
        :nonconsecutive__period_i_1,
        :nonconsecutive__period_i_3,
    ]

    @test GEM.agent_net_supply(
        nonconsecutive[1],
        [10.0],
        ones(3),
    )[end] ≈ -1.1 atol=1.0e-10 rtol=1.0e-10

    @test GEM.agent_net_supply(
        nonconsecutive[2],
        [10.0],
        ones(3),
    )[end] ≈ -3.3 atol=1.0e-10 rtol=1.0e-10


    # ------------------------------------------------------------
    # 4. One concrete dated agent belongs in ordinary add_agent!.
    # ------------------------------------------------------------

    direct_model =
        fresh_model()

    direct_agent =
        add_agent!(
            direct_model,
            CESSpec([1.0]);
            name=AgentRef(
                :direct;
                period=2,
            ),
            demands=[
                CommodityRef(
                    :labor;
                    period=RelativePeriod(0),
                ),
            ],
            outputs=[
                CommodityRef(
                    :product;
                    period=RelativePeriod(1),
                ),
            ],
            activity_start=10.0,
        )

    @test GEM.agent_name(
        direct_agent,
    ) == :direct__period_i_2

    @test direct_model.agent_refs == [
        AgentRef(
            :direct;
            period=2,
        ),
    ]
end

println("AgentTemplate STEP 7C1 tests passed.")
