# ================================================================
# test_commoditySpace_step2_v1.jl
#
# STEP 2 tests for CommoditySpace input normalization.
#
# This step proves that simple Symbol commodities and structured
# CommoditySpec objects share one canonical CommoditySpace.
# GEMBModel itself is intentionally unchanged in STEP 2.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEMB


@testset "CommoditySpace STEP 2" begin

    # ------------------------------------------------------------
    # 1. Simple Symbol commodities are normalized automatically.
    # ------------------------------------------------------------

    simple = CommoditySpace([
        :prod,
        :lab,
    ])

    @test length(simple.specs) == 2
    @test all(spec -> spec isa CommoditySpec, simple.specs)

    @test simple.specs[1].name == :prod
    @test simple.specs[2].name == :lab
    @test isempty(simple.specs[1].axes)
    @test isempty(simple.specs[2].axes)

    @test simple.commodity_names == [
        :prod,
        :lab,
    ]

    @test simple.coordinates == [
        NamedTuple(),
        NamedTuple(),
    ]

    @test simple.price_lower_bounds == [
        0.0,
        0.0,
    ]

    @test simple.price_upper_bounds == [
        Inf,
        Inf,
    ]

    @test GEMB._resolve_commodity_ref(
        simple,
        CommodityRef(:prod),
    ) == [1]

    @test GEMB._resolve_commodity_ref(
        simple,
        CommodityRef(:lab),
    ) == [2]


    # ------------------------------------------------------------
    # 2. Mixed simple and structured declarations are supported.
    # ------------------------------------------------------------

    mixed = CommoditySpace([
        :labor,
        CommoditySpec(
            :product;
            axes=(
                type=1:2,
                region=[:east, :west],
            ),
            price_lower_bound=1.0e-8,
            price_upper_bound=100.0,
        ),
        :claim,
    ])

    @test [spec.name for spec in mixed.specs] == [
        :labor,
        :product,
        :claim,
    ]

    @test mixed.commodity_names == [
        :labor,
        :product_1_east,
        :product_1_west,
        :product_2_east,
        :product_2_west,
        :claim,
    ]

    @test mixed.coordinates == [
        NamedTuple(),
        (type=1, region=:east),
        (type=1, region=:west),
        (type=2, region=:east),
        (type=2, region=:west),
        NamedTuple(),
    ]

    @test mixed.price_lower_bounds == [
        0.0,
        1.0e-8,
        1.0e-8,
        1.0e-8,
        1.0e-8,
        0.0,
    ]

    @test mixed.price_upper_bounds == [
        Inf,
        100.0,
        100.0,
        100.0,
        100.0,
        Inf,
    ]

    @test GEMB._resolve_commodity_ref(
        mixed,
        CommodityRef(
            :product;
            region=:east,
        ),
    ) == [2, 4]

    @test GEMB._resolve_commodity_ref(
        mixed,
        CommodityRef(:claim),
    ) == [6]


    # ------------------------------------------------------------
    # 3. Symbol and explicit zero-axis CommoditySpec are equivalent.
    # ------------------------------------------------------------

    symbol_space = CommoditySpace([
        :x,
        :y,
    ])

    explicit_space = CommoditySpace([
        CommoditySpec(:x),
        CommoditySpec(:y),
    ])

    @test symbol_space.commodity_names ==
          explicit_space.commodity_names

    @test symbol_space.coordinates ==
          explicit_space.coordinates

    @test symbol_space.index_by_key ==
          explicit_space.index_by_key

    @test symbol_space.price_lower_bounds ==
          explicit_space.price_lower_bounds

    @test symbol_space.price_upper_bounds ==
          explicit_space.price_upper_bounds


    # ------------------------------------------------------------
    # 4. Duplicate group names are rejected after normalization.
    # ------------------------------------------------------------

    @test_throws ArgumentError CommoditySpace([
        :x,
        CommoditySpec(:x),
    ])


    # ------------------------------------------------------------
    # 5. Flat-name collisions remain rejected.
    # ------------------------------------------------------------

    @test_throws ArgumentError CommoditySpace([
        :product_1,
        CommoditySpec(
            :product;
            axes=(type=1:1,),
        ),
    ])


    # ------------------------------------------------------------
    # 6. Unsupported declaration types fail clearly.
    # ------------------------------------------------------------

    @test_throws ArgumentError CommoditySpace([
        :x,
        "y",
    ])

    @test_throws ArgumentError CommoditySpace(Any[])


    # ------------------------------------------------------------
    # 7. Existing intertemporal absolute resolution remains intact.
    # ------------------------------------------------------------

    dated = CommoditySpec(
        :dated_product;
        axes=(
            type=1:2,
            period=1:3,
        ),
    )

    general_space = CommoditySpace([
        :cash,
        dated,
    ])

    @test general_space.commodity_names == [
        :cash,
        :dated_product_1_1,
        :dated_product_1_2,
        :dated_product_1_3,
        :dated_product_2_1,
        :dated_product_2_2,
        :dated_product_2_3,
    ]

    @test GEMB._resolve_commodity_ref(
        general_space,
        CommodityRef(
            :dated_product;
            type=2,
            period=3,
        ),
    ) == [7]

    @test GEMB._resolve_commodity_ref(
        general_space,
        CommodityRef(
            :dated_product;
            period=2,
        ),
    ) == [3, 6]


    # ------------------------------------------------------------
    # 8. RelativePeriod resolution requires intertemporal context.
    # ------------------------------------------------------------

    relative_ref = CommodityRef(
        :dated_product;
        period=RelativePeriod(1),
    )

    @test_throws ArgumentError GEMB._resolve_commodity_ref(
        general_space,
        relative_ref,
    )

end

println("CommoditySpace STEP 2 tests passed.")
