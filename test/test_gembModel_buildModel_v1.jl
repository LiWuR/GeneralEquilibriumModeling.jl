# ================================================================
# test_gembModel_buildModel_v1.jl
#
# STEP 5 tests for GEMBModel -> GEM.EquilibriumModel materialization.
#
# No equilibrium is solved here. solve(::GEMBModel) belongs to STEP 6.
# ================================================================

using Test
using GEM
using GEMB


@testset "GEMBModel STEP 5 build_model" begin

    # ------------------------------------------------------------
    # 1. Construct a small high-level model entirely with names.
    # ------------------------------------------------------------

    high = GEMBModel(
        [:product, :labor];
        numeraire=:labor,
        numeraire_value=2.5,
    )

    firm = add_agent!(
        high,
        CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        activity_start=5.0,
        name=:firm,
    )

    household = add_agent!(
        high,
        CESSpec([1.0]);
        demands=:product,
        endowments=:labor,
        endowment_quantities=10.0,
        activity_start=5.0,
        name=:household,
    )

    @test length(high.agents) == 2


    # ------------------------------------------------------------
    # 2. Materialize the canonical GEM model.
    # ------------------------------------------------------------

    low = build_model(high)

    @test low isa GEM.EquilibriumModel
    @test low isa GEM.NetSupplyEquilibriumModel

    @test low.commodity_names == [:product, :labor]
    @test low.commodity_index == Dict(
        :product => 1,
        :labor => 2,
    )

    @test low.numeraire_index == 2
    @test low.numeraire_value == 2.5

    @test length(low.agents) == 2
    @test low.agents[1] === firm
    @test low.agents[2] === household

    # STEP 5 relies on the existing GEM defaults for these components.
    @test isempty(low.auxiliary_variables)
    @test isempty(low.auxiliary_equations)
    @test GEM.price_lower_bounds(low) == [0.0, 0.0]
    @test GEM.price_upper_bounds(low) == [Inf, Inf]


    # ------------------------------------------------------------
    # 3. Compare against the direct low-level GEM construction.
    # ------------------------------------------------------------

    direct = GEM.EquilibriumModel(
        [firm, household],
        [:product, :labor];
        numeraire_index=2,
        numeraire_value=2.5,
    )

    @test low.commodity_names == direct.commodity_names
    @test low.commodity_index == direct.commodity_index
    @test low.numeraire_index == direct.numeraire_index
    @test low.numeraire_value == direct.numeraire_value
    @test GEM.price_lower_bounds(low) == GEM.price_lower_bounds(direct)
    @test GEM.price_upper_bounds(low) == GEM.price_upper_bounds(direct)

    @test length(low.agents) == length(direct.agents)
    for i in eachindex(low.agents)
        @test low.agents[i] === direct.agents[i]
    end


    # ------------------------------------------------------------
    # 4. build_model does not replace or mutate the high-level state.
    # ------------------------------------------------------------

    @test high.commodity_names == [:product, :labor]
    @test high.commodity_index == Dict(
        :product => 1,
        :labor => 2,
    )
    @test high.numeraire == :labor
    @test high.numeraire_value == 2.5
    @test length(high.agents) == 2
    @test high.agent_index == Dict(
        :firm => 1,
        :household => 2,
    )


    # ------------------------------------------------------------
    # 5. A GEMBModel may be incomplete while it is being built,
    #    but GEM's canonical constructor rejects materialization
    #    before at least one agent has been added.
    # ------------------------------------------------------------

    empty_high = GEMBModel(
        [:product, :labor];
        numeraire=:product,
    )

    @test_throws ArgumentError build_model(empty_high)


    # ------------------------------------------------------------
    # 6. build_model uses the current model state each time.
    # ------------------------------------------------------------

    high2 = GEMBModel(
        [:product, :labor];
        numeraire=:product,
    )

    first_agent = add_agent!(
        high2,
        CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        name=:first_agent,
    )

    first_low = build_model(high2)
    @test length(first_low.agents) == 1
    @test first_low.agents[1] === first_agent

    second_agent = add_agent!(
        high2,
        CESSpec([1.0]);
        demands=:product,
        endowments=:labor,
        endowment_quantities=5.0,
        name=:second_agent,
    )

    second_low = build_model(high2)

    @test length(second_low.agents) == 2
    @test second_low.agents[1] === first_agent
    @test second_low.agents[2] === second_agent

    # The previously materialized GEM model remains the earlier snapshot.
    @test length(first_low.agents) == 1
end

println("GEMBModel STEP 5 build_model tests passed.")
