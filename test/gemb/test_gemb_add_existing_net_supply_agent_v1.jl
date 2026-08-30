# ================================================================
# test_gemb_add_existing_net_supply_agent_v1.jl
#
# STEP 2 regression tests for registering already constructed
# GEM.AbstractNetSupplyAgent objects in GEMBModel.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "GEMB add existing net-supply agent STEP 2" begin

    model =
        GEMB.GEMBModel(
            [:product, :labor];
            numeraire=:product,
        )

    # 1. Default identity comes from the existing GEM agent name.
    simple_agent =
        GEM.NetSupplyAgent(
            [1, 2],
            (local_variables, local_prices, observed_values=Any[]) ->
                [0.0, 1.0];
            name=:consumer,
        )

    returned =
        GEMB.add_agent!(
            model,
            simple_agent,
        )

    @test returned === simple_agent
    @test model.agents[1] === simple_agent
    @test model.agent_refs[1] == GEMB.AgentRef(:consumer)
    @test model.agent_index[:consumer] == 1
    @test model.agent_ref_index[GEMB.AgentRef(:consumer)] == 1

    # 2. Structured AgentRef is retained when its flat name matches.
    dated_ref =
        GEMB.AgentRef(
            :firm;
            period=2,
        )

    dated_agent =
        GEM.NetSupplyAgent(
            [1],
            (local_variables, local_prices, observed_values=Any[]) ->
                [0.0];
            name=GEMB._flat_agent_name(dated_ref),
        )

    GEMB.add_agent!(
        model,
        dated_agent;
        name=dated_ref,
    )

    @test model.agent_refs[2] == dated_ref
    @test model.agent_ref_index[dated_ref] == 2
    @test model.agent_index[:firm__period_i_2] == 2
    @test GEM.agent_name(model.agents[2]) == :firm__period_i_2

    # 3. Mismatched identity is rejected without registry mutation.
    before_agents = length(model.agents)
    before_refs = length(model.agent_refs)

    mismatched =
        GEM.NetSupplyAgent(
            [1],
            (local_variables, local_prices, observed_values=Any[]) ->
                [0.0];
            name=:low_level_name,
        )

    @test_throws ArgumentError GEMB.add_agent!(
        model,
        mismatched;
        name=:different_name,
    )

    @test length(model.agents) == before_agents
    @test length(model.agent_refs) == before_refs
    @test !haskey(model.agent_index, :low_level_name)
    @test !haskey(model.agent_index, :different_name)

    # 4. Model-incompatible commodity indices are rejected transactionally.
    out_of_range =
        GEM.NetSupplyAgent(
            [3],
            (local_variables, local_prices, observed_values=Any[]) ->
                [0.0];
            name=:bad_commodity_agent,
        )

    before_agents = length(model.agents)
    before_refs = length(model.agent_refs)

    @test_throws ArgumentError GEMB.add_agent!(
        model,
        out_of_range,
    )

    @test length(model.agents) == before_agents
    @test length(model.agent_refs) == before_refs
    @test !haskey(model.agent_index, :bad_commodity_agent)

    # 5. Duplicate registration is rejected.
    @test_throws ArgumentError GEMB.add_agent!(
        model,
        simple_agent,
    )

    @test length(model.agents) == 2
    @test length(model.agent_refs) == 2

    # 6. Existing specification-based add_agent! still dispatches normally.
    spec_model =
        GEMB.GEMBModel(
            [:product, :labor];
            numeraire=:product,
        )

    spec_agent =
        GEMB.add_agent!(
            spec_model,
            GEMB.CESSpec([1.0]);
            outputs=:product,
            demands=:labor,
            name=:firm,
        )

    @test spec_agent isa GEM.AbstractNetSupplyAgent
    @test spec_model.agent_index[:firm] == 1
end

println("GEMB existing net-supply agent STEP 2 tests passed.")
