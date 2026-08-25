# ================================================================
# test_gembModel_noPureEndowment_v1.jl
#
# Verify the current GEMB design decision that there is no
# pure-endowment build_agent/add_agent! construction path.
#
# Current intended behavior:
#
#   - build_agent requires a behavioral specification (or a legacy
#     behavioral function accepted by the compatibility router);
#   - fixed exogenous net supply, if needed, is constructed directly
#     with GEM.NetSupplyAgent;
#   - GEMBModel.add_agent! therefore requires a behavioral `spec`.
#
# This test makes no source changes.
# ================================================================

using Test
using GEM
using GEMB


@testset "GEMBModel: no pure-endowment agent builder" begin

    # ------------------------------------------------------------
    # 1. Current low-level GEMB router rejects no-behavior agents.
    # ------------------------------------------------------------

    err = try
        build_agent(
            ;
            endowment_indices=[2],
            endowment_quantities=10.0,
            name=:owner,
        )
        nothing
    catch e
        e
    end

    @test err isa ArgumentError

    if err isa ArgumentError
        message = sprint(showerror, err)
        @test occursin(
            "build_agent requires a behavioral specification",
            message,
        )
        @test occursin(
            "GEM.NetSupplyAgent",
            message,
        )
    end


    # ------------------------------------------------------------
    # 2. High-level GEMBModel API likewise has no keyword-only
    #    add_agent!(model; ...) pure-endowment method.
    # ------------------------------------------------------------

    model = GEMBModel(
        [:product, :labor];
        numeraire=:product,
    )

    before_agents = copy(model.agents)
    before_index = copy(model.agent_index)

    @test_throws MethodError add_agent!(
        model;
        endowments=:labor,
        endowment_quantities=10.0,
        name=:owner,
    )

    @test model.agents == before_agents
    @test model.agent_index == before_index


    # ------------------------------------------------------------
    # 3. Endowments remain valid when attached to a behavioral
    #    consumer agent. This distinguishes "agent with endowment"
    #    from the removed "pure-endowment agent".
    # ------------------------------------------------------------

    household = add_agent!(
        model,
        CESSpec([1.0]);
        demands=:product,
        endowments=:labor,
        endowment_quantities=10.0,
        name=:household,
    )

    @test household isa GEM.AbstractNetSupplyAgent
    @test length(model.agents) == 1
    @test model.agents[1] === household
    @test model.agent_index == Dict(
        :household => 1,
    )
end

println("GEMBModel no-pure-endowment regression tests passed.")
