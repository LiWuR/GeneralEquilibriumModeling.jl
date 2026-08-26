# ================================================================
# test_endogenous_output_tax_auxiliary_v1.jl
#
# Regression test for an endogenous output-tax rate determined by an
# auxiliary government-budget equation.
# ================================================================

module TestEndogenousOutputTaxAuxiliaryV1

using Test
using GeneralEquilibriumModeling.GEM

const ATOL = 1.0e-7
const RTOL = 1.0e-7

@testset "Endogenous output tax and government budget" begin
    labor_endowment = 100.0
    government_purchase = 20.0

    tax_rate = AuxiliaryVariable(
        :tax_rate;
        start=0.15,
        lower_bound=0.0,
        upper_bound=0.95,
    )

    firm = ProducerAgent(
        [1, 2],
        function (variables, prices, observed_values)
            z = variables[1]
            p_product = prices[1]
            tau = observed_values[1]
            tax_payment = tau * p_product * z
            return [z, -z - tax_payment]
        end;
        variable_names=[:activity],
        variable_lower_bounds=[0.0],
        variable_upper_bounds=[Inf],
        variable_start=[95.0],
        observed_variables=[AuxiliaryVariableRef(:tax_rate)],
        name=:firm,
    )

    household = ConsumerAgent(
        [1, 2],
        function (variables, prices)
            income = labor_endowment * prices[2]
            product_demand = income / prices[1]
            return [-product_demand, labor_endowment]
        end;
        name=:household,
    )

    government = NetSupplyAgent(
        [1, 2],
        function (variables, prices, observed_values)
            z = observed_values[1]
            tau = observed_values[2]
            p_product = prices[1]
            tax_receipts = tau * p_product * z
            return [-government_purchase, tax_receipts]
        end;
        variable_names=Symbol[],
        observed_variables=[
            AgentVariableRef(:firm, :activity),
            AuxiliaryVariableRef(:tax_rate),
        ],
        name=:government,
    )

    government_budget = AuxiliaryEquation(
        :government_budget,
        :tax_rate,
        values -> begin
            z = values[1]
            p_product = values[2]
            tau = values[3]
            tau * p_product * z - p_product * government_purchase
        end;
        observed_variables=[
            AgentVariableRef(:firm, :activity),
            PriceVariableRef(:product),
            AuxiliaryVariableRef(:tax_rate),
        ],
    )

    model = EquilibriumModel(
        [firm, household, government],
        [:product, :labor];
        auxiliary_variables=[tax_rate],
        auxiliary_equations=[government_budget],
        numeraire_index=2,
        numeraire_value=1.0,
    )

    result = solve_equilibrium_model_mcp_jump(
        model;
        p0=[1.2, 1.0],
        auxiliary0=[0.15],
        residual_tol=1.0e-8,
        silent=true,
    )

    expected_activity = labor_endowment
    expected_tax_rate = government_purchase / labor_endowment
    expected_product_price =
        labor_endowment / (labor_endowment - government_purchase)
    expected_tax_receipts =
        expected_tax_rate * expected_product_price * expected_activity

    @test result.solved
    @test result.all_markets_clear
    @test isapprox(
        result.prices,
        [expected_product_price, 1.0];
        atol=ATOL,
        rtol=RTOL,
    )
    @test isapprox(
        result.agent_variable_values[1][1],
        expected_activity;
        atol=ATOL,
        rtol=RTOL,
    )
    @test isapprox(
        result.auxiliary_values[:tax_rate],
        expected_tax_rate;
        atol=ATOL,
        rtol=RTOL,
    )
    @test isapprox(
        result.agent_net_supplies[1],
        [expected_activity, -expected_activity - expected_tax_receipts];
        atol=ATOL,
        rtol=RTOL,
    )
    @test isapprox(
        result.agent_net_supplies[2],
        [-(labor_endowment - government_purchase), labor_endowment];
        atol=ATOL,
        rtol=RTOL,
    )
    @test isapprox(
        result.agent_net_supplies[3],
        [-government_purchase, expected_tax_receipts];
        atol=ATOL,
        rtol=RTOL,
    )
    @test isapprox(result.total_net_supply, [0.0, 0.0]; atol=ATOL, rtol=RTOL)
    @test isapprox(
        result.auxiliary_equation_values[:government_budget],
        0.0;
        atol=ATOL,
        rtol=RTOL,
    )
    @test result.max_natural_residual <= 1.0e-8
end

end # module TestEndogenousOutputTaxAuxiliaryV1
