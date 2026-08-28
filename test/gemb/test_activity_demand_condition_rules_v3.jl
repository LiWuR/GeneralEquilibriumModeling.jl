# ================================================================
# test_activity_demand_condition_rules_v3.jl
#
# Focused tests for GEMB default condition-rule selection and explicit
# user override.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


@testset "GEMB activity-demand condition-rule defaults" begin
    generic_spec = ActivityDemandSpec(
        (activity, prices) -> activity .* [0.5, 0.5],
    )

    @test !hasproperty(generic_spec, :activity_structure)

    generic_firm = build_agent(
        generic_spec;
        output_indices=[1],
        demand_indices=[2, 3],
        activity_start=10.0,
        name=:generic_firm,
    )
    @test agent_condition_rule(generic_firm) isa UnitRevenueExpenditureBalanceConditions

    ces_firm = build_agent(
        CESSpec([0.5, 0.5]);
        output_indices=[1],
        demand_indices=[2, 3],
        activity_start=10.0,
        name=:ces_firm,
    )
    @test agent_condition_rule(ces_firm) isa UnitRevenueExpenditureBalanceConditions

    homogeneous_dces_firm = build_agent(
        DCESSpec(
            [0.5, 0.5];
            xi=[0.0, 0.0],
        );
        output_indices=[1],
        demand_indices=[2, 3],
        activity_start=10.0,
        name=:homogeneous_dces_firm,
    )
    @test agent_condition_rule(homogeneous_dces_firm) isa UnitRevenueExpenditureBalanceConditions

    displaced_dces_firm = build_agent(
        DCESSpec(
            [0.5, 0.5];
            xi=[1.0, 2.0],
        );
        output_indices=[1],
        demand_indices=[2, 3],
        activity_start=10.0,
        name=:displaced_dces_firm,
    )
    @test agent_condition_rule(displaced_dces_firm) isa TotalRevenueExpenditureBalanceConditions

    ces_with_endowment = build_agent(
        CESSpec([0.5, 0.5]);
        output_indices=[1],
        demand_indices=[2, 3],
        endowment_indices=[4],
        endowment_quantities=[1.0],
        activity_start=10.0,
        name=:ces_with_endowment,
    )
    @test agent_condition_rule(ces_with_endowment) isa TotalRevenueExpenditureBalanceConditions

    generic_with_endowment = build_agent(
        generic_spec;
        output_indices=[1],
        demand_indices=[2, 3],
        endowment_indices=[4],
        endowment_quantities=[1.0],
        activity_start=10.0,
        name=:generic_with_endowment,
    )
    @test agent_condition_rule(generic_with_endowment) isa TotalRevenueExpenditureBalanceConditions

    custom_spec = ActivityDemandSpec(
        (activity, prices) -> activity .* [0.5, 0.5];
        producer_condition_function=
            (variables, prices, net_supply) -> [
                -sum(prices .* net_supply),
            ],
    )

    custom_firm = build_agent(
        custom_spec;
        output_indices=[1],
        demand_indices=[2, 3],
        activity_start=10.0,
        name=:custom_firm,
    )
    @test agent_condition_rule(custom_firm) isa ExplicitAgentConditions
end


@testset "GEMB activity-demand condition-rule user override" begin
    ces_spec = CESSpec([0.5, 0.5])

    ces_force_total = build_agent(
        ces_spec;
        output_indices=[1],
        demand_indices=[2, 3],
        condition_rule=TotalRevenueExpenditureBalanceConditions(),
        activity_start=10.0,
        name=:ces_force_total,
    )
    @test agent_condition_rule(ces_force_total) isa TotalRevenueExpenditureBalanceConditions

    displaced_dces_force_unit = build_agent(
        DCESSpec(
            [0.5, 0.5];
            xi=[1.0, 2.0],
        );
        output_indices=[1],
        demand_indices=[2, 3],
        condition_rule=UnitRevenueExpenditureBalanceConditions(),
        activity_start=10.0,
        name=:displaced_dces_force_unit,
    )
    @test agent_condition_rule(displaced_dces_force_unit) isa UnitRevenueExpenditureBalanceConditions

    ces_endowment_force_unit = build_agent(
        ces_spec;
        output_indices=[1],
        demand_indices=[2, 3],
        endowment_indices=[4],
        endowment_quantities=[1.0],
        condition_rule=UnitRevenueExpenditureBalanceConditions(),
        activity_start=10.0,
        name=:ces_endowment_force_unit,
    )
    @test agent_condition_rule(ces_endowment_force_unit) isa UnitRevenueExpenditureBalanceConditions

    custom_spec = ActivityDemandSpec(
        (activity, prices) -> activity .* [0.5, 0.5];
        producer_condition_function=
            (variables, prices, net_supply) -> [
                -sum(prices .* net_supply),
            ],
    )

    custom_force_unit = build_agent(
        custom_spec;
        output_indices=[1],
        demand_indices=[2, 3],
        condition_rule=UnitRevenueExpenditureBalanceConditions(),
        activity_start=10.0,
        name=:custom_force_unit,
    )
    @test agent_condition_rule(custom_force_unit) isa UnitRevenueExpenditureBalanceConditions

    positional_force_total = build_agent(
        ces_spec;
        output_indices=[1],
        demand_indices=[2, 3],
        condition_rule=TotalRevenueExpenditureBalanceConditions(),
        activity_start=10.0,
        name=:positional_force_total,
    )
    @test agent_condition_rule(positional_force_total) isa TotalRevenueExpenditureBalanceConditions
end


@testset "GEMB activity-demand consumer default uses TREBC" begin
    consumer = build_agent(
        CESSpec([0.5, 0.5]);
        demand_indices=[1, 2],
        endowment_indices=[1, 2],
        endowment_quantities=[10.0, 10.0],
        activity_start=10.0,
        name=:consumer,
    )

    @test agent_condition_rule(consumer) isa TotalRevenueExpenditureBalanceConditions
end

println("GEMB activity-demand condition-rule V2 tests passed.")
