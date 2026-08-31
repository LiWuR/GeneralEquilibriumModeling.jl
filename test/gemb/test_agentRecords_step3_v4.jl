# ================================================================
# test_agentRecords_step3_v4.jl
#
# STEP 3 registry-alignment regression, compatible with STEP 4.
# ================================================================

using Test
using GeneralEquilibriumModeling

const _GEMB_AR3C = GeneralEquilibriumModeling.GEMB


@testset "GEMB agent records registry alignment" begin
    model = _GEMB_AR3C.GEMBModel(
        [:product, :labor];
        numeraire=:product,
    )

    spec = _GEMB_AR3C.ActivityDemandSpec(
        (activity, prices) -> [
            0.5 * activity,
            0.5 * activity,
        ],
    )

    added = _GEMB_AR3C.add_agent!(
        model,
        spec;
        outputs=:product,
        demands=[:product, :labor],
        activity_start=100.0,
        name=:firm,
    )

    @test added === model.agents[1]
    @test model.agent_refs[1] == _GEMB_AR3C.AgentRef(:firm)

    @test length(model.agents) ==
          length(model.agent_refs) ==
          length(model.agent_records) == 1

    @test model.agent_index[:firm] == 1
    @test model.agent_ref_index[_GEMB_AR3C.AgentRef(:firm)] == 1

    # STEP 4 enriches the record but must not disturb STEP 3 alignment.
    @test model.agent_records[1] isa
          _GEMB_AR3C.AbstractAgentRecord
end

println("GEMB agent registry alignment tests passed.")
