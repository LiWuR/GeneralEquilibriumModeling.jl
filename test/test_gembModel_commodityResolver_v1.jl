# ================================================================
# test_gembModel_commodityResolver_v1.jl
#
# STEP 2 regression tests for GEMBModel commodity-name resolution.
#
# This test intentionally covers only:
#
#   - the V1 GEMBModel construction contract needed by STEP 2;
#   - Symbol -> integer-index resolution;
#   - Vector{Symbol} -> integer-index resolution;
#   - nothing -> empty integer vector;
#   - duplicate, unknown, and unsupported selectors.
#
# add_agent!, build_model, solve, model editing, and CommodityRef
# support belong to later implementation steps.
# ================================================================

using Test
using GEM
using GEMB


@testset "GEMBModel STEP 2 commodity resolver" begin

    model = GEMBModel(
        [:product, :labor, :capital];
        numeraire=:product,
    )

    # ------------------------------------------------------------
    # 1. Construction state required by the resolver
    # ------------------------------------------------------------

    @test model.commodity_names == [
        :product,
        :labor,
        :capital,
    ]

    @test model.commodity_index == Dict(
        :product => 1,
        :labor => 2,
        :capital => 3,
    )

    @test isempty(model.agents)
    @test isempty(model.agent_index)


    # ------------------------------------------------------------
    # 2. nothing resolves to an empty integer mapping
    # ------------------------------------------------------------

    @test GEMB._resolve_commodities(
        model,
        nothing,
    ) == Int[]


    # ------------------------------------------------------------
    # 3. Scalar Symbol resolution
    # ------------------------------------------------------------

    @test GEMB._resolve_commodities(
        model,
        :product,
    ) == [1]

    @test GEMB._resolve_commodities(
        model,
        :labor,
    ) == [2]

    @test GEMB._resolve_commodities(
        model,
        :capital,
    ) == [3]


    # ------------------------------------------------------------
    # 4. Vector{Symbol} resolution preserves requested order
    # ------------------------------------------------------------

    @test GEMB._resolve_commodities(
        model,
        [:capital, :product],
    ) == [3, 1]

    @test GEMB._resolve_commodities(
        model,
        [:labor, :capital, :product],
    ) == [2, 3, 1]

    @test GEMB._resolve_commodities(
        model,
        Symbol[],
    ) == Int[]


    # ------------------------------------------------------------
    # 5. Source selector is not mutated
    # ------------------------------------------------------------

    selected = [:capital, :labor]
    resolved = GEMB._resolve_commodities(
        model,
        selected,
    )

    @test selected == [:capital, :labor]
    @test resolved == [3, 2]


    # ------------------------------------------------------------
    # 6. Unknown commodities fail immediately
    # ------------------------------------------------------------

    @test_throws ArgumentError GEMB._resolve_commodities(
        model,
        :land,
    )

    @test_throws ArgumentError GEMB._resolve_commodities(
        model,
        [:product, :land],
    )


    # ------------------------------------------------------------
    # 7. Duplicate commodity selections are rejected
    # ------------------------------------------------------------

    @test_throws ArgumentError GEMB._resolve_commodities(
        model,
        [:labor, :labor],
    )


    # ------------------------------------------------------------
    # 8. STEP 2 intentionally rejects unsupported selector forms
    # ------------------------------------------------------------

    @test_throws ArgumentError GEMB._resolve_commodities(
        model,
        1,
    )

    @test_throws ArgumentError GEMB._resolve_commodities(
        model,
        (:product, :labor),
    )

    @test_throws ArgumentError GEMB._resolve_commodities(
        model,
        ["product", "labor"],
    )
end

println("GEMBModel STEP 2 commodity resolver tests passed.")
