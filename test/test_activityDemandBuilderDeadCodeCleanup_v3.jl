# ================================================================
# test_activityDemandBuilderDeadCodeCleanup_v3.jl
#
# Focused regression for activity_demand_agent_builder_v6.jl.
# ================================================================

using Test
using GEM
using GEMB


const _RETIRED_ACTIVITY_HELPERS = (
    "_generic_linear_activity_condition_function",
    "_activity_producer_condition_function",
    "_generic_linear_claim_activity_condition_function",
    "_ces_activity_condition_function",
    "_dces_activity_condition_function",
    "_dces_unit_loss_numeric",
    "_cap_numeric",
)


@testset "Activity-demand builder dead-code cleanup" begin
    root =
        normpath(
            joinpath(
                @__DIR__,
                "..",
            ),
        )

    builder_path =
        joinpath(
            root,
            "src",
            "activity_demand_agent_builder_v6.jl",
        )

    gemb_path =
        joinpath(
            root,
            "src",
            "GEMB.jl",
        )

    @test isfile(builder_path)
    @test !isfile(
        joinpath(
            root,
            "src",
            "activity_demand_agent_builder_v4.jl",
        ),
    )

    builder =
        read(
            builder_path,
            String,
        )

    gemb_source =
        read(
            gemb_path,
            String,
        )

    @test occursin(
        "include(\"activity_demand_agent_builder_v6.jl\")",
        gemb_source,
    )

    @test !occursin(
        "include(\"activity_demand_agent_builder_v4.jl\")",
        gemb_source,
    )

    retired_unit_loss_keyword =
        "unit_" *
        "loss_" *
        "cap"

    @test !occursin(
        retired_unit_loss_keyword,
        builder,
    )

    for helper in _RETIRED_ACTIVITY_HELPERS
        @test !occursin(
            helper,
            builder,
        )
    end

    # Generic activity-demand producer still uses UnitProfitConditions.
    generic_spec =
        ActivityDemandSpec(
            (activity, prices) -> [
                activity / prices[1],
            ],
        )

    generic_firm =
        build_agent(
            generic_spec;
            output_indices=[1],
            output_coefficients=[1.0],
            demand_indices=[2],
            activity_start=10.0,
            name=:generic_firm,
        )

    @test GEM.agent_condition_rule(
        generic_firm,
    ) isa GEM.UnitProfitConditions

    # A custom explicit producer condition remains supported.
    custom_spec =
        ActivityDemandSpec(
            (activity, prices) -> [
                activity / prices[1],
            ];
            producer_condition_function=(
                local_variables,
                local_prices,
                net_supply,
            ) -> [
                7.0,
            ],
        )

    custom_firm =
        build_agent(
            custom_spec;
            output_indices=[1],
            output_coefficients=[1.0],
            demand_indices=[2],
            activity_start=10.0,
            name=:custom_firm,
        )

    @test GEM.agent_condition_rule(
        custom_firm,
    ) isa GEM.ExplicitAgentConditions

    # Displaced CES still defaults to TotalProfitConditions.
    displaced =
        build_agent(
            DCESSpec(
                [1.0];
                es=1.0,
                alpha=1.0,
                xi=[1.0],
            );
            output_indices=[1],
            output_coefficients=[1.0],
            demand_indices=[2],
            activity_start=10.0,
            name=:displaced,
        )

    @test GEM.agent_condition_rule(
        displaced,
    ) isa GEM.TotalProfitConditions

    # Claim construction remains on the ordinary net-supply path.
    claimed =
        build_agent(
            CESSpec(
                [1.0];
                es=1.0,
                alpha=1.0,
            );
            output_indices=[1],
            output_coefficients=[1.0],
            demand_indices=[2],
            claim_rate=0.1,
            claim_index=3,
            activity_start=10.0,
            name=:claimed,
        )

    @test claimed isa GEM.NetSupplyAgent
    @test GEM.agent_condition_rule(
        claimed,
    ) isa GEM.UnitProfitConditions
end

println("Activity-demand builder dead-code cleanup tests passed.")
