# ================================================================
# test_agentTemplateEndowmentHelper_step7c2_v1.jl
#
# Final template endowment-helper regression.
# ================================================================

using Test
using GEM
using GEMB


@testset "AgentTemplate endowment helper STEP 7C2" begin
    product =
        CommoditySpec(
            :product;
            axes=(
                type=1:1,
                period=1:3,
            ),
            price_lower_bound=1.0e-10,
        )

    labor =
        CommoditySpec(
            :labor;
            axes=(
                type=1:1,
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
                type=1,
                period=1,
            ),
        )

    refs,
    quantities =
        GEMB._materialize_agent_template_endowments(
            model,
            [
                CommodityRef(
                    :product;
                    type=1,
                    period=1,
                ) => 100.0,
                CommodityRef(
                    :labor;
                    type=1,
                ) => [
                    60.0,
                    65.0,
                ],
            ],
        )

    @test refs == [
        CommodityRef(
            :product;
            type=1,
            period=1,
        ),
        CommodityRef(
            :labor;
            type=1,
        ),
    ]

    @test quantities == [
        100.0,
        60.0,
        65.0,
    ]

    relative_endowments = [
        CommodityRef(
            :labor;
            type=1,
            period=RelativePeriod(0),
        ) => 10.0,
    ]

    @test_throws ArgumentError GEMB._materialize_agent_template_endowments(
        model,
        relative_endowments,
    )

    relative_refs,
    relative_quantities =
        GEMB._materialize_agent_template_endowments(
            model,
            relative_endowments;
            agent_ref=AgentRef(
                :household;
                period=2,
            ),
            period=2,
        )

    @test relative_refs == [
        CommodityRef(
            :labor;
            type=1,
            period=2,
        ),
    ]

    @test relative_quantities == [
        10.0,
    ]
end

println("AgentTemplate endowment helper STEP 7C2 tests passed.")
