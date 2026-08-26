# ================================================================
# test_byPeriodEndowmentValidation_step7a_v2.jl
#
# STEP 7A fix:
# distinguish template-declaration validation from concrete-instance
# endowment validation.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "ByPeriod endowment validation STEP 7A" begin
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

    function fresh_model()
        return GEMBModel(
            [
                product,
                labor,
            ];
            numeraire=CommodityRef(
                :product;
                period=1,
            ),
        )
    end


    # ------------------------------------------------------------
    # 1. ByPeriod is legal at template declaration time.
    # ------------------------------------------------------------

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

    @test household.endowments[1].second isa ByPeriod


    # ------------------------------------------------------------
    # 2. Concrete quantities are validated only after ByPeriod
    #    materialization during repeated-agent expansion.
    # ------------------------------------------------------------

    model =
        fresh_model()

    agents =
        add_agents!(
            model,
            household,
        )

    @test length(agents) == 2

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
    # 3. A plain invalid quantity is still rejected immediately.
    # ------------------------------------------------------------

    @test_throws ArgumentError AgentTemplate(
        :badPlain,
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
            ) => :invalid,
        ],
    )


    # ------------------------------------------------------------
    # 4. An invalid concrete value produced by ByPeriod is rejected
    #    during expansion, and the model rolls back transactionally.
    # ------------------------------------------------------------

    bad_template =
        AgentTemplate(
            :badTemplate,
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
                    ByPeriod(
                        t -> t == 1 ? 100.0 : :invalid,
                    ),
            ],
        )

    rollback_model =
        fresh_model()

    @test_throws ArgumentError add_agents!(
        rollback_model,
        bad_template,
    )

    @test isempty(rollback_model.agents)
    @test isempty(rollback_model.agent_refs)
end

println("ByPeriod endowment validation STEP 7A tests passed.")
