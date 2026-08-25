# ================================================================
# test_gembModel_commodityRefStep4_v1.jl
#
# CommoditySpace integration STEP 4 for GEMBModel.
#
# This test verifies the unified Symbol / CommodityRef resolution path.
# RelativePeriod remains outside GEMBModel in this step.
# ================================================================

using Test
using GEM
using GEMB


@testset "GEMBModel CommodityRef STEP 4" begin

    # ------------------------------------------------------------
    # 1. Structured model and selector resolution.
    # ------------------------------------------------------------

    model = GEMBModel(
        [
            CommoditySpec(
                :product;
                axes=(type=1:2,),
            ),
            :labor,
            CommoditySpec(
                :claim;
                axes=(period=1:2,),
            ),
        ];
        numeraire=CommodityRef(
            :product;
            type=1,
        ),
    )

    @test model.commodity_names == [
        :product_1,
        :product_2,
        :labor,
        :claim_1,
        :claim_2,
    ]

    # The selected CommodityRef is stored as the canonical flat name.
    @test model.numeraire == :product_1

    # Group Symbol is shorthand for CommodityRef(:product).
    @test GEMB._resolve_commodities(
        model,
        :product,
    ) == [1, 2]

    # Flat Symbol remains a compatibility fallback.
    @test GEMB._resolve_commodities(
        model,
        :product_1,
    ) == [1]

    @test GEMB._resolve_commodities(
        model,
        CommodityRef(
            :product;
            type=2,
        ),
    ) == [2]

    @test GEMB._resolve_commodities(
        model,
        CommodityRef(:product),
    ) == [1, 2]

    @test GEMB._resolve_commodities(
        model,
        [
            CommodityRef(
                :product;
                type=2,
            ),
            :labor,
            CommodityRef(
                :claim;
                period=1,
            ),
        ],
    ) == [2, 3, 4]


    # ------------------------------------------------------------
    # 2. Vector selector-block order is preserved.
    # ------------------------------------------------------------

    @test GEMB._resolve_commodities(
        model,
        [
            CommodityRef(
                :product;
                type=2,
            ),
            CommodityRef(
                :product;
                type=1,
            ),
        ],
    ) == [2, 1]


    # ------------------------------------------------------------
    # 3. Overlapping selections are rejected.
    # ------------------------------------------------------------

    @test_throws ArgumentError GEMB._resolve_commodities(
        model,
        [
            :product,
            CommodityRef(
                :product;
                type=1,
            ),
        ],
    )

    @test_throws ArgumentError GEMB._resolve_commodities(
        model,
        [
            :labor,
            :labor,
        ],
    )


    # ------------------------------------------------------------
    # 4. Unknown and unsupported selectors fail clearly.
    # ------------------------------------------------------------

    @test_throws ArgumentError GEMB._resolve_commodities(
        model,
        :unknown,
    )

    @test_throws ArgumentError GEMB._resolve_commodities(
        model,
        "labor",
    )

    @test_throws ArgumentError GEMB._resolve_commodities(
        model,
        [
            :labor,
            "bad",
        ],
    )


    # ------------------------------------------------------------
    # 5. Numeraire must resolve to exactly one concrete commodity.
    # ------------------------------------------------------------

    @test_throws ArgumentError GEMBModel(
        [
            CommoditySpec(
                :product;
                axes=(type=1:2,),
            ),
            :labor,
        ];
        numeraire=:product,
    )

    flat_numeraire_model = GEMBModel(
        [
            CommoditySpec(
                :product;
                axes=(type=1:2,),
            ),
            :labor,
        ];
        numeraire=:product_2,
    )

    @test flat_numeraire_model.numeraire == :product_2


    # ------------------------------------------------------------
    # 6. add_agent! accepts CommodityRef and group Symbols.
    # ------------------------------------------------------------

    build_model_ref = GEMBModel(
        [
            CommoditySpec(
                :product;
                axes=(type=1:2,),
            ),
            :labor,
        ];
        numeraire=CommodityRef(
            :product;
            type=1,
        ),
    )

    firm = add_agent!(
        build_model_ref,
        CESSpec([1.0]);
        outputs=CommodityRef(
            :product;
            type=1,
        ),
        demands=:labor,
        name=:firm,
    )

    @test firm isa GEM.AbstractNetSupplyAgent
    @test haskey(
        build_model_ref.agent_index,
        :firm,
    )

    consumer = add_agent!(
        build_model_ref,
        CESSpec([0.5, 0.5]);
        demands=:product,
        endowments=:labor,
        endowment_quantities=[1.0],
        name=:consumer,
    )

    @test consumer isa GEM.AbstractNetSupplyAgent
    @test length(build_model_ref.agents) == 2


    # ------------------------------------------------------------
    # 7. claim accepts CommodityRef but must be unique.
    # ------------------------------------------------------------

    claim_model = GEMBModel(
        [
            :product,
            :labor,
            CommoditySpec(
                :claim;
                axes=(period=1:2,),
            ),
        ];
        numeraire=:product,
    )

    claimed_firm = add_agent!(
        claim_model,
        CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        claim=CommodityRef(
            :claim;
            period=1,
        ),
        claim_rate=0.2,
        name=:claimed_firm,
    )

    @test claimed_firm isa GEM.AbstractNetSupplyAgent

    before_count =
        length(claim_model.agents)

    @test_throws ArgumentError add_agent!(
        claim_model,
        CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        claim=:claim,
        claim_rate=0.2,
        name=:ambiguous_claim_firm,
    )

    @test length(claim_model.agents) == before_count
    @test !haskey(
        claim_model.agent_index,
        :ambiguous_claim_firm,
    )


    # ------------------------------------------------------------
    # 8. Existing simple two-good solve remains unchanged.
    # ------------------------------------------------------------

    simple = GEMBModel(
        [:prod, :lab];
        numeraire=:prod,
    )

    add_agent!(
        simple,
        CESSpec([0.5, 0.5]);
        outputs=:prod,
        demands=[:prod, :lab],
        activity_start=40.0,
        name=:firm,
    )

    add_agent!(
        simple,
        CESSpec([0.8, 0.2]);
        demands=[:prod, :lab],
        endowments=:lab,
        endowment_quantities=[100.0],
        activity_start=20.0,
        name=:laborer,
    )

    result = solve(
        simple;
        p0=[1.0, 0.25],
        residual_tol=1.0e-8,
        silent=true,
    )

    @test result.solved
    @test result.mcp_solved
    @test result.all_markets_clear

    @test isapprox(
        result.prices,
        [1.0, 0.25];
        atol=1.0e-8,
        rtol=1.0e-8,
    )


    # ------------------------------------------------------------
    # 9. RelativePeriod remains an intertemporal-only extension.
    # ------------------------------------------------------------

    relative_model = GEMBModel(
        [
            CommoditySpec(
                :dated_product;
                axes=(period=1:3,),
            ),
            :labor,
        ];
        numeraire=CommodityRef(
            :dated_product;
            period=1,
        ),
    )

    @test_throws ArgumentError GEMB._resolve_commodities(
        relative_model,
        CommodityRef(
            :dated_product;
            period=RelativePeriod(1),
        ),
    )
end

println("GEMBModel CommodityRef STEP 4 tests passed.")
