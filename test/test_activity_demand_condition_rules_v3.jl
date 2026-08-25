# ================================================================
# test_activity_demand_condition_rules_v3.jl
#
# Focused tests for GEMB default condition-rule selection and explicit
# user override.
# ================================================================

using Test
using GEM
using GEMB


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
    @test agent_condition_rule(generic_firm) isa UnitProfitConditions

    ces_firm = build_agent(
        CESSpec([0.5, 0.5]);
        output_indices=[1],
        demand_indices=[2, 3],
        activity_start=10.0,
        name=:ces_firm,
    )
    @test agent_condition_rule(ces_firm) isa UnitProfitConditions

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
    @test agent_condition_rule(homogeneous_dces_firm) isa UnitProfitConditions

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
    @test agent_condition_rule(displaced_dces_firm) isa TotalProfitConditions

    ces_with_endowment = build_agent(
        CESSpec([0.5, 0.5]);
        output_indices=[1],
        demand_indices=[2, 3],
        endowment_indices=[4],
        endowment_quantities=[1.0],
        activity_start=10.0,
        name=:ces_with_endowment,
    )
    @test agent_condition_rule(ces_with_endowment) isa TotalProfitConditions

    generic_with_endowment = build_agent(
        generic_spec;
        output_indices=[1],
        demand_indices=[2, 3],
        endowment_indices=[4],
        endowment_quantities=[1.0],
        activity_start=10.0,
        name=:generic_with_endowment,
    )
    @test agent_condition_rule(generic_with_endowment) isa TotalProfitConditions

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
        condition_rule=TotalProfitConditions(),
        activity_start=10.0,
        name=:ces_force_total,
    )
    @test agent_condition_rule(ces_force_total) isa TotalProfitConditions

    displaced_dces_force_unit = build_agent(
        DCESSpec(
            [0.5, 0.5];
            xi=[1.0, 2.0],
        );
        output_indices=[1],
        demand_indices=[2, 3],
        condition_rule=UnitProfitConditions(),
        activity_start=10.0,
        name=:displaced_dces_force_unit,
    )
    @test agent_condition_rule(displaced_dces_force_unit) isa UnitProfitConditions

    ces_endowment_force_unit = build_agent(
        ces_spec;
        output_indices=[1],
        demand_indices=[2, 3],
        endowment_indices=[4],
        endowment_quantities=[1.0],
        condition_rule=UnitProfitConditions(),
        activity_start=10.0,
        name=:ces_endowment_force_unit,
    )
    @test agent_condition_rule(ces_endowment_force_unit) isa UnitProfitConditions

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
        condition_rule=UnitProfitConditions(),
        activity_start=10.0,
        name=:custom_force_unit,
    )
    @test agent_condition_rule(custom_force_unit) isa UnitProfitConditions

    positional_force_total = build_agent(
        ces_spec;
        output_indices=[1],
        demand_indices=[2, 3],
        condition_rule=TotalProfitConditions(),
        activity_start=10.0,
        name=:positional_force_total,
    )
    @test agent_condition_rule(positional_force_total) isa TotalProfitConditions
end


@testset "GEMB activity-demand consumer default remains explicit" begin
    consumer = build_agent(
        CESSpec([0.5, 0.5]);
        demand_indices=[1, 2],
        endowment_indices=[1, 2],
        endowment_quantities=[10.0, 10.0],
        activity_start=10.0,
        name=:consumer,
    )

    @test agent_condition_rule(consumer) isa ExplicitAgentConditions
end

println("GEMB activity-demand condition-rule V2 tests passed.")
