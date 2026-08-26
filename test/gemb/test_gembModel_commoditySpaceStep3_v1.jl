# ================================================================
# test_gembModel_commoditySpaceStep3_v1.jl
#
# CommoditySpace integration STEP 3 for GEMBModel.
#
# This test verifies that:
#
#   1. old Symbol-only GEMBModel construction remains unchanged;
#   2. GEMBModel now owns a CommoditySpace;
#   3. CommoditySpec declarations are accepted;
#   4. CommoditySpace price bounds reach the low-level GEM model;
#   5. existing Symbol-based add_agent! and solve behavior still works;
#   6. CommodityRef selectors are still deliberately deferred to STEP 4.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "GEMBModel CommoditySpace STEP 3" begin

    # ------------------------------------------------------------
    # 1. Old simple constructor behavior remains available.
    # ------------------------------------------------------------

    simple = GEMBModel(
        [:prod, :lab];
        numeraire=:prod,
    )

    @test simple.commodity_space isa CommoditySpace
    @test simple.commodity_names == [:prod, :lab]
    @test simple.commodity_index == Dict(
        :prod => 1,
        :lab => 2,
    )

    @test simple.commodity_space.commodity_names ==
          simple.commodity_names

    @test simple.commodity_space.price_lower_bounds == [
        0.0,
        0.0,
    ]

    @test simple.commodity_space.price_upper_bounds == [
        Inf,
        Inf,
    ]

    @test simple.numeraire == :prod


    # ------------------------------------------------------------
    # 2. CommoditySpec declarations are accepted by GEMBModel.
    # ------------------------------------------------------------

    structured = GEMBModel(
        [
            CommoditySpec(
                :product;
                axes=(type=1:2,),
            ),
            :labor,
        ];
        numeraire=:product_1,
    )

    @test structured.commodity_names == [
        :product_1,
        :product_2,
        :labor,
    ]

    @test structured.commodity_index == Dict(
        :product_1 => 1,
        :product_2 => 2,
        :labor => 3,
    )

    @test structured.commodity_space.coordinates == [
        (type=1,),
        (type=2,),
        NamedTuple(),
    ]


    # ------------------------------------------------------------
    # 3. Custom CommoditySpec price bounds reach GEM.
    # ------------------------------------------------------------

    bounded = GEMBModel(
        [
            CommoditySpec(
                :prod;
                price_lower_bound=0.25,
                price_upper_bound=10.0,
            ),
            CommoditySpec(
                :lab;
                price_lower_bound=0.0,
                price_upper_bound=Inf,
            ),
        ];
        numeraire=:prod,
        numeraire_value=1.0,
    )

    add_agent!(
        bounded,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        name=:firm,
    )

    add_agent!(
        bounded,
        CESSpec([1.0]);
        demands=:prod,
        endowments=:lab,
        endowment_quantities=[1.0],
        name=:consumer,
    )

    low_bounded =
        build_model(
            bounded,
        )

    @test GEM.price_lower_bounds(low_bounded) == [
        0.25,
        0.0,
    ]

    @test GEM.price_upper_bounds(low_bounded) == [
        10.0,
        Inf,
    ]


    # ------------------------------------------------------------
    # 4. Numeraire value is checked against CommoditySpace bounds.
    # ------------------------------------------------------------

    @test_throws ArgumentError GEMBModel(
        [
            CommoditySpec(
                :prod;
                price_lower_bound=2.0,
                price_upper_bound=10.0,
            ),
            :lab,
        ];
        numeraire=:prod,
        numeraire_value=1.0,
    )


    # ------------------------------------------------------------
    # 5. Existing two-good high-level equilibrium still solves.
    # ------------------------------------------------------------

    model = GEMBModel(
        [:prod, :lab];
        numeraire=:prod,
    )

    add_agent!(
        model,
        CESSpec([0.5, 0.5]);
        outputs=:prod,
        demands=[:prod, :lab],
        activity_start=40.0,
        name=:firm,
    )

    add_agent!(
        model,
        CESSpec([0.8, 0.2]);
        demands=[:prod, :lab],
        endowments=:lab,
        endowment_quantities=[100.0],
        activity_start=20.0,
        name=:laborer,
    )

    result = solve(
        model;
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

    @test maximum(
        abs,
        result.total_net_supply,
    ) <= 1.0e-8


    # ------------------------------------------------------------
    # 6. CommodityRef remains intentionally unavailable in add_agent!.
    # ------------------------------------------------------------

    ref_model = GEMBModel(
        [
            CommoditySpec(
                :product;
                axes=(type=1:2,),
            ),
            :labor,
        ];
        numeraire=:product_1,
    )

    @test_throws ArgumentError add_agent!(
        ref_model,
        CESSpec([1.0]);
        outputs=CommodityRef(
            :product;
            type=1,
        ),
        demands=:labor,
        name=:firm,
    )

    @test isempty(ref_model.agents)
    @test isempty(ref_model.agent_index)
end

println("GEMBModel CommoditySpace STEP 3 tests passed.")
