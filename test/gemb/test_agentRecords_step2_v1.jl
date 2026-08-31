# ================================================================
# test_agentRecords_step2_v1.jl
#
# GEMB agent-record STEP 2:
# GEMBModel owns an initially empty economic-record registry.
# ================================================================

using Test
using GeneralEquilibriumModeling

const _GEMB_AR2 = GeneralEquilibriumModeling.GEMB


@testset "GEMB agent records STEP 2" begin
    model = _GEMB_AR2.GEMBModel(
        [:product, :labor];
        numeraire=:product,
        numeraire_value=1.0,
    )

    @test hasfield(typeof(model), :agent_records)

    @test model.agent_records isa Vector{_GEMB_AR2.AbstractAgentRecord}

    @test isempty(model.agents)
    @test isempty(model.agent_refs)
    @test isempty(model.agent_records)
    @test isempty(model.agent_index)
    @test isempty(model.agent_ref_index)

    @test model.commodity_names == [:product, :labor]
    @test model.commodity_index == Dict(
        :product => 1,
        :labor => 2,
    )
    @test model.numeraire == :product
    @test model.numeraire_value == 1.0

    # STEP 2 is storage-only. Registry alignment for inserted agents is
    # deliberately introduced in STEP 3.
    @test length(model.agents) ==
          length(model.agent_refs) ==
          length(model.agent_records) == 0
end

println("GEMB agent records STEP 2 tests passed.")
