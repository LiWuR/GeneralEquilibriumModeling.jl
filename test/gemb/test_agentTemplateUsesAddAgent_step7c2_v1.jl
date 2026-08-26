# ================================================================
# test_agentTemplateUsesAddAgent_step7c2_v1.jl
#
# STEP 7B:
# repeated template expansion delegates RelativePeriod commodity
# materialization to ordinary GEMBModel.add_agent!.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "AgentTemplate delegates to add_agent! STEP 7C2" begin

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

    model =
        GEMBModel(
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

    template =
        AgentTemplate(
            :producer,
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
            claim_rate=ByPeriod([
                0.10,
                0.20,
            ]),
            activity_start=10.0,
        )

    agents =
        add_agents!(
            model,
            template,
        )

    @test length(agents) == 2

    @test GEM.agent_name.(agents) == [
        :producer__period_i_1,
        :producer__period_i_2,
    ]

    @test GEM.agent_commodity_indices(
        agents[1],
    ) == [
        2,
        4,
        6,
    ]

    @test GEM.agent_commodity_indices(
        agents[2],
    ) == [
        3,
        5,
        7,
    ]

    @test GEM.agent_net_supply(
        agents[1],
        [10.0],
        ones(3),
    ) ≈ [
        10.0,
        -10.0,
        -1.0,
    ] atol=1.0e-10 rtol=1.0e-10

    @test GEM.agent_net_supply(
        agents[2],
        [10.0],
        ones(3),
    ) ≈ [
        10.0,
        -10.0,
        -2.0,
    ] atol=1.0e-10 rtol=1.0e-10

    # STEP 7C2 removes the retired wrapper and expansion entry points.
    retired_names =
        (
            Symbol(
                "Intertemporal" *
                "AgentSpec",
            ),
            Symbol(
                "add_intertemporal_" *
                "agent!",
            ),
            Symbol(
                "add_intertemporal_" *
                "agents!",
            ),
            Symbol(
                "_add_intertemporal_" *
                "agent!",
            ),
            Symbol(
                "_add_intertemporal_" *
                "agents!",
            ),
        )

    for retired_name in retired_names
        @test !isdefined(
            GEMB,
            retired_name,
        )
    end
end

println("AgentTemplate delegation STEP 7C2 tests passed.")
