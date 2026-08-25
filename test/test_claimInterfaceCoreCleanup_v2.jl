# ================================================================
# test_claimInterfaceCoreCleanup_v2.jl
#
# Focused regression for the claim_rate-only CORE interface.
# ================================================================

using Test
using GEM
using GEMB


@testset "Claim-rate CORE interface" begin
    retired_claim_type =
        Symbol(
            "AdValorem" *
            "Claim",
        )

    retired_modifier_type =
        Symbol(
            "AbstractDemand" *
            "Modifier",
        )

    @test !isdefined(
        GEMB,
        retired_claim_type,
    )

    @test !isdefined(
        GEMB,
        retired_modifier_type,
    )

    @test isdefined(
        GEMB,
        :_ClaimRateModifier,
    )

    @test isdefined(
        GEMB,
        :_AbstractDemandModifier,
    )

    @test !(
        :_ClaimRateModifier in names(
            GEMB;
            all=false,
            imported=false,
        )
    )

    spec =
        CESSpec(
            [1.0];
            es=1.0,
            alpha=1.0,
        )

    agent =
        build_agent(
            spec;
            output_indices=[1],
            output_coefficients=[1.0],
            demand_indices=[2],
            claim_rate=0.25,
            claim_index=3,
            activity_start=10.0,
            name=:claim_rate_firm,
        )

    @test agent isa GEM.NetSupplyAgent

    supply =
        GEM.agent_net_supply(
            agent,
            [10.0],
            [1.25, 1.0, 2.0],
        )

    # Base input expenditure is 10. Claim expenditure is 0.25 * 10 = 2.5,
    # so at claim price 2 the claim quantity is 1.25.
    @test isapprox(
        supply,
        [10.0, -10.0, -1.25];
        atol=1.0e-12,
        rtol=1.0e-12,
    )
end

println("Claim-rate CORE interface V2 tests passed.")
