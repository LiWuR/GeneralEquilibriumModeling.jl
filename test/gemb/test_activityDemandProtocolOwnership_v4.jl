# ================================================================
# test_activityDemandProtocolOwnership_v4.jl
#
# Verify that activity-demand behavior is owned by the specification layer,
# while the builder owns validation and GEM agent assembly.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "Activity-demand protocol ownership V4" begin
    root =
        normpath(
            joinpath(@__DIR__, "..", ".."),
        )

    specs_path =
        joinpath(root, "src", "GEMB", "activity_demand_specs_v5.jl",
        )

    builder_path =
        joinpath(root, "src", "GEMB", "activity_demand_agent_builder_v6.jl",
        )

    @test isfile(specs_path)
    @test isfile(builder_path)

    @test !isfile(
        joinpath(root, "src", "GEMB", "activity_demand_specs_v4.jl",
        ),
    )

    specs =
        replace(
            read(
                specs_path,
                String,
            ),
            "\r\n" => "\n",
        )

    builder =
        replace(
            read(
                builder_path,
                String,
            ),
            "\r\n" => "\n",
        )

    @test occursin(
        "function _call_activity_demand_function(",
        specs,
    )

    @test occursin(
        "function activity_demand(",
        specs,
    )

    @test occursin(
        r"(?m)^[ \t]*activity_demand,[ \t]*$",
        specs,
    )

    @test !occursin(
        "function _call_activity_demand_function(",
        builder,
    )

    @test !occursin(
        "function activity_demand(",
        builder,
    )

    @test !occursin(
        r"export\s+activity_demand",
        builder,
    )

    @test occursin(
        "function _check_activity_demand_dimension(",
        builder,
    )

    @test occursin(
        "function build_agent(",
        builder,
    )

    custom =
        ActivityDemandSpec(
            (activity, prices) -> [
                activity / prices[1],
            ],
        )

    @test isapprox(
        activity_demand(
            custom,
            10.0,
            [2.0],
        ),
        [5.0];
        atol=1.0e-12,
        rtol=1.0e-12,
    )

    ces =
        CESSpec(
            [1.0];
            es=1.0,
            alpha=1.0,
        )

    # With one CES input, beta = 1 and alpha = 1 imply y = x.
    # Hence activity 10 requires 10 physical units of the input; the
    # input price affects cost, not the physical conditional demand.
    @test isapprox(
        activity_demand(
            ces,
            10.0,
            [2.0],
        ),
        [10.0];
        atol=1.0e-12,
        rtol=1.0e-12,
    )

    firm =
        build_agent(
            ces;
            output_indices=[1],
            output_coefficients=[1.0],
            demand_indices=[2],
            activity_start=10.0,
            name=:firm,
        )

    @test firm isa GEM.NetSupplyAgent

    @test GEM.agent_condition_rule(
        firm,
    ) isa GEM.UnitRevenueExpenditureBalanceConditions
end

println("Activity-demand protocol ownership V4 tests passed.")
