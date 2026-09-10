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

    @test !occursin(
        "\nAgent net supply values\n",
        output,
    )

    @test !occursin(
        "\nTotal net supply\n",
        output,
    )

    # Sums are now integrated into the two matrix displays.
    @test count(
        "Sum",
        output,
    ) >= 3

    # Net-supply quantity totals by commodity are displayed in the
    # rightmost column.
    @test occursin(
        "7.0",
        output,
    )

    # The net-supply value matrix includes the agent totals
    # firm = 5 and consumer = 8, plus the grand total 13.
    @test occursin(
        "5.0",
        output,
    )

    @test occursin(
        "8.0",
        output,
    )

    @test occursin(
        "13.0",
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
    # Matrix displays can be suppressed for large models.
    compact_io =
        IOBuffer()

    compact_returned =
        GeneralEquilibriumModeling.GEMB.print_equilibrium_statistics(
            compact_io,
            model,
            result;
            show_matrices=false,
        )

    @test compact_returned === nothing

    compact_output =
        String(
            take!(
                compact_io,
            ),
        )

    @test occursin(
        "GEMB Equilibrium Statistics",
        compact_output,
    )

    @test occursin(
        "Prices",
        compact_output,
    )

    @test occursin(
        "Activity levels",
        compact_output,
    )

    @test !occursin(
        "Net supply matrix",
        compact_output,
    )

    @test !occursin(
        "Net supply value matrix",
        compact_output,
    )

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
