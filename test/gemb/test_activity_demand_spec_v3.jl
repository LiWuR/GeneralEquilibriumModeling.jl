using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB

@testset "GEMB ActivityDemandSpec V11" begin
    @test isdefined(GEMB, :AbstractActivityDemandSpec)
    @test isdefined(GEMB, :ActivityDemandSpec)
    @test isdefined(GEMB, :activity_demand)

    # ------------------------------------------------------------
    # 1. Generic ActivityDemandSpec numerical protocol
    # ------------------------------------------------------------
    generic_spec = ActivityDemandSpec(
        (activity, prices) -> activity .* [0.4, 0.6],
    )

    @test activity_demand(generic_spec, 10.0, [1.0, 2.0]) ≈ [4.0, 6.0]

    generic_observed_spec = ActivityDemandSpec(
        (activity, prices, observed) ->
            activity .* [0.5 + observed[1], 0.5 - observed[1]],
    )

    @test activity_demand(
        generic_observed_spec,
        10.0,
        [1.0, 1.0],
        [0.1],
    ) ≈ [6.0, 4.0]

    # ------------------------------------------------------------
    # 2. Generic producer construction
    # ------------------------------------------------------------
    generic_producer = build_agent(
        generic_spec;
        output_indices=[1],
        output_coefficients=[1.0],
        demand_indices=[2, 3],
        activity_start=10.0,
        name=:generic_producer,
    )

    @test generic_producer isa GEM.NetSupplyAgent
    @test agent_condition_rule(generic_producer) isa UnitRevenueExpenditureBalanceConditions

    # ------------------------------------------------------------
    # 3. Generic compensated-demand consumer construction
    # ------------------------------------------------------------
    generic_consumer = build_agent(
        generic_spec;
        demand_indices=[1, 2],
        endowment_indices=[1, 2],
        endowment_quantities=[10.0, 10.0],
        activity_start=10.0,
        name=:generic_consumer,
    )

    @test generic_consumer isa GEM.NetSupplyAgent
    @test agent_condition_rule(generic_consumer) isa TotalRevenueExpenditureBalanceConditions

    # ------------------------------------------------------------
    # 4. CES uses the same ActivityDemandSpec protocol
    # ------------------------------------------------------------
    ces_spec = CESSpec(
        [0.5, 0.5];
        es=1.0,
        alpha=1.0,
    )

    ces_demand = activity_demand(ces_spec, 10.0, [1.0, 1.0])
    @test ces_demand isa AbstractVector
    @test length(ces_demand) == 2
    @test all(isfinite, ces_demand)

    ces_producer = build_agent(
        ces_spec;
        output_indices=[1],
        output_coefficients=[1.0],
        demand_indices=[2, 3],
        activity_start=10.0,
        name=:ces_producer,
    )
    @test ces_producer isa GEM.NetSupplyAgent
    @test agent_condition_rule(ces_producer) isa UnitRevenueExpenditureBalanceConditions

    ces_consumer = build_agent(
        ces_spec;
        demand_indices=[1, 2],
        endowment_indices=[1, 2],
        endowment_quantities=[10.0, 10.0],
        activity_start=10.0,
        name=:ces_consumer,
    )
    @test ces_consumer isa GEM.NetSupplyAgent
    @test agent_condition_rule(ces_consumer) isa TotalRevenueExpenditureBalanceConditions

    # ------------------------------------------------------------
    # 5. DCES uses the same ActivityDemandSpec protocol
    # ------------------------------------------------------------
    dces_spec = DCESSpec(
        [0.5, 0.5];
        es=1.0,
        alpha=1.0,
        xi=[1.0, 2.0],
    )

    dces_demand = activity_demand(dces_spec, 10.0, [1.0, 1.0])
    @test dces_demand isa AbstractVector
    @test length(dces_demand) == 2
    @test all(isfinite, dces_demand)

    dces_producer = build_agent(
        dces_spec;
        output_indices=[1],
        output_coefficients=[1.0],
        demand_indices=[2, 3],
        activity_start=10.0,
        name=:dces_producer,
    )
    @test dces_producer isa GEM.NetSupplyAgent
    @test agent_condition_rule(dces_producer) isa TotalRevenueExpenditureBalanceConditions

    dces_consumer = build_agent(
        dces_spec;
        demand_indices=[1, 2],
        endowment_indices=[1, 2],
        endowment_quantities=[20.0, 20.0],
        activity_start=10.0,
        name=:dces_consumer,
    )
    @test dces_consumer isa GEM.NetSupplyAgent
    @test agent_condition_rule(dces_consumer) isa TotalRevenueExpenditureBalanceConditions

    # ------------------------------------------------------------
    # 6. Nonlinear generic activity demand remains user-selectable
    # ------------------------------------------------------------
    #
    # GEMB does not reject a nonlinear ActivityDemandSpec. With no explicit
    # producer condition or rule override, the producer defaults to
    # UnitRevenueExpenditureBalanceConditions. The user remains responsible for deciding whether
    # that rule is economically appropriate.
    general_spec = ActivityDemandSpec(
        (activity, prices) -> [activity^2, activity^2],
    )

    general_producer = build_agent(
        general_spec;
        output_indices=[1],
        output_coefficients=[1.0],
        demand_indices=[2, 3],
        activity_start=1.0,
        name=:general_producer,
    )

    @test general_producer isa GEM.NetSupplyAgent
    @test agent_condition_rule(general_producer) isa UnitRevenueExpenditureBalanceConditions

    general_total_producer = build_agent(
        general_spec;
        output_indices=[1],
        output_coefficients=[1.0],
        demand_indices=[2, 3],
        condition_rule=TotalRevenueExpenditureBalanceConditions(),
        activity_start=1.0,
        name=:general_total_producer,
    )

    @test agent_condition_rule(general_total_producer) isa TotalRevenueExpenditureBalanceConditions

    # The same specification remains valid for a compensated-demand consumer.
    general_consumer = build_agent(
        general_spec;
        demand_indices=[1, 2],
        endowment_indices=[1, 2],
        endowment_quantities=[10.0, 10.0],
        activity_start=1.0,
        name=:general_consumer,
    )

    @test general_consumer isa GEM.NetSupplyAgent
    @test agent_condition_rule(general_consumer) isa TotalRevenueExpenditureBalanceConditions
end
