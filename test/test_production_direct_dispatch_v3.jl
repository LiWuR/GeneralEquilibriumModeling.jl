using Test
using GEM
using GEMB

const ATOL = 1.0e-8
const RTOL = 1.0e-8

@testset "GEMB production direct dispatch" begin

    production_function = x -> x[1]
    marginal_product_function = x -> [1.0]

    # ------------------------------------------------------------
    # 1. Stationary ProductionFunctionSpec is built directly.
    # ------------------------------------------------------------

    stationary_spec = GEMB.ProductionFunctionSpec(
        production_function,
        marginal_product_function;
        behavior = :stationary,
    )

    stationary_agent = GEMB.build_agent(
        stationary_spec;
        output_indices = [1],
        output_coefficients = [1.0],
        demand_indices = [2],
        activity_start = 10.0,
        demand_start = [10.0],
        production_multiplier_start = 1.0,
        name = :stationary_firm,
    )

    @test stationary_agent isa GEM.NetSupplyAgent
    @test stationary_agent.name == :stationary_firm
    @test stationary_agent.variable_names == [
        :activity,
        :input_2,
        :production_multiplier,
    ]

    # ------------------------------------------------------------
    # 2. Cost-min ProductionFunctionSpec is built directly.
    # ------------------------------------------------------------

    cost_min_spec = GEMB.ProductionFunctionSpec(
        production_function,
        marginal_product_function;
        behavior = :cost_min,
    )

    cost_min_agent = GEMB.build_agent(
        cost_min_spec;
        output_indices = [1],
        output_coefficients = [1.0],
        demand_indices = [2],
        activity_start = 10.0,
        demand_start = [10.0],
        demand_lower_bounds = [0.0],
        production_multiplier_start = 1.0,
        name = :cost_min_firm,
    )

    @test cost_min_agent isa GEM.NetSupplyAgent
    @test cost_min_agent.name == :cost_min_firm
    @test cost_min_agent.variable_lower_bounds[end] == 0.0

    # ------------------------------------------------------------
    # 3. An equivalent explicit ProductionFunctionSpec preserves the same layout.
    # ------------------------------------------------------------

    repeat_agent = GEMB.build_agent(
        GEMB.ProductionFunctionSpec(
            production_function,
            marginal_product_function;
            behavior = :stationary,
        );
        output_indices = [1],
        output_coefficients = [1.0],
        demand_indices = [2],
        activity_start = 10.0,
        demand_start = [10.0],
        production_multiplier_start = 1.0,
        name = :repeat_firm,
    )

    @test repeat_agent isa GEM.NetSupplyAgent
    @test repeat_agent.commodity_indices == stationary_agent.commodity_indices
    @test repeat_agent.variable_names == stationary_agent.variable_names
    @test repeat_agent.variable_lower_bounds == stationary_agent.variable_lower_bounds
    @test repeat_agent.variable_upper_bounds == stationary_agent.variable_upper_bounds
    @test repeat_agent.variable_start == stationary_agent.variable_start

    # ------------------------------------------------------------
    # 4. ProductionFunctionSpec does not accept endowments.
    # ------------------------------------------------------------

    @test_throws ArgumentError GEMB.build_agent(
        stationary_spec;
        output_indices = [1],
        demand_indices = [2],
        endowment_indices = [3],
        endowment_quantities = [1.0],
    )

    # ------------------------------------------------------------
    # 5. Full equilibrium through direct production dispatch.
    # ------------------------------------------------------------

    household = GEMB.build_agent(
        GEMB.MarshallDemandConsumerSpec(
            (income, prices) -> [income / prices[1]],
        );
        demand_indices = [1],
        endowment_indices = [2],
        endowment_quantities = [100.0],
        name = :household,
    )

    firm = GEMB.build_agent(
        stationary_spec;
        output_indices = [1],
        output_coefficients = [1.0],
        demand_indices = [2],
        activity_start = 95.0,
        demand_start = [95.0],
        production_multiplier_start = 1.0,
        name = :firm,
    )

    model = GEM.NetSupplyEquilibriumModel(
        [firm, household],
        [:product, :labor];
        numeraire_index = 2,
        numeraire_value = 1.0,
    )

    result = GEM.solve_equilibrium_model_mcp_jump(
        model;
        p0 = [1.0, 1.0],
        residual_tol = 1.0e-8,
        silent = true,
    )

    @test result isa GEM.EquilibriumResult
    @test result.solved
    @test isapprox(result.prices, [1.0, 1.0]; atol=ATOL, rtol=RTOL)
    @test isapprox(
        result.agent_variable_values[1][1],
        100.0;
        atol=ATOL,
        rtol=RTOL,
    )
    @test result.max_natural_residual <= ATOL
end

println("GEMB production direct-dispatch test passed.")
