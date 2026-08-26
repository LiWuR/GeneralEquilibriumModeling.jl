# ================================================================
# test_auxiliary_feedback_v1.jl
#
# Regression tests for auxiliary-variable feedback through the current
# GEM public API.
# ================================================================

module TestAuxiliaryFeedbackV1

using Test
using GeneralEquilibriumModeling.GEM

const ATOL = 1.0e-7
const RTOL = 1.0e-7

@testset "Firm observes auxiliary variable" begin
    productivity = AuxiliaryVariable(
        :productivity;
        start=1.8,
        lower_bound=0.0,
        upper_bound=Inf,
    )

    production = function (inputs, observed_values)
        A = observed_values[1]
        return A * inputs[1]
    end

    marginal_product = function (inputs, observed_values)
        A = observed_values[1]
        return [A]
    end

    firm_net_supply = ProductionNetSupply(
        [1],
        [1.0],
        [2],
    )

    firm_conditions = CostMinimizationKKTConditions(
        production,
        marginal_product,
        firm_net_supply.input_positions,
    )

    firm = ProducerAgent(
        firm_net_supply.local_indices,
        firm_net_supply;
        variable_names=[
            :activity,
            :input_labor,
            :production_multiplier,
        ],
        variable_lower_bounds=[0.0, 0.0, 0.0],
        variable_upper_bounds=[Inf, Inf, Inf],
        variable_start=[180.0, 90.0, 0.5],
        observed_variables=[
            AuxiliaryVariableRef(:productivity),
        ],
        condition_rule=firm_conditions,
        name=:firm,
    )

    household = ConsumerAgent(
        [1, 2],
        function (variables, prices)
            income = 100.0 * prices[2]
            return [-income / prices[1], 100.0]
        end;
        name=:household,
    )

    productivity_equation = AuxiliaryEquation(
        :productivity_feedback,
        :productivity,
        values -> values[2] - 1.0 - 0.005 * values[1];
        observed_variables=[
            AgentVariableRef(:firm, :activity),
            AuxiliaryVariableRef(:productivity),
        ],
    )

    model = EquilibriumModel(
        [firm, household],
        [:product, :labor];
        auxiliary_variables=[productivity],
        auxiliary_equations=[productivity_equation],
        numeraire_index=2,
        numeraire_value=1.0,
    )

    result = solve_equilibrium_model_mcp_jump(
        model;
        residual_tol=1.0e-8,
        silent=true,
    )

    @test result.solved
    @test result.all_markets_clear
    @test isapprox(result.prices, [0.5, 1.0]; atol=ATOL, rtol=RTOL)
    @test isapprox(
        result.agent_variable_values[1],
        [200.0, 100.0, 0.5];
        atol=ATOL,
        rtol=RTOL,
    )
    @test isapprox(
        result.auxiliary_values[:productivity],
        2.0;
        atol=ATOL,
        rtol=RTOL,
    )
    @test isapprox(
        result.auxiliary_equation_values[:productivity_feedback],
        0.0;
        atol=ATOL,
        rtol=RTOL,
    )
    @test isapprox(
        result.observed_variable_values[1],
        [2.0];
        atol=ATOL,
        rtol=RTOL,
    )
    @test result.max_natural_residual <= 1.0e-8
    @test maximum(abs, result.total_net_supply) <= 1.0e-8
end

@testset "Consumer observes auxiliary variable and price" begin
    share = AuxiliaryVariable(
        :share;
        start=0.45,
        lower_bound=0.01,
        upper_bound=0.99,
    )

    consumer_a = ConsumerAgent(
        [1, 2],
        function (variables, prices, observed_values)
            s = observed_values[1]
            observed_px = observed_values[2]
            income = prices[2]

            return [
                -s * income / observed_px,
                1.0 - (1.0 - s) * income / prices[2],
            ]
        end;
        observed_variables=[
            AuxiliaryVariableRef(:share),
            PriceVariableRef(:x),
        ],
        name=:consumer_a,
    )

    consumer_b = ConsumerAgent(
        [1, 2],
        function (variables, prices)
            income = prices[1]
            return [1.0, -income / prices[2]]
        end;
        name=:consumer_b,
    )

    share_equation = AuxiliaryEquation(
        :share_feedback,
        :share,
        values -> values[2] - 0.4 - 0.2 * values[1];
        observed_variables=[
            PriceVariableRef(:x),
            AuxiliaryVariableRef(:share),
        ],
    )

    model = EquilibriumModel(
        [consumer_a, consumer_b],
        [:x, :y];
        auxiliary_variables=[share],
        auxiliary_equations=[share_equation],
        numeraire_index=2,
        numeraire_value=1.0,
    )

    result = solve_equilibrium_model_mcp_jump(
        model;
        p0=[0.45, 1.0],
        residual_tol=1.0e-8,
        silent=true,
    )

    @test result.solved
    @test result.all_markets_clear
    @test isapprox(result.prices, [0.5, 1.0]; atol=ATOL, rtol=RTOL)
    @test isapprox(result.auxiliary_values[:share], 0.5; atol=ATOL, rtol=RTOL)
    @test isapprox(
        result.observed_variable_values[1],
        [0.5, 0.5];
        atol=ATOL,
        rtol=RTOL,
    )
    @test isapprox(result.total_net_supply, [0.0, 0.0]; atol=ATOL, rtol=RTOL)
    @test isapprox(
        result.auxiliary_equation_values[:share_feedback],
        0.0;
        atol=ATOL,
        rtol=RTOL,
    )
    @test result.max_natural_residual <= 1.0e-8
end

@testset "Missing auxiliary reference validation" begin
    observer = ConsumerAgent(
        [1, 2],
        (variables, prices, observed_values) -> [-1.0, 1.0];
        observed_variables=[AuxiliaryVariableRef(:missing_aux)],
        name=:observer,
    )

    supplier = ConsumerAgent(
        [1, 2],
        (variables, prices) -> [1.0, -1.0];
        name=:supplier,
    )

    @test_throws ArgumentError EquilibriumModel(
        [observer, supplier],
        [:x, :y];
        numeraire_index=2,
    )
end

end # module TestAuxiliaryFeedbackV1
