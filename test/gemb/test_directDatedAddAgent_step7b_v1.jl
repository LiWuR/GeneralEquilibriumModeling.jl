# ================================================================
# test_directDatedAddAgent_step7b_v1.jl
#
# STEP 7B:
# ordinary GEMBModel.add_agent! materializes RelativePeriod commodity
# references from a concrete dated AgentRef.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "Direct dated add_agent! STEP 7B" begin

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
    # 1. A concrete dated producer may use RelativePeriod directly
    #    through ordinary add_agent!.
    # ------------------------------------------------------------

    model =
        fresh_model()

    producer =
        add_agent!(
            model,
            CESSpec([1.0]);
            name=AgentRef(
                :producer;
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
            claim=CommodityRef(
                :claim;
                period=RelativePeriod(0),
            ),
            claim_rate=0.20,
            activity_start=10.0,
        )

    @test GEM.agent_name(
        producer,
    ) == :producer__period_i_2

    @test GEM.agent_commodity_indices(
        producer,
    ) == [
        3,
        6,
        9,
    ]

    @test GEM.agent_net_supply(
        producer,
        [10.0],
        ones(3),
    ) ≈ [
        10.0,
        -10.0,
        -2.0,
    ] atol=1.0e-10 rtol=1.0e-10

    @test model.agent_refs == [
        AgentRef(
            :producer;
            period=2,
        ),
    ]


    # ------------------------------------------------------------
    # 2. Direct dated endowments use the same RelativePeriod path.
    # ------------------------------------------------------------

    household =
        add_agent!(
            model,
            CESSpec([1.0]);
            name=AgentRef(
                :household;
                period=2,
            ),
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
                ),
            ],
            endowment_quantities=[
                100.0,
            ],
            activity_start=10.0,
        )

    @test GEM.agent_commodity_indices(
        household,
    ) == [
        2,
        6,
    ]

    @test GEM.agent_net_supply(
        household,
        [10.0],
        ones(2),
    ) ≈ [
        -10.0,
        100.0,
    ] atol=1.0e-10 rtol=1.0e-10


    # ------------------------------------------------------------
    # 3. Absolute CommodityRef values remain unchanged.
    # ------------------------------------------------------------

    absolute_model =
        fresh_model()

    absolute =
        add_agent!(
            absolute_model,
            CESSpec([1.0]);
            name=AgentRef(
                :absolute;
                period=2,
            ),
            demands=[
                CommodityRef(
                    :labor;
                    period=1,
                ),
            ],
            outputs=[
                CommodityRef(
                    :product;
                    period=4,
                ),
            ],
            activity_start=10.0,
        )

    @test GEM.agent_commodity_indices(
        absolute,
    ) == [
        4,
        5,
    ]


    # ------------------------------------------------------------
    # 4. RelativePeriod requires an AgentRef with an absolute period.
    # ------------------------------------------------------------

    no_period_model =
        fresh_model()

    @test_throws ArgumentError add_agent!(
        no_period_model,
        CESSpec([1.0]);
        name=:noPeriod,
        demands=[
            CommodityRef(
                :labor;
                period=RelativePeriod(0),
            ),
        ],
        outputs=[
            CommodityRef(
                :product;
                period=1,
            ),
        ],
    )

    @test isempty(
        no_period_model.agents,
    )

    symbolic_period_model =
        fresh_model()

    @test_throws ArgumentError add_agent!(
        symbolic_period_model,
        CESSpec([1.0]);
        name=AgentRef(
            :symbolicPeriod;
            period=:current,
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
                period=1,
            ),
        ],
    )

    @test isempty(
        symbolic_period_model.agents,
    )


    # ------------------------------------------------------------
    # 5. RelativePeriod is legal only on the :period axis.
    # ------------------------------------------------------------

    region_product =
        CommoditySpec(
            :regionalProduct;
            axes=(
                region=[
                    :east,
                    :west,
                ],
                period=1:2,
            ),
            price_lower_bound=1.0e-10,
        )

    region_model =
        GEMBModel(
            [
                region_product,
            ];
            numeraire=CommodityRef(
                :regionalProduct;
                region=:east,
                period=1,
            ),
        )

    @test_throws ArgumentError add_agent!(
        region_model,
        CESSpec([1.0]);
        name=AgentRef(
            :badAxis;
            period=1,
        ),
        demands=[
            CommodityRef(
                :regionalProduct;
                region=RelativePeriod(0),
                period=1,
            ),
        ],
    )

    @test isempty(
        region_model.agents,
    )


    # ------------------------------------------------------------
    # 6. An out-of-domain relative period fails before model mutation.
    # ------------------------------------------------------------

    out_of_domain_model =
        fresh_model()

    @test_throws ArgumentError add_agent!(
        out_of_domain_model,
        CESSpec([1.0]);
        name=AgentRef(
            :terminalProducer;
            period=3,
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
                period=RelativePeriod(2),
            ),
        ],
    )

    @test isempty(
        out_of_domain_model.agents,
    )
end

println("Direct dated add_agent! STEP 7B tests passed.")
