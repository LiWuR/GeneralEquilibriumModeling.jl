# ================================================================
# test_claimInterfaceUserFacingCleanup_v2.jl
#
# Static regression for the final user-facing claim API.
# ================================================================

using Test


@testset "Claim-interface USER-FACING cleanup" begin
    root =
        normpath(
            joinpath(@__DIR__, "..", ".."),
        )

    example_path =
        joinpath(root, "examples", "gemb", "gemb_CES_tax_nc4_na3_v3.jl",
        )

    docs_root =
        joinpath(root, "docs", "src", "gemb", )

    docs_example =
        joinpath(
            docs_root,
            "examples",
            "gemb_CES_tax_nc4_na3_v3.md",
        )

    @test isfile(example_path)
    @test isfile(docs_example)

    @test !isfile(
        joinpath(root, "examples", "gemb", "gemb_CES_tax_nc4_na3_v2.jl",
        ),
    )

    @test !isfile(
        joinpath(
            docs_root,
            "examples",
            "gemb_CES_tax_nc4_na3_v1.md",
        ),
    )

    @test !isfile(
        joinpath(
            docs_root,
            "examples",
            "gemb_CES_tax_nc4_na3_v2.md",
        ),
    )

    example_text =
        read(
            example_path,
            String,
        )

    docs_text =
        read(
            docs_example,
            String,
        )

    combined =
        example_text *
        "\n" *
        docs_text *
        "\n" *
        read(
            joinpath(
                docs_root,
                "index.md",
            ),
            String,
        )

    retired_claim_type =
        "AdValorem" *
        "Claim"

    retired_index_keyword =
        "claim_" *
        "index"

    retired_ticket_underscore =
        "tax" *
        "_ticket"

    retired_ticket_space =
        "tax " *
        "ticket"

    @test !occursin(
        retired_claim_type,
        combined,
    )

    @test !occursin(
        retired_index_keyword,
        combined,
    )

    @test !occursin(
        retired_ticket_underscore,
        lowercase(combined),
    )

    @test !occursin(
        retired_ticket_space,
        lowercase(combined),
    )

    @test occursin(
        "GEMBModel(",
        example_text,
    )

    @test occursin(
        "add_agent!(",
        example_text,
    )

    @test occursin(
        "claim_rate=TAX_RATE",
        example_text,
    )

    @test occursin(
        "claim=CommodityRef(",
        example_text,
    )

    @test occursin(
        "solve(",
        example_text,
    )
end

println("Claim-interface USER-FACING cleanup V2 tests passed.")
