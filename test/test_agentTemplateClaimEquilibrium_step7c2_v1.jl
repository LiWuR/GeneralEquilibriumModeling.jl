# ================================================================
# test_agentTemplateClaimEquilibrium_step7c2_v1.jl
#
# Full-equilibrium regression for dated claims through AgentTemplate
# plus ordinary concrete add_agent!.
# ================================================================

using Test
using GEM
using GEMB


@testset "AgentTemplate claim equilibrium STEP 7C2" begin
    np =
        3

    product =
        CommoditySpec(
            :product;
            axes=(
                type=1:1,
                period=1:np,
            ),
            price_lower_bound=1.0e-10,
        )

    labor =
        CommoditySpec(
            :labor;
            axes=(
                type=1:1,
                period=1:(np - 1),
            ),
            price_lower_bound=1.0e-10,
        )

    claim =
        CommoditySpec(
            :claim;
            axes=(
                type=[:tax],
                period=1:(np - 1),
            ),
            price_lower_bound=1.0e-10,
        )

    producer =
        AgentTemplate(
            :producer,
            CESSpec(
                [
                    0.5,
                    0.5,
                ];
                es=1.0,
                alpha=2.0,
            );
            periods=1:(np - 1),
            demands=[
                CommodityRef(
                    :product;
                    type=1,
                    period=RelativePeriod(0),
                ),
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
            claim_rate=0.10,
            claim=CommodityRef(
                :claim;
                type=:tax,
                period=RelativePeriod(0),
            ),
            activity_start=100.0,
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
                type=1,
                period=1,
            ),
        )

    add_agents!(
        model,
        producer,
    )

    household =
        add_agent!(
            model,
            CESSpec(
                fill(
                    1.0 / np,
                    np,
                );
                es=1.0,
                alpha=1.0,
            );
            name=:household,
            demands=[
                CommodityRef(
                    :product;
                    type=1,
                ),
            ],
            endowments=[
                CommodityRef(
                    :product;
                    type=1,
                    period=1,
                ),
                CommodityRef(
                    :labor;
                    type=1,
                ),
            ],
            endowment_quantities=[
                150.0,
                100.0,
                100.0,
            ],
            activity_start=100.0,
        )

    claim_owner =
        add_agent!(
            model,
            CESSpec(
                fill(
                    1.0 / np,
                    np,
                );
                es=1.0,
                alpha=1.0,
            );
            name=:claimOwner,
            demands=[
                CommodityRef(
                    :product;
                    type=1,
                ),
            ],
            endowments=[
                CommodityRef(
                    :claim;
                    type=:tax,
                ),
            ],
            endowment_quantities=[
                10.0,
                10.0,
            ],
            activity_start=10.0,
        )

    @test household !== nothing
    @test claim_owner !== nothing

    low_model =
        build_model(
            model,
        )

    @test low_model.commodity_names == [
        :product_1_1,
        :product_1_2,
        :product_1_3,
        :labor_1_1,
        :labor_1_2,
        :claim_tax_1,
        :claim_tax_2,
    ]

    @test GEM.agent_name.(low_model.agents) == [
        :producer__period_i_1,
        :producer__period_i_2,
        :household,
        :claimOwner,
    ]

    @test GEM.agent_commodity_indices(
        low_model.agents[1],
    ) == [
        2,
        1,
        4,
        6,
    ]

    @test GEM.agent_commodity_indices(
        low_model.agents[2],
    ) == [
        3,
        2,
        5,
        7,
    ]

    result =
        GEM.solve_equilibrium_model_mcp_jump(
            low_model;
            p0=ones(
                length(
                    low_model.commodity_names,
                ),
            ),
            residual_tol=1.0e-8,
            silent=true,
        )

    @test result.solved

    @test result.prices[1] ≈
          1.0 atol=1.0e-10 rtol=1.0e-10

    @test all(
        result.prices .> 0.0,
    )

    @test result.max_natural_residual <=
          1.0e-7

    @test maximum(
        abs.(
            result.total_net_supply,
        ),
    ) <= 1.0e-7

    @test maximum(
        abs.(
            result.total_net_supply[
                6:7
            ],
        ),
    ) <= 1.0e-7

    @test result.agent_net_supplies[1][end] ≈
          -10.0 atol=1.0e-6 rtol=1.0e-6

    @test result.agent_net_supplies[2][end] ≈
          -10.0 atol=1.0e-6 rtol=1.0e-6


    bad_model =
        GEMBModel(
            [
                product,
                labor,
                claim,
            ];
            numeraire=CommodityRef(
                :product;
                type=1,
                period=1,
            ),
        )

    missing_claim =
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
            claim_rate=0.10,
        )

    @test_throws ArgumentError add_agents!(
        bad_model,
        missing_claim,
    )

    @test isempty(
        bad_model.agents,
    )
end

println("AgentTemplate claim equilibrium STEP 7C2 tests passed.")
