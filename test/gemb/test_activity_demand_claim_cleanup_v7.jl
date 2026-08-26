# ================================================================
# test_activity_demand_claim_cleanup_v7.jl
#
# Regression tests for the claim_rate-only public API.
#
# Public interface:
#
#     claim_rate = tau
#     claim_index = commodity_index
#
# claim_rate remains an internal representation and is not required
# in ordinary model-building code.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "GEMB claim_rate public API" begin
    @test !isdefined(GEMB, :CESClaimSpec)
    @test !isdefined(GEMB, :DCESClaimSpec)

    base_spec = CESSpec(
        [1.0];
        es=0.0,
        alpha=1.0,
    )

    # ------------------------------------------------------------
    # 1. Validation
    # ------------------------------------------------------------

    @test_throws ArgumentError build_agent(
        base_spec;
        output_indices=[1],
        demand_indices=[2],
        claim_rate=0.20,
    )

    @test_throws ArgumentError build_agent(
        base_spec;
        output_indices=[1],
        demand_indices=[2],
        claim_index=3,
    )

    @test_throws ArgumentError build_agent(
        base_spec;
        output_indices=[1],
        demand_indices=[2, 3],
        claim_rate=0.20,
        claim_index=3,
    )

    @test_throws ArgumentError build_agent(
        base_spec;
        output_indices=[1],
        demand_indices=[2],
        claim_rate=-1.0,
        claim_index=3,
    )

    @test_throws ArgumentError build_agent(
        base_spec;
        output_indices=[1],
        demand_indices=[2],
        claim_rate=Inf,
        claim_index=3,
    )

    @test_throws ArgumentError build_agent(
        base_spec;
        output_indices=[1],
        demand_indices=[2],
        claim_rate="0.20",
        claim_index=3,
    )

    # The old public keyword must no longer be accepted.
    @test_throws MethodError build_agent(
        base_spec;
        output_indices=[1],
        demand_indices=[2],
        claim=0.20,
        claim_index=3,
    )


    # ------------------------------------------------------------
    # 2. Positive ad valorem claim
    # ------------------------------------------------------------

    ces_firm = build_agent(
        base_spec;
        output_indices=[1],
        demand_indices=[2],
        claim_rate=0.25,
        claim_index=3,
        activity_start=10.0,
        name=:ces_firm,
    )

    ces_variables = [10.0]
    ces_prices = [1.25, 1.0, 2.0]

    ces_supply = agent_net_supply(
        ces_firm,
        ces_variables,
        ces_prices,
    )

    @test agent_condition_rule(ces_firm) isa UnitProfitConditions

    ces_unit_supply = agent_net_supply(
        ces_firm,
        [1.0],
        ces_prices,
    )

    @test isapprox(
        -sum(ces_prices .* ces_unit_supply),
        0.0;
        atol=1.0e-12,
        rtol=0.0,
    )

    @test ces_supply ≈ [10.0, -10.0, -1.25]
    @test ces_prices[3] * (-ces_supply[3]) ≈
        0.25 * ces_prices[2] * (-ces_supply[2])


    # ------------------------------------------------------------
    # 3. Repeated positional construction
    # ------------------------------------------------------------

    ces_firm_repeat = build_agent(
        base_spec;
        output_indices=[1],
        demand_indices=[2],
        claim_rate=0.25,
        claim_index=3,
        activity_start=10.0,
        name=:ces_firm_repeat,
    )

    @test agent_net_supply(
        ces_firm_repeat,
        ces_variables,
        ces_prices,
    ) ≈ ces_supply
    @test agent_condition_rule(ces_firm_repeat) isa UnitProfitConditions


    # ------------------------------------------------------------
    # 4. Negative claim rate / subsidy
    # ------------------------------------------------------------

    dces_spec = DCESSpec(
        [1.0];
        es=0.0,
        alpha=1.0,
        xi=[0.0],
    )

    dces_firm = build_agent(
        dces_spec;
        output_indices=[1],
        demand_indices=[2],
        claim_rate=-0.20,
        claim_index=3,
        activity_start=100.0,
        name=:dces_firm,
    )

    dces_variables = [100.0]
    dces_prices = [0.8, 1.0, -20.0]

    dces_supply = agent_net_supply(
        dces_firm,
        dces_variables,
        dces_prices,
    )

    @test agent_condition_rule(dces_firm) isa UnitProfitConditions

    dces_unit_supply = agent_net_supply(
        dces_firm,
        [1.0],
        dces_prices,
    )

    @test isapprox(
        -sum(dces_prices .* dces_unit_supply),
        0.0;
        atol=1.0e-12,
        rtol=0.0,
    )

    @test dces_supply ≈ [100.0, -100.0, -1.0]
    @test -dces_supply[3] > 0.0
    @test dces_prices[3] * (-dces_supply[3]) ≈
        -0.20 * dces_prices[2] * (-dces_supply[2])


    # ------------------------------------------------------------
    # 5. Activity-demand consumer
    # ------------------------------------------------------------

    consumer_spec = ActivityDemandSpec(
        (utility, prices) -> [utility],
    )

    consumer = build_agent(
        consumer_spec;
        demand_indices=[1],
        endowment_indices=[1],
        endowment_quantities=[10.0],
        claim_rate=0.25,
        claim_index=2,
        activity_start=8.0,
        name=:consumer,
    )

    consumer_variables = [8.0]
    consumer_prices = [1.0, 2.0]

    consumer_supply = agent_net_supply(
        consumer,
        consumer_variables,
        consumer_prices,
    )

    consumer_conditions = agent_condition_rule(
        consumer,
    )(
        consumer_variables,
        consumer_prices,
        consumer_supply,
    )

    @test agent_condition_rule(consumer) isa ExplicitAgentConditions
    @test consumer_supply ≈ [2.0, -1.0]
    @test consumer_conditions ≈ [0.0]
    @test agent_variable_count(consumer) == 1


    # ------------------------------------------------------------
    # 6. Zero claim rate
    # ------------------------------------------------------------

    zero_claim_firm = build_agent(
        base_spec;
        output_indices=[1],
        demand_indices=[2],
        claim_rate=0.0,
        claim_index=3,
        activity_start=10.0,
    )

    zero_claim_supply = agent_net_supply(
        zero_claim_firm,
        [10.0],
        [1.0, 1.0, 0.0],
    )

    @test agent_condition_rule(zero_claim_firm) isa UnitProfitConditions
    @test zero_claim_supply ≈ [10.0, -10.0, 0.0]
end


@testset "GEMB claim_rate negative-price equilibrium" begin
    TAU_TEST = -0.20
    WORKER_LABOR_TEST = 80.0
    ISSUER_LABOR_TEST = 20.0
    CLAIM_SUPPLY_TEST = 1.0

    subsidy_spec = DCESSpec(
        [1.0];
        es=0.0,
        alpha=1.0,
        xi=[0.0],
    )

    firm = build_agent(
        subsidy_spec;
        output_indices=[1],
        demand_indices=[2],
        claim_rate=TAU_TEST,
        claim_index=3,
        activity_start=95.0,
        name=:firm,
    )

    @test agent_condition_rule(firm) isa UnitProfitConditions

    worker = NetSupplyConsumerAgent(
        [1, 2],
        function (local_variables, local_prices)
            income = WORKER_LABOR_TEST * local_prices[2]
            product_demand = income / local_prices[1]
            return [-product_demand, WORKER_LABOR_TEST]
        end;
        name=:worker,
    )

    issuer = NetSupplyConsumerAgent(
        [2, 3],
        (local_variables, local_prices) ->
            [ISSUER_LABOR_TEST, CLAIM_SUPPLY_TEST];
        name=:claim_issuer,
    )

    model = EquilibriumModel(
        [firm, worker, issuer],
        [:product, :labor, :claim];
        numeraire_index=2,
        price_lower_bounds=[0.0, 0.0, -Inf],
    )

    result = solve_equilibrium_model_mcp_jump(
        model;
        p0=[0.9, 1.0, -10.0],
        residual_tol=1.0e-6,
        silent=true,
    )

    expected_activity =
        WORKER_LABOR_TEST + ISSUER_LABOR_TEST

    expected_product_price =
        1.0 + TAU_TEST

    expected_claim_price =
        TAU_TEST *
        expected_activity /
        CLAIM_SUPPLY_TEST

    @test result.solved
    @test result.mcp_solved

    @test isapprox(
        result.agent_variable_values[1][1],
        expected_activity;
        atol=1.0e-5,
        rtol=1.0e-6,
    )

    @test isapprox(
        result.prices[1],
        expected_product_price;
        atol=1.0e-6,
        rtol=1.0e-6,
    )

    @test isapprox(
        result.prices[2],
        1.0;
        atol=1.0e-12,
        rtol=0.0,
    )

    @test isapprox(
        result.prices[3],
        expected_claim_price;
        atol=1.0e-5,
        rtol=1.0e-6,
    )

    @test maximum(abs, result.total_net_supply) <= 1.0e-5
    @test result.max_natural_residual <= 1.0e-6
end


println("claim_rate API regression tests completed.")
