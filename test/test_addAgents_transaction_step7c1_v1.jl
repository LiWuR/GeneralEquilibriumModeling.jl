# ================================================================
# test_addAgents_transaction_step7c1_v1.jl
#
# STEP 7C1:
# transactional add_agents! behavior for one and several templates.
# ================================================================

using Test
using GEM
using GEMB


@testset "add_agents! transaction STEP 7C1" begin

    product =
        CommoditySpec(
            :product;
            axes=(
                period=1:3,
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

    claim =
        CommoditySpec(
            :claim;
            axes=(
                period=1:2,
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

    function template(
        name,
        rate,
    )
        return AgentTemplate(
            name,
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
            claim=CommodityRef(
                :claim;
                period=RelativePeriod(0),
            ),
            claim_rate=rate,
            activity_start=10.0,
        )
    end


    # ------------------------------------------------------------
    # 1. Several templates are expanded in one transaction.
    # ------------------------------------------------------------

    model =
        fresh_model()

    templates =
        [
            template(
                :producerA,
                ByPeriod([
                    0.10,
                    0.20,
                ]),
            ),
            template(
                :producerB,
                ByPeriod([
                    0.30,
                    0.40,
                ]),
            ),
        ]

    agents =
        add_agents!(
            model,
            templates,
        )

    @test length(agents) == 4
    @test length(model.agents) == 4

    @test GEM.agent_name.(agents) == [
        :producerA__period_i_1,
        :producerA__period_i_2,
        :producerB__period_i_1,
        :producerB__period_i_2,
    ]


    # ------------------------------------------------------------
    # 2. Failure in a later template rolls back the full batch.
    # ------------------------------------------------------------

    rollback_model =
        fresh_model()

    good =
        template(
            :good,
            ByPeriod([
                0.10,
                0.20,
            ]),
        )

    bad =
        template(
            :bad,
            ByPeriod([
                0.30,
            ]),
        )

    @test_throws DimensionMismatch add_agents!(
        rollback_model,
        [
            good,
            bad,
        ],
    )

    @test isempty(
        rollback_model.agents,
    )

    @test isempty(
        rollback_model.agent_refs,
    )

    @test isempty(
        rollback_model.agent_index,
    )

    @test isempty(
        rollback_model.agent_ref_index,
    )


    # ------------------------------------------------------------
    # 3. Period-domain validation occurs before mutation.
    # ------------------------------------------------------------

    domain_model =
        fresh_model()

    outside =
        AgentTemplate(
            :outside,
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
        )

    @test_throws ArgumentError add_agents!(
        domain_model,
        outside,
    )

    @test isempty(
        domain_model.agents,
    )
end

println("add_agents! transaction STEP 7C1 tests passed.")
