# ================================================================
# test_claimRate_equilibrium_gemb_v1.jl
#
# Full general-equilibrium regression for the generic claim_rate
# modifier under the ActivityDemand architecture.
#
# Commodities:
#   1. product
#   2. labor   (numeraire)
#   3. claim
#
# Agents:
#   1. Firm:
#      - one unit of labor produces one unit of product;
#      - purchases claim services equal in value to 20% of its
#        ordinary labor-input expenditure.
#
#   2. Worker:
#      - owns 100 units of labor;
#      - consumes product through the utility/activity representation;
#      - purchases claim services equal in value to 10% of ordinary
#        product expenditure.
#
#   3. Claim issuer:
#      - owns 320/11 units of claim;
#      - consumes product through the utility/activity representation.
#
# The test deliberately uses the same generic claim_rate mechanism
# for both the producer and the compensated-demand consumer. There are
# no CESClaimSpec or DCESClaimSpec objects.
#
# Analytic equilibrium with p_labor = 1:
#
#   p_product = 1.2
#   p_labor   = 1.0
#   p_claim   = 1.0
#
#   firm activity  = 100
#   worker utility = 2500/33
#   issuer utility = 800/33
#
# Claim demands:
#
#   firm   = 20
#   worker = 100/11
#   total  = 320/11 = claim supply
#
# This is the V13 replacement for the old claim-equilibrium regression
# that used CESClaimSpec/DCESClaimSpec.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB

@testset "GEMB generic ad valorem claim equilibrium" begin
    tau_firm = 0.20
    tau_consumer = 0.10
    labor_supply = 100.0
    claim_supply = 320.0 / 11.0

    # ------------------------------------------------------------
    # 1. Producer: labor -> product, plus an ad valorem claim
    # ------------------------------------------------------------

    firm_spec = DCESSpec(
        [1.0];
        es=0.0,
        alpha=1.0,
        xi=[0.0],
    )

    firm = build_agent(
        firm_spec;
        output_indices=[1],
        output_coefficients=[1.0],
        demand_indices=[2],
        claim_rate=tau_firm,
        claim_index=3,
        activity_start=100.0,
        activity_lower_bound=0.0,
        activity_upper_bound=Inf,
        name=:firm,
    )

    # ------------------------------------------------------------
    # 2. Worker: compensated product demand, plus the same generic
    #    ad valorem claim mechanism
    # ------------------------------------------------------------

    worker_spec = CESSpec(
        [1.0];
        es=1.0,
        alpha=1.0,
    )

    worker = build_agent(
        worker_spec;
        demand_indices=[1],
        endowment_indices=[2],
        endowment_quantities=[labor_supply],
        claim_rate=tau_consumer,
        claim_index=3,
        activity_start=75.0,
        activity_lower_bound=0.0,
        activity_upper_bound=Inf,
        name=:worker,
    )

    # ------------------------------------------------------------
    # 3. Claim issuer: owns claim and consumes product
    # ------------------------------------------------------------

    issuer_spec = DCESSpec(
        [1.0];
        es=0.0,
        alpha=1.0,
        xi=[0.0],
    )

    claim_issuer = build_agent(
        issuer_spec;
        demand_indices=[1],
        endowment_indices=[3],
        endowment_quantities=[claim_supply],
        activity_start=24.0,
        activity_lower_bound=0.0,
        activity_upper_bound=Inf,
        name=:claim_issuer,
    )

    # Each ActivityDemand agent owns exactly one local activity variable.
    @test agent_variable_count(firm) == 1
    @test agent_variable_count(worker) == 1
    @test agent_variable_count(claim_issuer) == 1

    # ------------------------------------------------------------
    # 4. General-equilibrium model
    # ------------------------------------------------------------

    model = NetSupplyEquilibriumModel(
        AbstractNetSupplyAgent[
            firm,
            worker,
            claim_issuer,
        ],
        [:product, :labor, :claim];
        numeraire_index=2,
        numeraire_value=1.0,
        price_lower_bounds=[0.0, 0.0, 0.0],
        price_upper_bounds=[Inf, Inf, Inf],
    )

    result = solve_equilibrium_model_mcp_jump(
        model;
        p0=[1.1, 1.0, 0.9],
        residual_tol=1.0e-8,
        silent=true,
    )

    # ------------------------------------------------------------
    # 5. Analytic benchmark
    # ------------------------------------------------------------

    expected_prices = [1.2, 1.0, 1.0]
    expected_firm_activity = labor_supply
    expected_worker_utility =
        labor_supply / ((1.0 + tau_consumer) * expected_prices[1])
    expected_issuer_utility =
        claim_supply * expected_prices[3] / expected_prices[1]

    @test isapprox(
        expected_worker_utility,
        2500.0 / 33.0;
        atol=1.0e-12,
        rtol=1.0e-12,
    )
    @test isapprox(
        expected_issuer_utility,
        800.0 / 33.0;
        atol=1.0e-12,
        rtol=1.0e-12,
    )

    # ------------------------------------------------------------
    # 6. Equilibrium regression
    # ------------------------------------------------------------

    @test result.solved
    @test result.mcp_solved

    @test isapprox(
        result.prices,
        expected_prices;
        atol=1.0e-7,
        rtol=1.0e-7,
    )

    firm_activity = result.agent_variable_values[1][1]
    worker_utility = result.agent_variable_values[2][1]
    issuer_utility = result.agent_variable_values[3][1]

    @test isapprox(
        firm_activity,
        expected_firm_activity;
        atol=1.0e-7,
        rtol=1.0e-7,
    )
    @test isapprox(
        worker_utility,
        expected_worker_utility;
        atol=1.0e-7,
        rtol=1.0e-7,
    )
    @test isapprox(
        issuer_utility,
        expected_issuer_utility;
        atol=1.0e-7,
        rtol=1.0e-7,
    )

    # ------------------------------------------------------------
    # 7. Economic identities implied by the generic modifier
    # ------------------------------------------------------------

    p_product, p_labor, p_claim = result.prices

    firm_base_expenditure = p_labor * firm_activity
    firm_claim_demand =
        tau_firm * firm_base_expenditure / p_claim

    worker_base_expenditure = p_product * worker_utility
    worker_claim_demand =
        tau_consumer * worker_base_expenditure / p_claim

    @test isapprox(
        firm_claim_demand,
        20.0;
        atol=1.0e-7,
        rtol=1.0e-7,
    )
    @test isapprox(
        worker_claim_demand,
        100.0 / 11.0;
        atol=1.0e-7,
        rtol=1.0e-7,
    )
    @test isapprox(
        firm_claim_demand + worker_claim_demand,
        claim_supply;
        atol=1.0e-7,
        rtol=1.0e-7,
    )

    # Producer zero-profit condition including the claim wedge.
    @test isapprox(
        p_product,
        (1.0 + tau_firm) * p_labor;
        atol=1.0e-7,
        rtol=1.0e-7,
    )

    # Worker expenditure balance including the claim.
    @test isapprox(
        (1.0 + tau_consumer) * worker_base_expenditure,
        labor_supply * p_labor;
        atol=1.0e-7,
        rtol=1.0e-7,
    )

    # Claim issuer expenditure equals claim-endowment income.
    @test isapprox(
        p_product * issuer_utility,
        claim_supply * p_claim;
        atol=1.0e-7,
        rtol=1.0e-7,
    )

    # Product and claim demands jointly reproduce the analytic allocation.
    @test isapprox(
        worker_utility + issuer_utility,
        firm_activity;
        atol=1.0e-7,
        rtol=1.0e-7,
    )

    # Solver-level equilibrium diagnostics.
    @test maximum(abs, result.total_net_supply) <= 1.0e-7
    @test result.max_natural_residual <= 1.0e-8
end
