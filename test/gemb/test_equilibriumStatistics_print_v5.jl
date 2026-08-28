# ================================================================
# test_equilibriumStatistics_print_v5.jl
#
# Focused regression tests for GEMB equilibrium statistics display.
#
# No PATH solve is required.
# ================================================================

using Test
using GeneralEquilibriumModeling


@testset "GEMB equilibrium statistics: display" begin

    model =
        GeneralEquilibriumModeling.GEMB.GEMBModel(
            [:product, :labor, :land];
            numeraire=:product,
        )

    GeneralEquilibriumModeling.GEMB.add_agent!(
        model,
        GeneralEquilibriumModeling.GEMB.CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        name=:firm,
    )

    GeneralEquilibriumModeling.GEMB.add_agent!(
        model,
        GeneralEquilibriumModeling.GEMB.CESSpec([1.0]);
        demands=:product,
        endowments=:land,
        endowment_quantities=[7.0],
        name=GeneralEquilibriumModeling.GEMB.AgentRef(
            :consumer;
            period=1,
        ),
    )

    result =
        GeneralEquilibriumModeling.GEM.EquilibriumResult(
            (
                prices=[
                    2.0,
                    3.0,
                    4.0,
                ],
                agent_net_supplies=[
                    [10.0, -5.0],
                    [-10.0, 7.0],
                ],
                total_net_supply=[
                    0.0,
                    -5.0,
                    7.0,
                ],
            ),
        )

    io =
        IOBuffer()

    returned =
        GeneralEquilibriumModeling.GEMB.print_equilibrium_statistics(
            io,
            model,
            result;
            display_tol=1.0e-10,
            sigdigits=8,
        )

    @test returned === nothing

    output =
        String(
            take!(
                io,
            ),
        )

    @test occursin(
        "GEMB Equilibrium Statistics",
        output,
    )

    @test occursin(
        "Prices",
        output,
    )

    @test occursin(
        "Net supply matrix",
        output,
    )

    @test occursin(
        "Net supply value matrix",
        output,
    )

    @test occursin(
        "Agent net supply values",
        output,
    )

    @test occursin(
        "Total net supply",
        output,
    )

    @test occursin(
        "product",
        output,
    )

    @test occursin(
        "firm",
        output,
    )

    @test occursin(
        "consumer(period=1)",
        output,
    )

    # Display formatting must not mutate stored result data.
    @test result.prices ==
          [2.0, 3.0, 4.0]

    @test result.agent_net_supplies ==
          [
              [10.0, -5.0],
              [-10.0, 7.0],
          ]

    @test_throws ArgumentError GeneralEquilibriumModeling.GEMB.print_equilibrium_statistics(
        IOBuffer(),
        model,
        result;
        display_tol=-1.0,
    )

    @test_throws ArgumentError GeneralEquilibriumModeling.GEMB.print_equilibrium_statistics(
        IOBuffer(),
        model,
        result;
        sigdigits=0,
    )
end


@testset "GEMB equilibrium statistics: display tolerance" begin

    model =
        GeneralEquilibriumModeling.GEMB.GEMBModel(
            [:product];
            numeraire=:product,
        )

    GeneralEquilibriumModeling.GEMB.add_agent!(
        model,
        GeneralEquilibriumModeling.GEMB.CESSpec([1.0]);
        outputs=:product,
        demands=:product,
        name=:agent,
    )

    result =
        GeneralEquilibriumModeling.GEM.EquilibriumResult(
            (
                prices=[
                    1.0,
                ],
                agent_net_supplies=[
                    [1.0e-12],
                ],
                total_net_supply=[
                    1.0e-12,
                ],
            ),
        )

    io =
        IOBuffer()

    GeneralEquilibriumModeling.GEMB.print_equilibrium_statistics(
        io,
        model,
        result;
        display_tol=1.0e-10,
    )

    output =
        String(
            take!(
                io,
            ),
        )

    @test !occursin(
        "1.0e-12",
        output,
    )

    # The underlying data must remain unchanged.
    @test result.agent_net_supplies[1][1] ==
          1.0e-12
end


println("GEMB equilibrium-statistics print tests passed.")
