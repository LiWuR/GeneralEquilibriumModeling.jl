# ================================================================
# test_profit_condition_rule_dispatch_v2.jl
#
# Regression test for the final condition-rule classification.
#
# There is no activity_structure classification and no transitional
# legacy automatic condition-rule type type.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM

@testset "Profit condition rule dispatch V2" begin
    simple_supply = (variables, prices) -> begin
        z = variables[1]
        [z, -z]
    end

    default_firm = ProducerAgent(
        [1, 2],
        simple_supply;
        variable_names=[:activity],
        variable_start=[1.0],
        name=:default_firm,
    )

    @test agent_condition_rule(default_firm) isa UnitRevenueExpenditureBalanceConditions
    @test agent_uses_automatic_conditions(default_firm)
    @test !hasproperty(default_firm, :activity_structure)

    unit_firm = ProducerAgent(
        [1, 2],
        simple_supply;
        variable_names=[:activity],
        variable_start=[1.0],
        condition_rule=UnitRevenueExpenditureBalanceConditions(),
        name=:unit_firm,
    )

    @test agent_condition_rule(unit_firm) isa UnitRevenueExpenditureBalanceConditions
    @test agent_uses_automatic_conditions(unit_firm)

    total_firm = ProducerAgent(
        [1, 2],
        simple_supply;
        variable_names=[:activity],
        variable_start=[1.0],
        condition_rule=TotalRevenueExpenditureBalanceConditions(),
        name=:total_firm,
    )

    @test agent_condition_rule(total_firm) isa TotalRevenueExpenditureBalanceConditions
    @test agent_uses_automatic_conditions(total_firm)

    explicit_firm = ProducerAgent(
        [1, 2],
        simple_supply;
        variable_names=[:activity],
        variable_start=[1.0],
        condition_rule=ExplicitAgentConditions(
            (variables, prices, net_supply) -> [
                -sum(prices .* net_supply),
            ],
        ),
        name=:explicit_firm,
    )

    @test agent_condition_rule(explicit_firm) isa ExplicitAgentConditions
    @test !agent_uses_automatic_conditions(explicit_firm)

    @test !isdefined(GEM, Symbol("Automatic", "Profit", "Conditions"))
    @test !isdefined(GEM, :agent_activity_structure)
end

println("Profit condition rule dispatch V2 test passed.")
