# ================================================================
# test_agentTemplateClaim_step7c2_v1.jl
#
# Dated-claim regression after final AgentTemplate API cleanup.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "AgentTemplate dated claim STEP 7C2" begin

    product =
        CommoditySpec(
            :product;
            axes=(
                type=1:1,
                period=1:3,
            ),
        )

    labor =
        CommoditySpec(
            :labor;
            axes=(
                type=1:1,
                period=1:2,
            ),
        )

    claimCommodity =
        CommoditySpec(
            :claim;
            axes=(
                type=[:tax],
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
                claimCommodity,
            ];
            numeraire=CommodityRef(
                :product;
                type=1,
                period=1,
            ),
        )
    end

    @test fresh_model().commodity_names == [
        :product_1_1,
        :product_1_2,
        :product_1_3,
        :labor_1_1,
        :labor_1_2,
        :claim_tax_1,
        :claim_tax_2,
        :claim_tax_3,
    ]


    # ------------------------------------------------------------
    # 1. Period-varying producer claim rates use one AgentTemplate.
    # ------------------------------------------------------------

    taxedProducer =
        AgentTemplate(
            :taxedProducer,
            CESSpec(
                [1.0];
                es=1.0,
                alpha=1.0,
            );
            periods=1:2,
            demands=[
                CommodityRef(
                    :labor;
                    type=1,
                    period=RelativePeriod(0),
                ),
            ],
            outputs=[
                CommodityRef(
                    :product;
                    type=1,
                    period=RelativePeriod(1),
                ),
            ],
            activity_start=10.0,
            claim_rate=ByPeriod([
                0.1,
                0.2,
            ]),
            claim=CommodityRef(
                :claim;
                type=:tax,
                period=RelativePeriod(0),
            ),
        )

    producer_model =
        fresh_model()

    producerAgents =
        add_agents!(
            producer_model,
            taxedProducer,
        )

    @test length(producerAgents) == 2

    @test producer_model.agent_refs == [
        AgentRef(
            :taxedProducer;
            period=1,
        ),
        AgentRef(
            :taxedProducer;
            period=2,
        ),
    ]

    @test GEM.agent_commodity_indices(
        producerAgents[1],
    ) == [
        2,
        4,
        6,
    ]

    @test GEM.agent_commodity_indices(
        producerAgents[2],
    ) == [
        3,
        5,
        7,
    ]

    @test GEM.agent_net_supply(
        producerAgents[1],
        [10.0],
        ones(3),
    ) ≈ [
        10.0,
        -10.0,
        -1.0,
    ] atol=1.0e-10 rtol=1.0e-10

    @test GEM.agent_net_supply(
        producerAgents[2],
        [10.0],
        ones(3),
    ) ≈ [
        10.0,
        -10.0,
        -2.0,
    ] atol=1.0e-10 rtol=1.0e-10


    # ------------------------------------------------------------
    # 2. One scalar claim rate is reused by repeated agents.
    # ------------------------------------------------------------

    scalarRateProducer =
        AgentTemplate(
            :scalarRate,
            CESSpec([1.0]);
            periods=1:2,
            demands=[
                CommodityRef(
                    :labor;
                    type=1,
                    period=RelativePeriod(0),
                ),
            ],
            outputs=[
                CommodityRef(
                    :product;
                    type=1,
                    period=RelativePeriod(1),
                ),
            ],
            activity_start=10.0,
            claim_rate=0.25,
            claim=CommodityRef(
                :claim;
                type=:tax,
                period=RelativePeriod(0),
            ),
        )

    scalar_model =
        fresh_model()

    scalarRateAgents =
        add_agents!(
            scalar_model,
            scalarRateProducer,
        )

    @test length(scalarRateAgents) == 2

    for agent in scalarRateAgents
        supply =
            GEM.agent_net_supply(
                agent,
                [10.0],
                ones(3),
            )

        @test supply ≈ [
            10.0,
            -10.0,
            -2.5,
        ] atol=1.0e-10 rtol=1.0e-10
    end


    # ------------------------------------------------------------
    # 3. One concrete undated agent uses ordinary add_agent!.
    # ------------------------------------------------------------

    consumerBehavior =
        CESSpec(
            [0.5, 0.5];
            es=1.0,
            alpha=1.0,
        )

    consumer_model =
        fresh_model()

    consumerAgent =
        add_agent!(
            consumer_model,
            consumerBehavior;
            name=:taxedConsumer,
            demands=[
                CommodityRef(
                    :product;
                    type=1,
                    period=1:2,
                ),
            ],
            endowments=[
                CommodityRef(
                    :product;
                    type=1,
                    period=1,
                ),
            ],
            endowment_quantities=[
                100.0,
            ],
            activity_start=10.0,
            claim_rate=0.15,
            claim=CommodityRef(
                :claim;
                type=:tax,
                period=3,
            ),
        )

    @test GEM.agent_commodity_indices(
        consumerAgent,
    ) == [
        1,
        2,
        8,
    ]

    baseDemand =
        activity_demand(
            consumerBehavior,
            10.0,
            ones(2),
        )

    expectedClaim =
        0.15 *
        sum(
            baseDemand,
        )

    consumerSupply =
        GEM.agent_net_supply(
            consumerAgent,
            [10.0],
            ones(3),
        )

    @test consumerSupply ≈ [
        100.0 - baseDemand[1],
        -baseDemand[2],
        -expectedClaim,
    ] atol=1.0e-10 rtol=1.0e-10


    # ------------------------------------------------------------
    # 4. Complete GEMBModel mixes templates and concrete agents.
    # ------------------------------------------------------------

    model =
        fresh_model()

    add_agents!(
        model,
        taxedProducer,
    )

    add_agent!(
        model,
        consumerBehavior;
        name=:taxedConsumer,
        demands=[
            CommodityRef(
                :product;
                type=1,
                period=1:2,
            ),
        ],
        endowments=[
            CommodityRef(
                :product;
                type=1,
                period=1,
            ),
        ],
        endowment_quantities=[
            100.0,
        ],
        activity_start=10.0,
        claim_rate=0.15,
        claim=CommodityRef(
            :claim;
            type=:tax,
            period=3,
        ),
    )

    low_model =
        build_model(
            model,
        )

    @test GEM.agent_name.(low_model.agents) == [
        :taxedProducer__period_i_1,
        :taxedProducer__period_i_2,
        :taxedConsumer,
    ]


    # ------------------------------------------------------------
    # 5. Structural and behavior-specific validation.
    # ------------------------------------------------------------

    validation_model =
        fresh_model()

    missingClaim =
        AgentTemplate(
            :missingClaim,
            CESSpec([1.0]);
            periods=[1],
            demands=[
                CommodityRef(
                    :labor;
                    type=1,
                    period=RelativePeriod(0),
                ),
            ],
            outputs=[
                CommodityRef(
                    :product;
                    type=1,
                    period=RelativePeriod(1),
                ),
            ],
            claim_rate=0.1,
        )

    @test_throws ArgumentError add_agents!(
        validation_model,
        missingClaim,
    )

    @test isempty(
        validation_model.agents,
    )

    @test_throws ArgumentError add_agent!(
        validation_model,
        CESSpec([1.0]);
        name=:missingRate,
        demands=[
            CommodityRef(
                :product;
                type=1,
                period=1,
            ),
        ],
        claim=CommodityRef(
            :claim;
            type=:tax,
            period=1,
        ),
    )

    badRateType =
        AgentTemplate(
            :badRateType,
            CESSpec([1.0]);
            periods=1:2,
            demands=[
                CommodityRef(
                    :labor;
                    type=1,
                    period=RelativePeriod(0),
                ),
            ],
            outputs=[
                CommodityRef(
                    :product;
                    type=1,
                    period=RelativePeriod(1),
                ),
            ],
            claim_rate=[
                0.1,
            ],
            claim=CommodityRef(
                :claim;
                type=:tax,
                period=RelativePeriod(0),
            ),
        )

    @test_throws ArgumentError add_agents!(
        validation_model,
        badRateType,
    )

    multipleClaim =
        AgentTemplate(
            :multipleClaim,
            CESSpec([1.0]);
            periods=[1],
            demands=[
                CommodityRef(
                    :labor;
                    type=1,
                    period=RelativePeriod(0),
                ),
            ],
            outputs=[
                CommodityRef(
                    :product;
                    type=1,
                    period=RelativePeriod(1),
                ),
            ],
            claim_rate=0.1,
            claim=CommodityRef(
                :claim;
                type=:tax,
            ),
        )

    @test_throws ArgumentError add_agents!(
        validation_model,
        multipleClaim,
    )

    @test_throws ArgumentError add_agent!(
        validation_model,
        CESSpec([1.0]);
        name=:relativeClaimWithoutBase,
        demands=[
            CommodityRef(
                :product;
                type=1,
                period=1,
            ),
        ],
        claim_rate=0.1,
        claim=CommodityRef(
            :claim;
            type=:tax,
            period=RelativePeriod(0),
        ),
    )

    @test_throws ArgumentError add_agent!(
        validation_model,
        CESSpec(
            [0.5, 0.5];
            es=1.0,
            alpha=1.0,
        );
        name=:overlap,
        demands=[
            CommodityRef(
                :product;
                type=1,
                period=1:2,
            ),
        ],
        claim_rate=0.1,
        claim=CommodityRef(
            :product;
            type=1,
            period=1,
        ),
    )

    @test isempty(
        validation_model.agents,
    )
end

println("AgentTemplate dated claim STEP 7C2 tests passed.")
