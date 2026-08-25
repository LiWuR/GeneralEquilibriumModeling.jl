# ================================================================
# test_relativeAgentRefs_step7c2fix_v1.jl
#
# Regression for RelativePeriod + AgentRef after removal of the retired
# intertemporal agent wrapper.
# ================================================================

using Test
using GEM
using GEMB


@testset "Relative AgentRef STEP 7C2 fix" begin

    lagged =
        AgentRef(
            :firm;
            period=RelativePeriod(-1),
        )

    @test lagged.selectors.period ==
          RelativePeriod(-1)

    @test_throws ArgumentError AgentRef(
        :firm;
        region=RelativePeriod(-1),
    )

    @test GEMB._absolute_intertemporal_agent_ref(
        lagged;
        base_period=3,
    ) == AgentRef(
        :firm;
        period=2,
    )

    regional =
        AgentRef(
            :producer;
            region=:east,
            period=RelativePeriod(1),
            type=2,
        )

    @test GEMB._absolute_intertemporal_agent_ref(
        regional;
        base_period=3,
    ) == AgentRef(
        :producer;
        region=:east,
        period=4,
        type=2,
    )

    @test_throws ArgumentError GEMB._flat_agent_name(
        lagged,
    )

    model =
        GEMBModel(
            [
                :product,
                :labor,
            ];
            numeraire=:labor,
        )

    for period in 1:3
        add_agent!(
            model,
            CESSpec([1.0]);
            name=AgentRef(
                :firm;
                period=period,
            ),
            outputs=:product,
            demands=:labor,
        )
    end

    @test GEMB._resolve_intertemporal_agent_ref(
        model,
        lagged;
        base_period=3,
    ) == 2

    observed =
        add_agent!(
            model,
            CESSpec([1.0]);
            name=AgentRef(
                :observer;
                period=3,
            ),
            outputs=:product,
            demands=:labor,
            observed_variables=[
                agent_variable_ref(
                    AgentRef(
                        :firm;
                        period=RelativePeriod(-1),
                    ),
                    :activity,
                ),
            ],
        )

    @test GEM.agent_observed_variables(
        observed,
    ) == [
        GEM.AgentVariableRef(
            :firm__period_i_2,
            :activity,
        ),
    ]
end

println("Relative AgentRef STEP 7C2 fix tests passed.")
