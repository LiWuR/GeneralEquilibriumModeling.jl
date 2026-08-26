# ================================================================
# test_agentRef_step1_v1.jl
#
# STEP 1 tests for general absolute AgentRef identity.
#
# This test intentionally does not modify or exercise GEMBModel,
# RelativePeriod, AgentVariableRef, or the intertemporal builder.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEMB


@testset "AgentRef STEP 1" begin

    # ------------------------------------------------------------
    # 1. Simple identity.
    # ------------------------------------------------------------

    simple =
        AgentRef(:firm)

    @test simple.name == :firm
    @test isempty(simple.selectors)

    @test GEMB._agent_ref_key(simple) == (
        :firm,
        NamedTuple(),
    )

    @test GEMB._flat_agent_name(simple) == :firm


    # ------------------------------------------------------------
    # 2. Structured absolute identity.
    # ------------------------------------------------------------

    dated =
        AgentRef(
            :firm;
            period=3,
        )

    @test dated.name == :firm
    @test dated.selectors == (
        period=3,
    )

    @test GEMB._flat_agent_name(dated) ==
          :firm__period_i_3


    # ------------------------------------------------------------
    # 3. Selector order is not part of identity.
    # ------------------------------------------------------------

    a =
        AgentRef(
            :producer;
            region=:east,
            period=3,
        )

    b =
        AgentRef(
            :producer;
            period=3,
            region=:east,
        )

    @test a == b
    @test isequal(a, b)

    @test a.selectors == (
        period=3,
        region=:east,
    )

    @test GEMB._agent_ref_key(a) ==
          GEMB._agent_ref_key(b)

    @test GEMB._flat_agent_name(a) ==
          GEMB._flat_agent_name(b)

    @test GEMB._flat_agent_name(a) ==
          :producer__period_i_3__region_s_east


    # ------------------------------------------------------------
    # 4. AgentRef works as a dictionary identity.
    # ------------------------------------------------------------

    registry =
        Dict(
            a => 7,
        )

    @test registry[b] == 7


    # ------------------------------------------------------------
    # 5. Scalar label types are encoded distinctly.
    # ------------------------------------------------------------

    symbol_ref =
        AgentRef(
            :firm;
            region=:east,
        )

    string_ref =
        AgentRef(
            :firm;
            region="east",
        )

    int_ref =
        AgentRef(
            :firm;
            type=2,
        )

    float_ref =
        AgentRef(
            :firm;
            share=0.5,
        )

    char_ref =
        AgentRef(
            :firm;
            class='A',
        )

    bool_ref =
        AgentRef(
            :firm;
            active=true,
        )

    @test GEMB._flat_agent_name(symbol_ref) ==
          :firm__region_s_east

    @test GEMB._flat_agent_name(string_ref) ==
          :firm__region_q_east

    @test GEMB._flat_agent_name(int_ref) ==
          :firm__type_i_2

    @test GEMB._flat_agent_name(float_ref) ==
          Symbol(
              "firm__share_f_0.5",
          )

    @test GEMB._flat_agent_name(char_ref) ==
          :firm__class_c_65

    @test GEMB._flat_agent_name(bool_ref) ==
          :firm__active_b_true

    @test GEMB._flat_agent_name(symbol_ref) !=
          GEMB._flat_agent_name(string_ref)


    # ------------------------------------------------------------
    # 6. Separator escaping is deterministic.
    # ------------------------------------------------------------

    escaped =
        AgentRef(
            :firm;
            region=:north_east,
        )

    @test GEMB._flat_agent_name(escaped) ==
          Symbol(
              "firm__region_s_north%5Feast",
          )


    # ------------------------------------------------------------
    # 7. Multi-agent selectors are deliberately rejected.
    # ------------------------------------------------------------

    @test_throws ArgumentError AgentRef(
        :firm;
        period=1:3,
    )

    @test_throws ArgumentError AgentRef(
        :firm;
        period=[1, 2, 3],
    )

    @test_throws ArgumentError AgentRef(
        :firm;
        period=(1, 2),
    )

    @test_throws ArgumentError AgentRef(
        :firm;
        region=Set([
            :east,
            :west,
        ]),
    )

    @test_throws ArgumentError AgentRef(
        :firm;
        period=Colon(),
    )


    # ------------------------------------------------------------
    # 8. Unsupported and invalid scalar values are rejected.
    # ------------------------------------------------------------

    @test_throws ArgumentError AgentRef(
        Symbol("");
    )

    @test_throws ArgumentError AgentRef(
        :firm;
        period=Inf,
    )

    @test_throws ArgumentError AgentRef(
        :firm;
        metadata=Dict(
            :period => 1,
        ),
    )


    # ------------------------------------------------------------
    # 9. AgentRef is part of the public GEMB API.
    # ------------------------------------------------------------

    public_names =
        Set(
            names(
                GEMB;
                all=false,
                imported=false,
            ),
        )

    @test :AgentRef in public_names
end

println("AgentRef STEP 1 tests passed.")
