# ================================================================
# test_stationary_nonhomogeneous_v1.jl
#
# Regression test for stationary production with a nonhomogeneous
# production function, using only the current GEM public API.
# ================================================================

module TestStationaryNonhomogeneousV1

using Test
using GeneralEquilibriumModeling.GEM

@testset "Stationary nonhomogeneous production" begin
    production(x) = sqrt(x[1]) + 0.1 * x[1]

    marginal_product(x) = [
        0.5 / sqrt(x[1]) + 0.1,
    ]

    firm_net_supply = ProductionNetSupply(
        [1],
        [1.0],
        [2],
    )

    firm_conditions = ProductionStationarityConditions(
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
        variable_lower_bounds=[0.0, 1.0e-8, -Inf],
        variable_upper_bounds=[Inf, Inf, Inf],
        variable_start=[18.0, 90.0, 6.0],
        condition_rule=firm_conditions,
        name=:firm,
    )

    household = ConsumerAgent(
        [1, 2],
        function (variables, prices)
            income = 100.0 * prices[2]
            product_demand = income / prices[1]
            return [-product_demand, 100.0]
        end;
        name=:household,
    )

    model = EquilibriumModel(
        [firm, household],
        [:product, :labor];
        numeraire_index=2,
        numeraire_value=1.0,
    )

    result = solve_equilibrium_model_mcp_jump(
        model;
        p0=[4.5, 1.0],
        residual_tol=1.0e-8,
        silent=true,
    )

    @test result.solved
    @test result.all_markets_clear
    @test result.prices ≈ [5.0, 1.0] atol=1.0e-8 rtol=1.0e-8
    @test result.agent_variable_values[1] ≈ [
        20.0,
        100.0,
        20.0 / 3.0,
    ] atol=1.0e-8 rtol=1.0e-8
    @test maximum(abs, result.agent_conditions[1]) <= 1.0e-8
    @test maximum(abs, result.total_net_supply) <= 1.0e-8
    @test result.max_natural_residual <= 1.0e-8
end

end # module TestStationaryNonhomogeneousV1
