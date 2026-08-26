# ================================================================
# test_exogenousLandPrice_virtualAgent_v1.jl
#
# Focused regression for the high-level virtual-agent representation
# of the exogenous-land-price closure.
# ================================================================

using Test

@testset "GEMB virtual-agent auxiliary-equivalent closure" begin
    include(
        joinpath(
            @__DIR__,
            "..",
            "examples",
            "gemb_exogenousLandPrice_virtualAgent_nc3_na3_v1.jl",
        ),
    )

    @test result.solved

    @test isapprox(
        result.prices,
        [2.0, 1.0, 4.0];
        atol=1.0e-7,
        rtol=1.0e-7,
    )

    @test isapprox(
        producer_activity,
        100.0;
        atol=1.0e-7,
        rtol=1.0e-7,
    )

    @test isapprox(
        land_supply,
        25.0;
        atol=1.0e-7,
        rtol=1.0e-7,
    )

    @test maximum(abs, result.total_net_supply) <= 1.0e-7
    @test result.max_natural_residual <= 1.0e-7

    gem_model = build_model(model)

    @test isempty(GEM.auxiliary_variables(gem_model))
    @test isempty(GEM.auxiliary_equations(gem_model))
end

println("Virtual-agent exogenous-land-price validation passed.")
