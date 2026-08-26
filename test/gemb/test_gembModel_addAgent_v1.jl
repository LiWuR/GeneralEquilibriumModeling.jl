# ================================================================
# test_gembModel_addAgent_v1.jl
#
# STEP 3 regression tests for GEMBModel add_agent!.
#
# This test intentionally verifies the thin-wrapper contract only:
#
#   commodity names
#       -> integer mappings
#       -> existing build_agent
#       -> completed NetSupplyAgent
#       -> GEMBModel insertion
#
# build_model, solve, model editing, pure-endowment add_agent!, and
# CommodityRef support belong to later implementation steps.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "GEMBModel STEP 3 add_agent!" begin

    # ------------------------------------------------------------
    # 1. CES producer: names -> build_agent -> stored agent
    # ------------------------------------------------------------

    model = GEMBModel(
        [:product, :labor, :capital];
        numeraire=:product,
    )

    technology = CESSpec(
        [0.5, 0.5];
        es=1.0,
        alpha=1.0,
    )

    firm = add_agent!(
        model,
        technology;
        outputs=:product,
        demands=[:labor, :capital],
        activity_start=40.0,
        name=:firm,
    )

    @test firm isa GEM.AbstractNetSupplyAgent
    @test length(model.agents) == 1
    @test model.agents[1] === firm
    @test model.agent_index == Dict(
        :firm => 1,
    )


    # ------------------------------------------------------------
    # 2. The same generic wrapper also reaches the CES consumer path
    # ------------------------------------------------------------

    household = add_agent!(
        model,
        CESSpec([1.0]);
        demands=:product,
        endowments=:labor,
        endowment_quantities=10.0,
        name=:household,
    )

    @test household isa GEM.AbstractNetSupplyAgent
    @test length(model.agents) == 2
    @test model.agents[2] === household
    @test model.agent_index == Dict(
        :firm => 1,
        :household => 2,
    )


    # ------------------------------------------------------------
    # 3. Existing build_agent keywords are forwarded unchanged
    # ------------------------------------------------------------

    model2 = GEMBModel(
        [:output, :labor];
        numeraire=:output,
    )

    firm2 = add_agent!(
        model2,
        CESSpec([1.0]);
        outputs=:output,
        demands=:labor,
        output_coefficients=2.0,
        activity_start=7.0,
        activity_lower_bound=0.0,
        activity_upper_bound=100.0,
        unit_loss_cap=1.0e8,
        name=:firm2,
    )

    @test firm2 isa GEM.AbstractNetSupplyAgent
    @test length(model2.agents) == 1
    @test model2.agent_index[:firm2] == 1


    # ------------------------------------------------------------
    # 4. Unknown commodities fail before model mutation
    # ------------------------------------------------------------

    before_agents = copy(model.agents)
    before_index = copy(model.agent_index)

    @test_throws ArgumentError add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:product,
        demands=:land,
        name=:bad_unknown,
    )

    @test model.agents == before_agents
    @test model.agent_index == before_index


    # ------------------------------------------------------------
    # 5. build_agent failures also leave model unchanged
    # ------------------------------------------------------------

    before_agents = copy(model.agents)
    before_index = copy(model.agent_index)

    # beta has length 2 but only one demand commodity is supplied.
    @test_throws DimensionMismatch add_agent!(
        model,
        CESSpec([0.5, 0.5]);
        outputs=:product,
        demands=:labor,
        name=:bad_dimension,
    )

    @test model.agents == before_agents
    @test model.agent_index == before_index


    # ------------------------------------------------------------
    # 6. Duplicate agent names are rejected without mutation
    # ------------------------------------------------------------

    before_agents = copy(model.agents)
    before_index = copy(model.agent_index)

    @test_throws ArgumentError add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        name=:firm,
    )

    @test model.agents == before_agents
    @test model.agent_index == before_index


    # ------------------------------------------------------------
    # 7. Low-level integer mapping keywords are rejected
    # ------------------------------------------------------------

    before_agents = copy(model.agents)
    before_index = copy(model.agent_index)

    @test_throws ArgumentError add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        output_indices=[1],
        name=:bad_low_level,
    )

    @test model.agents == before_agents
    @test model.agent_index == before_index


    # ------------------------------------------------------------
    # 8. name is required by the high-level model API
    # ------------------------------------------------------------

    @test_throws UndefKeywordError add_agent!(
        GEMBModel([:product, :labor]),
        CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
    )
end

println("GEMBModel STEP 3 add_agent! tests passed.")
