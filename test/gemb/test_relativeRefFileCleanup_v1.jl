# ================================================================
# test_relativeRefFileCleanup_v1.jl
#
# File-boundary regression after renaming the two remaining
# intertemporal_* reference extensions to relative_* names.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "Relative reference file cleanup" begin
    root =
        normpath(
            joinpath(@__DIR__, "..", ".."),
        )

    src_dir =
        joinpath(root, "src", "GEMB", )

    entry_path =
        joinpath(
            src_dir,
            "GEMB.jl",
        )

    entry =
        read(
            entry_path,
            String,
        )

    @test occursin(
        "include(\"relative_agent_variable_refs_v1.jl\")",
        entry,
    )

    @test occursin(
        "include(\"relative_commodity_refs_v1.jl\")",
        entry,
    )

    @test !occursin(
        "include(\"intertemporal_agent_variable_refs_v1.jl\")",
        entry,
    )

    @test !occursin(
        "include(\"intertemporal_commodity_refs_v1.jl\")",
        entry,
    )

    @test isfile(
        joinpath(
            src_dir,
            "relative_agent_variable_refs_v1.jl",
        ),
    )

    @test isfile(
        joinpath(
            src_dir,
            "relative_commodity_refs_v1.jl",
        ),
    )

    @test !isfile(
        joinpath(
            src_dir,
            "intertemporal_agent_variable_refs_v1.jl",
        ),
    )

    @test !isfile(
        joinpath(
            src_dir,
            "intertemporal_commodity_refs_v1.jl",
        ),
    )


    # Functional smoke test: both relative-reference extensions remain active.
    model =
        GEMBModel(
            [
                CommoditySpec(
                    :product;
                    axes=(
                        period=1:3,
                    ),
                    price_lower_bound=1.0e-10,
                ),
                CommoditySpec(
                    :labor;
                    axes=(
                        period=1:2,
                    ),
                    price_lower_bound=1.0e-10,
                ),
            ];
            numeraire=CommodityRef(
                :product;
                period=1,
            ),
        )

    add_agent!(
        model,
        CESSpec([1.0]);
        name=AgentRef(
            :firm;
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
        activity_start=10.0,
    )

    observer =
        add_agent!(
            model,
            CESSpec([1.0]);
            name=AgentRef(
                :observer;
                period=2,
            ),
            demands=[
                CommodityRef(
                    :labor;
                    period=RelativePeriod(-1),
                ),
            ],
            outputs=[
                CommodityRef(
                    :product;
                    period=RelativePeriod(0),
                ),
            ],
            observed_variables=[
                agent_variable_ref(
                    AgentRef(
                        :firm;
                        period=RelativePeriod(-1),
                    ),
                    :activity,
                ),
            ],
            activity_start=10.0,
        )

    @test GEM.agent_observed_variables(
        observer,
    ) == [
        GEM.AgentVariableRef(
            :firm__period_i_1,
            :activity,
        ),
    ]
end

println("Relative reference file cleanup tests passed.")
