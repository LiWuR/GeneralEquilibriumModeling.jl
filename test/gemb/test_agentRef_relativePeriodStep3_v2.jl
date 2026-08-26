# ================================================================
# test_agentRef_relativePeriodStep3_v2.jl
#
# AgentRef STEP 3:
#
#   RelativePeriod + AgentRef
#
# This step verifies only the reference-resolution layer.
# AgentTemplate construction is outside this reference-resolution test.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "AgentRef RelativePeriod STEP 3" begin

    # ------------------------------------------------------------
    # 1. Absolute AgentRef resolution remains a general GEMBModel feature.
    # ------------------------------------------------------------

    model =
        GEMBModel(
            [:prod, :lab];
            numeraire=:prod,
        )

    refs =
        AgentRef[
            AgentRef(
                :firm;
                period=1,
            ),
            AgentRef(
                :firm;
                period=2,
            ),
            AgentRef(
                :firm;
                period=3,
            ),
        ]

    for ref in refs
        add_agent!(
            model,
            CESSpec([1.0]);
            outputs=:prod,
            demands=:lab,
            name=ref,
        )
    end

    @test GEMB._resolve_agent_ref(
        model,
        refs[1],
    ) == 1

    @test GEMB._resolve_agent_ref(
        model,
        refs[2],
    ) == 2

    @test GEMB._resolve_agent_ref(
        model,
        :firm__period_i_3,
    ) == 3

    @test GEMB._resolve_agent_name(
        model,
        refs[2],
    ) == :firm__period_i_2


    # ------------------------------------------------------------
    # 2. RelativePeriod is allowed only on AgentRef's :period axis.
    # ------------------------------------------------------------

    lagged =
        AgentRef(
            :firm;
            period=RelativePeriod(-1),
        )

    current =
        AgentRef(
            :firm;
            period=RelativePeriod(0),
        )

    lead =
        AgentRef(
            :firm;
            period=RelativePeriod(1),
        )

    @test lagged.selectors.period ==
          RelativePeriod(-1)

    @test_throws ArgumentError AgentRef(
        :firm;
        region=RelativePeriod(-1),
    )


    # ------------------------------------------------------------
    # 3. Relative AgentRef -> absolute AgentRef.
    # ------------------------------------------------------------

    @test GEMB._absolute_intertemporal_agent_ref(
        lagged;
        base_period=3,
    ) == AgentRef(
        :firm;
        period=2,
    )

    @test GEMB._absolute_intertemporal_agent_ref(
        current;
        base_period=2,
    ) == AgentRef(
        :firm;
        period=2,
    )

    @test GEMB._absolute_intertemporal_agent_ref(
        lead;
        base_period=2,
    ) == AgentRef(
        :firm;
        period=3,
    )


    # ------------------------------------------------------------
    # 4. Non-period coordinates are preserved.
    # ------------------------------------------------------------

    regional =
        AgentRef(
            :producer;
            region=:east,
            period=RelativePeriod(-1),
            type=2,
        )

    absolute_regional =
        GEMB._absolute_intertemporal_agent_ref(
            regional;
            base_period=4,
        )

    @test absolute_regional ==
          AgentRef(
              :producer;
              region=:east,
              period=3,
              type=2,
          )

    @test absolute_regional.selectors == (
        period=3,
        region=:east,
        type=2,
    )


    # ------------------------------------------------------------
    # 5. A base period is required only when the reference is relative.
    # ------------------------------------------------------------

    absolute =
        AgentRef(
            :firm;
            period=2,
        )

    undated =
        AgentRef(:household)

    @test GEMB._absolute_intertemporal_agent_ref(
        absolute,
    ) === absolute

    @test GEMB._absolute_intertemporal_agent_ref(
        undated,
    ) === undated

    @test_throws ArgumentError GEMB._absolute_intertemporal_agent_ref(
        lagged,
    )


    # ------------------------------------------------------------
    # 6. Relative resolver composes with the generic model resolver.
    # ------------------------------------------------------------

    @test GEMB._resolve_intertemporal_agent_ref(
        model,
        lagged;
        base_period=3,
    ) == 2

    @test GEMB._resolve_intertemporal_agent_ref(
        model,
        current;
        base_period=3,
    ) == 3

    @test GEMB._resolve_intertemporal_agent_ref(
        model,
        AgentRef(
            :firm;
            period=1,
        ),
    ) == 1


    # ------------------------------------------------------------
    # 7. Boundary / missing-agent cases fail at actual model resolution.
    # ------------------------------------------------------------

    before_start =
        AgentRef(
            :firm;
            period=RelativePeriod(-1),
        )

    @test GEMB._absolute_intertemporal_agent_ref(
        before_start;
        base_period=1,
    ) == AgentRef(
        :firm;
        period=0,
    )

    @test_throws ArgumentError GEMB._resolve_intertemporal_agent_ref(
        model,
        before_start;
        base_period=1,
    )

    @test_throws ArgumentError GEMB._resolve_intertemporal_agent_ref(
        model,
        lead;
        base_period=3,
    )


    # ------------------------------------------------------------
    # 8. Relative AgentRef cannot be passed directly to ordinary add_agent!.
    # ------------------------------------------------------------

    ordinary_model =
        GEMBModel(
            [:prod, :lab];
            numeraire=:prod,
        )

    @test_throws ArgumentError add_agent!(
        ordinary_model,
        CESSpec([1.0]);
        outputs=:prod,
        demands=:lab,
        name=AgentRef(
            :firm;
            period=RelativePeriod(0),
        ),
    )

    @test isempty(ordinary_model.agents)
    @test isempty(ordinary_model.agent_refs)
end

println("AgentRef RelativePeriod STEP 3 tests passed.")
