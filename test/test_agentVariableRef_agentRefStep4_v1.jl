# ================================================================
# test_agentVariableRef_agentRefStep4_v1.jl
#
# AgentRef STEP 4:
#
#   high-level agent_variable_ref(...) -> GEM.AgentVariableRef
#
# Verify:
#
#   - structured absolute AgentRef targets;
#   - forward references;
#   - RelativePeriod targets resolved from the observing agent period;
#   - existing GEM equilibrium-variable references remain unchanged;
#   - missing target agents/variables are still rejected by final GEM model
#     validation rather than prematurely by add_agent!;
#   - failed relative materialization is transactional.
# ================================================================

using Test
using GEM
using GEMB


@testset "AgentVariableRef + AgentRef STEP 4" begin

    # ------------------------------------------------------------
    # 1. Absolute structured target and forward reference.
    # ------------------------------------------------------------

    model =
        GEMBModel(
            [:prod, :lab];
            numeraire=:lab,
        )

    observer_ref =
        AgentRef(
            :observer;
            period=2,
        )

    target_ref =
        AgentRef(
            :firm;
            period=2,
        )

    observer =
        add_agent!(
            model,
            CESSpec([1.0]);
            outputs=:prod,
            demands=:lab,
            observed_variables=[
                agent_variable_ref(
                    target_ref,
                    :activity,
                ),
            ],
            name=observer_ref,
        )

    # Target does not exist yet, so add_agent! must preserve forward-reference
    # behavior rather than requiring immediate registry resolution.
    @test length(model.agents) == 1

    @test GEM.agent_observed_variables(observer) == [
        GEM.AgentVariableRef(
            :firm__period_i_2,
            :activity,
        ),
    ]

    add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        name=target_ref,
    )

    low_model =
        build_model(
            model,
        )

    @test length(low_model.agents) == 2

    @test GEM.agent_observed_variables(
        low_model.agents[1],
    ) == [
        GEM.AgentVariableRef(
            :firm__period_i_2,
            :activity,
        ),
    ]


    # ------------------------------------------------------------
    # 2. Relative target is interpreted from observer's own period.
    # ------------------------------------------------------------

    relative_model =
        GEMBModel(
            [:prod, :lab];
            numeraire=:lab,
        )

    lagged_firm =
        agent_variable_ref(
            AgentRef(
                :firm;
                period=RelativePeriod(-1),
            ),
            :activity,
        )

    observer_t3 =
        add_agent!(
            relative_model,
            CESSpec([1.0]);
            outputs=:prod,
            demands=:lab,
            observed_variables=[
                lagged_firm,
            ],
            name=AgentRef(
                :observer;
                period=3,
            ),
        )

    @test GEM.agent_observed_variables(
        observer_t3,
    ) == [
        GEM.AgentVariableRef(
            :firm__period_i_2,
            :activity,
        ),
    ]

    add_agent!(
        relative_model,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        name=AgentRef(
            :firm;
            period=2,
        ),
    )

    @test build_model(relative_model) isa
          GEM.EquilibriumModel


    # ------------------------------------------------------------
    # 3. RelativePeriod(0) resolves to the observing period.
    # ------------------------------------------------------------

    current_model =
        GEMBModel(
            [:prod, :lab];
            numeraire=:lab,
        )

    current_observer =
        add_agent!(
            current_model,
            CESSpec([1.0]);
            outputs=:prod,
            demands=:lab,
            observed_variables=[
                agent_variable_ref(
                    AgentRef(
                        :firm;
                        period=RelativePeriod(0),
                    ),
                    :activity,
                ),
            ],
            name=AgentRef(
                :observer;
                period=4,
            ),
        )

    @test GEM.agent_observed_variables(
        current_observer,
    ) == [
        GEM.AgentVariableRef(
            :firm__period_i_4,
            :activity,
        ),
    ]


    # ------------------------------------------------------------
    # 4. Observer without period cannot materialize a relative target.
    # ------------------------------------------------------------

    bad_context =
        GEMBModel(
            [:prod, :lab];
            numeraire=:lab,
        )

    @test_throws ArgumentError add_agent!(
        bad_context,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        observed_variables=[
            agent_variable_ref(
                AgentRef(
                    :firm;
                    period=RelativePeriod(-1),
                ),
                :activity,
            ),
        ],
        name=:observer,
    )

    @test isempty(bad_context.agents)
    @test isempty(bad_context.agent_refs)
    @test isempty(bad_context.agent_index)
    @test isempty(bad_context.agent_ref_index)


    # ------------------------------------------------------------
    # 5. Existing low-level GEM references pass through unchanged.
    # ------------------------------------------------------------

    compatibility_model =
        GEMBModel(
            [:prod, :lab];
            numeraire=:lab,
        )

    add_agent!(
        compatibility_model,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        name=:firm,
    )

    compatibility_observer =
        add_agent!(
            compatibility_model,
            CESSpec([1.0]);
            outputs=:prod,
            demands=:lab,
            observed_variables=[
                GEM.AgentVariableRef(
                    :firm,
                    :activity,
                ),
                GEM.PriceVariableRef(
                    :prod,
                ),
            ],
            name=:observer,
        )

    @test GEM.agent_observed_variables(
        compatibility_observer,
    ) == [
        GEM.AgentVariableRef(
            :firm,
            :activity,
        ),
        GEM.PriceVariableRef(
            :prod,
        ),
    ]

    @test build_model(compatibility_model) isa
          GEM.EquilibriumModel


    # ------------------------------------------------------------
    # 6. Missing target remains a final-model validation error.
    # ------------------------------------------------------------

    missing_target_model =
        GEMBModel(
            [:prod, :lab];
            numeraire=:lab,
        )

    missing_target_observer =
        add_agent!(
            missing_target_model,
            CESSpec([1.0]);
            outputs=:prod,
            demands=:lab,
            observed_variables=[
                agent_variable_ref(
                    AgentRef(
                        :missing_firm;
                        period=1,
                    ),
                    :activity,
                ),
            ],
            name=AgentRef(
                :observer;
                period=1,
            ),
        )

    @test missing_target_observer isa
          GEM.AbstractNetSupplyAgent

    @test_throws ArgumentError build_model(
        missing_target_model,
    )


    # ------------------------------------------------------------
    # 7. Missing target variable is likewise checked by final model build.
    # ------------------------------------------------------------

    missing_variable_model =
        GEMBModel(
            [:prod, :lab];
            numeraire=:lab,
        )

    add_agent!(
        missing_variable_model,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        observed_variables=[
            agent_variable_ref(
                AgentRef(
                    :firm;
                    period=1,
                ),
                :missing_variable,
            ),
        ],
        name=AgentRef(
            :observer;
            period=1,
        ),
    )

    add_agent!(
        missing_variable_model,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        name=AgentRef(
            :firm;
            period=1,
        ),
    )

    @test_throws ArgumentError build_model(
        missing_variable_model,
    )


    # ------------------------------------------------------------
    # 8. Public helper is exported by GEMB.
    # ------------------------------------------------------------

    public_names =
        Set(
            names(
                GEMB;
                all=false,
                imported=false,
            ),
        )

    @test :agent_variable_ref in public_names
end

println("AgentVariableRef + AgentRef STEP 4 tests passed.")
