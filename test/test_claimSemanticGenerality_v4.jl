# ================================================================
# test_claimSemanticGenerality_v4.jl
#
# Regression for the general ad valorem claim semantics.
# ================================================================

using Test
using GEMB


@testset "General ad valorem claim semantics" begin
    root =
        normpath(
            joinpath(
                @__DIR__,
                "..",
            ),
        )

    src_dir =
        joinpath(
            root,
            "src",
        )

    docs_dir =
        joinpath(
            root,
            "docs",
            "src",
        )

    modifier_v3 =
        joinpath(
            src_dir,
            "demand_modifiers_v3.jl",
        )

    modifier_v4 =
        joinpath(
            src_dir,
            "demand_modifiers_v4.jl",
        )

    guide_path =
        joinpath(
            docs_dir,
            "ad_valorem_claims.md",
        )

    index_path =
        joinpath(
            docs_dir,
            "index.md",
        )

    intertemporal_path =
        joinpath(
            docs_dir,
            "intertemporal_equilibrium.md",
        )

    @test !isfile(modifier_v3)
    @test isfile(modifier_v4)
    @test isfile(guide_path)
    @test isfile(index_path)

    modifier_text =
        read(
            modifier_v4,
            String,
        )

    guide_text =
        read(
            guide_path,
            String,
        )

    index_text =
        read(
            index_path,
            String,
        )

    @test !occursin(
        r"\bsubsid(?:y|ies)\b"i,
        modifier_text,
    )

    @test !occursin(
        r"\btax(?:es|ation)?\b"i,
        modifier_text,
    )

    for phrase in (
        "ad valorem claim",
        "economic value base",
        "dividend",
        "interest",
        "ad valorem tax revenue",
        "monopoly rent",
        "transaction fee",
        "Tax certificates",
        "stocks",
        "bonds",
        "money",
        "economic ownership",
    )
        @test occursin(
            lowercase(phrase),
            lowercase(guide_text),
        )
    end

    @test occursin(
        "claim_rate",
        guide_text,
    )

    @test occursin(
        "claim=CommodityRef(:claim)",
        guide_text,
    )

    @test occursin(
        "solve_asset_equilibrium_amsd",
        guide_text,
    )

    @test occursin(
        "Ad valorem claims",
        index_text,
    )

    @test !occursin(
        "claims for taxes, subsidies, and related instruments",
        lowercase(index_text),
    )

    if isfile(
        intertemporal_path,
    )
        intertemporal_text =
            read(
                intertemporal_path,
                String,
            )

        normalized_intertemporal =
            lowercase(
                replace(
                    strip(intertemporal_text),
                    r"\\s+" =>
                        " ",
                ),
            )

        @test occursin(
            "tax application",
            normalized_intertemporal,
        )

        @test occursin(
            "not limited to taxation",
            normalized_intertemporal,
        )

        # Tax-specific selectors remain valid examples of one concrete claim form.
        @test occursin(
            "type=:tax",
            intertemporal_text,
        )
    end
end

println("General ad valorem claim semantic V4 tests passed.")
