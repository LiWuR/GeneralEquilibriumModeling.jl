# ================================================================
# test_gembModel_claimName_v1.jl
#
# Focused regression for corrected STEP 4:
#   high-level claim=:name -> low-level claim_index
#
# Current GEMB has no pure-endowment builder path.
# ================================================================

using Test
using GEM
using GEMB


@testset "GEMBModel named claim mapping" begin
    model = GEMBModel(
        [:product, :labor, :claim];
        numeraire=:product,
    )

    firm = add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        claim=:claim,
        claim_rate=0.2,
        activity_start=10.0,
        name=:firm,
    )

    @test firm isa GEM.AbstractNetSupplyAgent
    @test length(model.agents) == 1
    @test model.agents[1] === firm
    @test model.agent_index == Dict(:firm => 1)


    # claim is a high-level commodity name, not a low-level integer.
    before_agents = copy(model.agents)
    before_index = copy(model.agent_index)

    @test_throws ArgumentError add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        claim=:missing_claim,
        claim_rate=0.2,
        name=:bad_claim_name,
    )

    @test model.agents == before_agents
    @test model.agent_index == before_index


    # Supplying claim without claim_rate is rejected before build_agent.
    @test_throws ArgumentError add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        claim=:claim,
        name=:missing_claim_rate,
    )

    @test model.agents == before_agents
    @test model.agent_index == before_index


    # Direct integer claim mappings remain a low-level build_agent API.
    @test_throws ArgumentError add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        claim_index=3,
        claim_rate=0.2,
        name=:low_level_claim,
    )

    @test model.agents == before_agents
    @test model.agent_index == before_index
end

println("GEMBModel named-claim tests passed.")
