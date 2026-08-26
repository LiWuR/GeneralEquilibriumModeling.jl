# ================================================================
# test_intertemporalPublicAPI_v8.jl
#
# Final public API boundary after STEP 7C2.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "GEMB intertemporal public API V8" begin
    public_names =
        Set(
            names(
                GEMB;
                all=false,
                imported=false,
            ),
        )

    for required in (
        :CommoditySpec,
        :CommodityRef,
        :CommoditySpace,
        :AgentRef,
        :GEMBModel,
        :RelativePeriod,
        :ByPeriod,
        :AgentTemplate,
        :add_agent!,
        :add_agents!,
        :build_model,
    )
        @test required in public_names
    end

    retired_public =
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
        )

    for retired in retired_public
        @test !(retired in public_names)
        @test !isdefined(
            GEMB,
            retired,
        )
    end

    retired_internal_names =
        (
            Symbol(
                "_add_intertemporal_" *
                "agent!",
            ),
            Symbol(
                "_add_intertemporal_" *
                "agents!",
            ),
            Symbol(
                "_intertemporal_" *
                "agent_identity",
            ),
            Symbol(
                "_validate_intertemporal_" *
                "agent_period_domain",
            ),
        )

    for retired_internal in retired_internal_names
        @test !isdefined(
            GEMB,
            retired_internal,
        )
    end


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
                period=1:1,
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

    template =
        AgentTemplate(
            :producer,
            CESSpec([1.0]);
            periods=[1],
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

    template_agents =
        add_agents!(
            model,
            template,
        )

    @test length(
        template_agents,
    ) == 1

    @test model.agent_refs == [
        AgentRef(
            :producer;
            period=1,
        ),
    ]

    direct =
        add_agent!(
            model,
            CESSpec([1.0]);
            name=AgentRef(
                :direct;
                period=1,
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
            activity_start=5.0,
        )

    @test GEM.agent_name(
        direct,
    ) == :direct__period_i_1

    low_model =
        build_model(
            model,
        )

    @test length(
        low_model.agents,
    ) == 2
end

println("GEMB intertemporal public API V8 tests passed.")
