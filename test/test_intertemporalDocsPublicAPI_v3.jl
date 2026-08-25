# ================================================================
# test_intertemporalDocsPublicAPI_v3.jl
#
# Final documentation boundary after AgentTemplate cleanup.
# ================================================================

using Test


@testset "Intertemporal docs public API V3" begin
    package_root =
        normpath(
            joinpath(
                @__DIR__,
                "..",
            ),
        )

    docs_root =
        joinpath(
            package_root,
            "docs",
            "src",
        )

    index_path =
        joinpath(
            docs_root,
            "index.md",
        )

    guide_path =
        joinpath(
            docs_root,
            "intertemporal_equilibrium.md",
        )

    @test isfile(index_path)
    @test isfile(guide_path)

    docs_text =
        read(
            index_path,
            String,
        ) *
        "\n" *
        read(
            guide_path,
            String,
        )

    for required in (
        "GEMBModel",
        "AgentTemplate",
        "add_agent!",
        "add_agents!",
        "RelativePeriod",
        "ByPeriod",
        "build_model",
    )
        @test occursin(
            required,
            docs_text,
        )
    end

    retired_names =
        (
            "Intertemporal" *
                "AgentSpec",
            "add_intertemporal_" *
                "agent!",
            "add_intertemporal_" *
                "agents!",
        )

    roots =
        (
            joinpath(
                package_root,
                "examples",
            ),
            docs_root,
        )

    for root in roots
        isdir(
            root,
        ) ||
            continue

        for (
            directory,
            _,
            files,
        ) in walkdir(
            root,
        )
            for filename in files
                extension =
                    lowercase(
                        splitext(
                            filename,
                        )[2],
                    )

                extension in (
                    ".jl",
                    ".md",
                ) ||
                    continue

                text =
                    read(
                        joinpath(
                            directory,
                            filename,
                        ),
                        String,
                    )

                for retired in retired_names
                    @test !occursin(
                        retired,
                        text,
                    )
                end
            end
        end
    end

    @test occursin(
        "AgentTemplate",
        read(
            joinpath(
                package_root,
                "examples",
                "gemb_intertemporalEquilibriumCESClaim_nct3_nat3_v3.jl",
            ),
            String,
        ),
    )

    @test occursin(
        "add_agent!",
        read(
            joinpath(
                package_root,
                "examples",
                "gemb_intertemporalEquilibriumCES_nct2_nat2_v5.jl",
            ),
            String,
        ),
    )
end

println("Intertemporal docs public API V3 tests passed.")
