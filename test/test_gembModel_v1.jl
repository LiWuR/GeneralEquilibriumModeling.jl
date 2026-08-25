# ================================================================
# test_gembModel_v1.jl
#
# STEP 1 regression tests for the minimal GEMBModel container.
#
# This test intentionally covers only construction-time behavior.
# add_agent!, commodity-name resolution, build_model, solve, and model
# editing belong to later implementation steps.
# ================================================================

using Test
using GEM
using GEMB


@testset "GEMBModel V1 construction" begin

    # ------------------------------------------------------------
    # 1. Default construction
    # ------------------------------------------------------------

    model = GEMBModel(
        [:product, :labor],
    )

    @test model.commodity_names == [
        :product,
        :labor,
    ]

    @test model.commodity_index == Dict(
        :product => 1,
        :labor => 2,
    )

    @test isempty(model.agents)
    @test eltype(model.agents) == GEM.AbstractNetSupplyAgent
    @test isempty(model.agent_index)

    @test model.numeraire == :product
    @test model.numeraire_value == 1.0
    @test model.solver === GEM.solve_equilibrium_model_mcp_jump


    # ------------------------------------------------------------
    # 2. Explicit numeraire and value
    # ------------------------------------------------------------

    model2 = GEMBModel(
        [:product, :capital, :labor];
        numeraire=:labor,
        numeraire_value=2.0,
    )

    @test model2.numeraire == :labor
    @test model2.numeraire_value == 2.0
    @test model2.commodity_index[:product] == 1
    @test model2.commodity_index[:capital] == 2
    @test model2.commodity_index[:labor] == 3


    # ------------------------------------------------------------
    # 3. The constructor owns its commodity-name vector
    # ------------------------------------------------------------

    source_names = [:x, :y]
    model3 = GEMBModel(source_names)
    source_names[1] = :changed

    @test model3.commodity_names == [:x, :y]
    @test model3.commodity_index == Dict(
        :x => 1,
        :y => 2,
    )


    # ------------------------------------------------------------
    # 4. Invalid commodity spaces and numeraires
    # ------------------------------------------------------------

    @test_throws ArgumentError GEMBModel(Symbol[])

    @test_throws ArgumentError GEMBModel(
        [:product, :product],
    )

    @test_throws ArgumentError GEMBModel(
        [:product, :labor];
        numeraire=:capital,
    )


    # ------------------------------------------------------------
    # 5. Invalid numeraire values
    # ------------------------------------------------------------

    @test_throws ArgumentError GEMBModel(
        [:product];
        numeraire_value=0.0,
    )

    @test_throws ArgumentError GEMBModel(
        [:product];
        numeraire_value=-1.0,
    )

    @test_throws ArgumentError GEMBModel(
        [:product];
        numeraire_value=Inf,
    )

    @test_throws ArgumentError GEMBModel(
        [:product];
        numeraire_value=NaN,
    )
end

println("GEMBModel V1 construction tests passed.")
