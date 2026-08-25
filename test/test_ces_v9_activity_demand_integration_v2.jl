# ================================================================
# test_ces_v9_activity_demand_integration_v2.jl
#
# Regression tests for:
#   1. claim-free CES_v8 numerical layer;
#   2. V13 ActivityDemandSpec integration;
#   3. generic claim_rate ownership of claim behavior.
#
# Run in a fresh Julia session after GEMB.jl includes:
#
#   include("CES_v8.jl")
#   include("net_supply_agent_builders_v13.jl")
# ================================================================

using Test
using GEM
using GEMB

@testset "CES_v8 claim-free numerical layer" begin
    @test isdefined(GEMB, :CES_input)
    @test isdefined(GEMB, :CES_cost)
    @test isdefined(GEMB, :CES_demand)
    @test isdefined(GEMB, :DCES_input)
    @test isdefined(GEMB, :DCES_cost)
    @test isdefined(GEMB, :DCES_demand)

    # Old CES/DCES-specific claim API must be gone in a fresh session.
    @test !isdefined(GEMB, :CES_input_claim)
    @test !isdefined(GEMB, :CES_cost_claim)
    @test !isdefined(GEMB, :CES_demand_claim)
    @test !isdefined(GEMB, :DCES_input_claim)
    @test !isdefined(GEMB, :DCES_cost_claim)
    @test !isdefined(GEMB, :DCES_demand_claim)

    beta = [0.4, 0.6]
    p = [1.0, 2.0]

    x = GEMB.CES_input(beta, 10.0, p; es=1.0, alpha=1.0)
    c = GEMB.CES_cost(beta, 10.0, p; es=1.0, alpha=1.0)
    @test length(x) == 2
    @test isapprox(sum(p .* x), c; atol=1e-10, rtol=1e-10)

    d = GEMB.CES_demand(beta, 100.0, p; es=1.0, alpha=1.0)
    @test isapprox(sum(p .* d), 100.0; atol=1e-10, rtol=1e-10)

    xi = [2.0, 1.0]
    xd = GEMB.DCES_input(beta, 8.0, p; es=0.8, alpha=1.2, xi=xi)
    cd = GEMB.DCES_cost(beta, 8.0, p; es=0.8, alpha=1.2, xi=xi)
    @test isapprox(sum(p .* xd), cd; atol=1e-9, rtol=1e-9)
end

@testset "V13 activity-demand integration" begin
    ces = CESSpec([0.4, 0.6]; es=1.0, alpha=1.0)
    p = [1.0, 2.0]
    a = 10.0

    x_spec = activity_demand(ces, a, p)
    x_direct = GEMB.CES_input(
        ces.beta,
        a,
        p;
        es=ces.es,
        alpha=ces.alpha,
    )
    @test x_spec ≈ x_direct

    dces = DCESSpec(
        [0.4, 0.6];
        es=0.8,
        alpha=1.2,
        xi=[2.0, 1.0],
    )

    xd_spec = activity_demand(dces, a, p)
    xd_direct = GEMB.DCES_input(
        dces.beta,
        a,
        p;
        es=dces.es,
        alpha=dces.alpha,
        xi=dces.xi,
    )
    @test xd_spec ≈ xd_direct
end

@testset "Claim behavior belongs to generic modifier layer" begin
    spec = CESSpec([1.0]; es=0.0, alpha=1.0)

    agent = build_agent(
        spec;
        output_indices=[1],
        demand_indices=[2],
        claim_rate=-0.20,
        claim_index=3,
        activity_start=100.0,
        name=:claim_firm,
    )

    @test agent isa GEM.NetSupplyAgent
    @test !isdefined(GEMB, :CESClaimSpec)
    @test !isdefined(GEMB, :DCESClaimSpec)
end

println("CES_v8 / ActivityDemand V13 integration tests completed.")
