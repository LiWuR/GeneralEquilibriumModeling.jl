# ================================================================
# test_agentBuilderRouter_userCleanup_v3.jl
#
# Static regression for the final user-facing retirement of the
# keyword-only build_agent compatibility router.
# ================================================================

using Test


const _RETIRED_BUILD_AGENT_USER_PATTERN =
    r"(?s)\bbuild_agent\s*\(\s*;?\s*(spec|marginal_function|demand_function|production_function|production_behavior)\s*="


function _router_user_files(root::String)
    paths =
        String[]

    for directory in (
        joinpath(root, "examples"),
        joinpath(root, "docs", "src"),
    )
        isdir(directory) ||
            continue

        for (
            current_root,
            _,
            names,
        ) in walkdir(directory)
            for name in names
                extension =
                    lowercase(
                        splitext(name)[2],
                    )

                extension in (
                    ".jl",
                    ".md",
                ) ||
                    continue

                push!(
                    paths,
                    joinpath(
                        current_root,
                        name,
                    ),
                )
            end
        end
    end

    return paths
end


@testset "Agent builder router user-facing cleanup" begin
    root =
        normpath(
            joinpath(
                @__DIR__,
                "..",
            ),
        )

    new_example =
        joinpath(
            root,
            "examples",
            "gemb_CES_CET_nc4_na2_v2.jl",
        )

    old_example =
        joinpath(
            root,
            "examples",
            "gemb_CES_CET_nc4_na2_v1.jl",
        )

    new_doc_example =
        joinpath(
            root,
            "docs",
            "src",
            "examples",
            "gemb_CES_CET_nc4_na2_v2.md",
        )

    old_doc_example =
        joinpath(
            root,
            "docs",
            "src",
            "examples",
            "gemb_CES_CET_nc4_na2_v1.md",
        )

    @test isfile(new_example)
    @test !isfile(old_example)
    @test isfile(new_doc_example)
    @test !isfile(old_doc_example)

    example_text =
        read(
            new_example,
            String,
        )

    @test occursin(
        "MarshallDemandConsumerSpec",
        example_text,
    )

    @test !occursin(
        r"\bdemand_function\s*=",
        example_text,
    )

    for path in _router_user_files(root)
        text =
            read(
                path,
                String,
            )

        @test !occursin(
            _RETIRED_BUILD_AGENT_USER_PATTERN,
            text,
        )
    end
end

println("Agent builder router user-facing cleanup V3 tests passed.")
