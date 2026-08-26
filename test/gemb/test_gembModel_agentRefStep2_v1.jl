# ================================================================
# test_gembModel_agentRefStep2_v1.jl
#
# AgentRef STEP 2 integration with GEMBModel.
#
# Verify:
#
#   - Symbol names remain backward-compatible;
#   - absolute AgentRef names are accepted by add_agent!;
#   - AgentRef <-> position and flat Symbol <-> position stay aligned;
#   - multiple structured agents with the same base name can coexist;
#   - identity duplicates and flat-name collisions are rejected;
#   - failed builds leave all agent registry state unchanged;
#   - build_model receives only flat GEM agent names.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "GEMBModel AgentRef STEP 2" begin

    # ------------------------------------------------------------
    # 1. Empty model owns aligned agent registries.
    # ------------------------------------------------------------

    model = GEMBModel(
        [:prod, :lab];
        numeraire=:prod,
    )

    @test isempty(model.agents)
    @test isempty(model.agent_refs)
    @test isempty(model.agent_index)
    @test isempty(model.agent_ref_index)


    # ------------------------------------------------------------
    # 2. Simple Symbol is normalized to AgentRef(:name).
    # ------------------------------------------------------------

    simple_agent = add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        name=:firm,
    )

    @test simple_agent isa GEM.AbstractNetSupplyAgent

    simple_ref =
        AgentRef(:firm)

    @test model.agent_refs == [
        simple_ref,
    ]

    @test model.agent_ref_index[simple_ref] == 1
    @test model.agent_index[:firm] == 1
    @test GEM.agent_name(model.agents[1]) == :firm


    # ------------------------------------------------------------
    # 3. Structured AgentRef is encoded only for GEM.
    # ------------------------------------------------------------

    dated_ref =
        AgentRef(
            :household;
            period=1,
        )

    dated_agent = add_agent!(
        model,
        CESSpec([1.0]);
        demands=:prod,
        endowments=:lab,
        endowment_quantities=[1.0],
        name=dated_ref,
    )

    @test dated_agent isa GEM.AbstractNetSupplyAgent

    dated_flat =
        GEMB._flat_agent_name(
            dated_ref,
        )

    @test dated_flat ==
          :household__period_i_1

    @test model.agent_refs[2] == dated_ref
    @test model.agent_ref_index[dated_ref] == 2
    @test model.agent_index[dated_flat] == 2
    @test GEM.agent_name(model.agents[2]) == dated_flat


    # ------------------------------------------------------------
    # 4. Same base name may coexist at different coordinates.
    # ------------------------------------------------------------

    firm_t2 =
        AgentRef(
            :firm;
            period=2,
        )

    firm_t3 =
        AgentRef(
            :firm;
            period=3,
        )

    add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        name=firm_t2,
    )

    add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        name=firm_t3,
    )

    @test model.agent_ref_index[firm_t2] == 3
    @test model.agent_ref_index[firm_t3] == 4

    @test model.agent_index[
        :firm__period_i_2
    ] == 3

    @test model.agent_index[
        :firm__period_i_3
    ] == 4


    # ------------------------------------------------------------
    # 5. Selector order canonicalization also prevents duplicates.
    # ------------------------------------------------------------

    producer_a =
        AgentRef(
            :producer;
            region=:east,
            period=1,
        )

    producer_b =
        AgentRef(
            :producer;
            period=1,
            region=:east,
        )

    add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        name=producer_a,
    )

    before_agents =
        length(model.agents)

    before_refs =
        length(model.agent_refs)

    @test_throws ArgumentError add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        name=producer_b,
    )

    @test length(model.agents) == before_agents
    @test length(model.agent_refs) == before_refs


    # ------------------------------------------------------------
    # 6. Flat-name collision is rejected even for different AgentRefs.
    # ------------------------------------------------------------

    collision_model =
        GEMBModel(
            [:prod, :lab];
            numeraire=:prod,
        )

    encoded_symbol =
        Symbol(
            "firm__period_i_3",
        )

    add_agent!(
        collision_model,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        name=encoded_symbol,
    )

    structured_collision =
        AgentRef(
            :firm;
            period=3,
        )

    @test structured_collision !=
          AgentRef(encoded_symbol)

    @test_throws ArgumentError add_agent!(
        collision_model,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        name=structured_collision,
    )

    @test length(collision_model.agents) == 1
    @test length(collision_model.agent_refs) == 1
    @test length(collision_model.agent_index) == 1
    @test length(collision_model.agent_ref_index) == 1


    # ------------------------------------------------------------
    # 7. Build failure remains transactional across all registries.
    # ------------------------------------------------------------

    transaction_model =
        GEMBModel(
            [:prod, :lab];
            numeraire=:prod,
        )

    failed_ref =
        AgentRef(
            :bad_firm;
            period=1,
        )

    @test_throws ArgumentError add_agent!(
        transaction_model,
        CESSpec([1.0]);
        outputs=:unknown,
        demands=:lab,
        name=failed_ref,
    )

    @test isempty(transaction_model.agents)
    @test isempty(transaction_model.agent_refs)
    @test isempty(transaction_model.agent_index)
    @test isempty(transaction_model.agent_ref_index)


    # ------------------------------------------------------------
    # 8. Unsupported name types fail before model mutation.
    # ------------------------------------------------------------

    @test_throws ArgumentError add_agent!(
        transaction_model,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        name="firm",
    )

    @test isempty(transaction_model.agents)
    @test isempty(transaction_model.agent_refs)


    # ------------------------------------------------------------
    # 9. build_model exposes only flat names to GEM.
    # ------------------------------------------------------------

    low_model =
        build_model(
            model,
        )

    @test GEM.agent_name.(low_model.agents) == [
        :firm,
        :household__period_i_1,
        :firm__period_i_2,
        :firm__period_i_3,
        :producer__period_i_1__region_s_east,
    ]

    @test length(model.agent_refs) ==
          length(model.agents)

    @test length(model.agent_ref_index) ==
          length(model.agents)

    @test length(model.agent_index) ==
          length(model.agents)
end

println("GEMBModel AgentRef STEP 2 tests passed.")
