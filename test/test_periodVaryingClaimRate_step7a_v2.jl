# ================================================================
# test_periodVaryingClaimRate_step7a_v2.jl
#
# STEP 7A:
# period-varying claim_rate through ByPeriod.
# ================================================================

using Test
using GEM
using GEMB


@testset "Period-varying claim_rate STEP 7A" begin

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

    function producer_template(
        name,
        periods,
        claim_rate,
    )
        return AgentTemplate(
            name,
            CESSpec([1.0]);
            periods=periods,
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
            claim_rate=claim_rate,
            activity_start=10.0,
        )
    end


    # ------------------------------------------------------------
    # 1. Vector provider gives one claim rate per template position.
    # ------------------------------------------------------------

    model =
        fresh_model()

    producers =
        add_agents!(
            model,
            producer_template(
                :producer,
                1:3,
                ByPeriod([
                    0.10,
                    0.20,
                    0.30,
                ]),
            ),
        )

    @test length(producers) == 3

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
                producers[position],
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
    # 2. Non-consecutive template periods still use vector position.
    # ------------------------------------------------------------

    nonconsecutive_model =
        fresh_model()

    nonconsecutive =
        add_agents!(
            nonconsecutive_model,
            producer_template(
                :nonconsecutive,
                [
                    1,
                    3,
                ],
                ByPeriod([
                    0.11,
                    0.33,
                ]),
            ),
        )

    @test GEM.agent_name.(nonconsecutive) == [
        :nonconsecutive__period_i_1,
        :nonconsecutive__period_i_3,
    ]

    @test GEM.agent_net_supply(
        nonconsecutive[1],
        [10.0],
        ones(3),
    ) ≈ [
        10.0,
        -10.0,
        -1.1,
    ] atol=1.0e-10 rtol=1.0e-10

    @test GEM.agent_net_supply(
        nonconsecutive[2],
        [10.0],
        ones(3),
    ) ≈ [
        10.0,
        -10.0,
        -3.3,
    ] atol=1.0e-10 rtol=1.0e-10


    # ------------------------------------------------------------
    # 3. Pair mapping uses actual period labels.
    # ------------------------------------------------------------

    mapped_model =
        fresh_model()

    mapped =
        add_agents!(
            mapped_model,
            producer_template(
                :mapped,
                [
                    1,
                    3,
                ],
                ByPeriod(
                    1 => 0.12,
                    3 => 0.36,
                ),
            ),
        )

    @test GEM.agent_net_supply(
        mapped[1],
        [10.0],
        ones(3),
    )[end] ≈ -1.2 atol=1.0e-10 rtol=1.0e-10

    @test GEM.agent_net_supply(
        mapped[2],
        [10.0],
        ones(3),
    )[end] ≈ -3.6 atol=1.0e-10 rtol=1.0e-10


    # ------------------------------------------------------------
    # 4. Function provider receives actual period.
    # ------------------------------------------------------------

    function_model =
        fresh_model()

    functional =
        add_agents!(
            function_model,
            producer_template(
                :functional,
                1:3,
                ByPeriod(
                    t -> 0.05 * t,
                ),
            ),
        )

    @test [
        GEM.agent_net_supply(
            agent,
            [10.0],
            ones(3),
        )[end]
        for agent in functional
    ] ≈ [
        -0.5,
        -1.0,
        -1.5,
    ] atol=1.0e-10 rtol=1.0e-10


    # ------------------------------------------------------------
    # 5. Scalar claim_rate retains the existing shared-value behavior.
    # ------------------------------------------------------------

    scalar_model =
        fresh_model()

    scalar =
        add_agents!(
            scalar_model,
            producer_template(
                :scalar,
                1:3,
                0.25,
            ),
        )

    @test all(
        agent -> isapprox(
            GEM.agent_net_supply(
                agent,
                [10.0],
                ones(3),
            )[end],
            -2.5;
            atol=1.0e-10,
            rtol=1.0e-10,
        ),
        scalar,
    )


    # ------------------------------------------------------------
    # 6. A raw vector is still NOT interpreted as a period-varying rate.
    # ------------------------------------------------------------

    raw_vector_model =
        fresh_model()

    @test_throws ArgumentError add_agents!(
        raw_vector_model,
        producer_template(
            :rawVector,
            1:3,
            [
                0.10,
                0.20,
                0.30,
            ],
        ),
    )

    @test isempty(raw_vector_model.agents)


    # ------------------------------------------------------------
    # 7. Missing mapping values and vector-length mismatch roll back.
    # ------------------------------------------------------------

    missing_model =
        fresh_model()

    @test_throws ArgumentError add_agents!(
        missing_model,
        producer_template(
            :missing,
            [
                1,
                3,
            ],
            ByPeriod(
                1 => 0.10,
            ),
        ),
    )

    @test isempty(missing_model.agents)

    mismatch_model =
        fresh_model()

    @test_throws DimensionMismatch add_agents!(
        mismatch_model,
        producer_template(
            :mismatch,
            1:3,
            ByPeriod([
                0.10,
                0.20,
            ]),
        ),
    )

    @test isempty(mismatch_model.agents)
end

println("Period-varying claim_rate STEP 7A tests passed.")
