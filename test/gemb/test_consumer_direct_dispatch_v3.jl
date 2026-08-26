using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB

@testset "GEMB consumer direct-dispatch V7" begin

    atol = 1.0e-10
    rtol = 1.0e-10

    # ------------------------------------------------------------
    # 1. Explicit marginal-utility consumer spec
    # ------------------------------------------------------------

    mu = demand -> [1.0 / demand[1]]

    mu_spec = GEMB.MarginalUtilityConsumerSpec(mu)

    @test mu_spec isa GEMB.AbstractConsumerSpec
    @test mu_spec.marginal_function === mu

    mu_agent = GEMB.build_agent(
        mu_spec;
        demand_indices = [1],
        endowment_indices = [2],
        endowment_quantities = [100.0],
        demand_start = [50.0],
        name = :mu_consumer,
    )

    @test mu_agent isa GEM.NetSupplyAgent
    @test mu_agent.name == :mu_consumer


    # ------------------------------------------------------------
    # 2. Explicit Marshall-demand consumer spec
    # ------------------------------------------------------------

    demand = (income, prices) -> [income / prices[1]]

    demand_spec = GEMB.MarshallDemandConsumerSpec(demand)

    @test demand_spec isa GEMB.AbstractConsumerSpec
    @test demand_spec.demand_function === demand

    demand_agent = GEMB.build_agent(
        demand_spec;
        demand_indices = [1],
        endowment_indices = [2],
        endowment_quantities = [100.0],
        name = :demand_consumer,
    )

    @test demand_agent isa GEM.NetSupplyAgent
    @test demand_agent.name == :demand_consumer


    # ------------------------------------------------------------
    # 3. Equivalent explicit specifications preserve the same agent layout
    # ------------------------------------------------------------

    mu_agent_repeat = GEMB.build_agent(
        GEMB.MarginalUtilityConsumerSpec(mu);
        demand_indices = [1],
        endowment_indices = [2],
        endowment_quantities = [100.0],
        demand_start = [50.0],
        name = :mu_consumer_old,
    )

    @test mu_agent.commodity_indices == mu_agent_repeat.commodity_indices
    @test mu_agent.variable_names == mu_agent_repeat.variable_names
    @test mu_agent.variable_lower_bounds == mu_agent_repeat.variable_lower_bounds
    @test mu_agent.variable_upper_bounds == mu_agent_repeat.variable_upper_bounds
    @test mu_agent.variable_start == mu_agent_repeat.variable_start

    demand_agent_repeat = GEMB.build_agent(
        GEMB.MarshallDemandConsumerSpec(demand);
        demand_indices = [1],
        endowment_indices = [2],
        endowment_quantities = [100.0],
        name = :demand_consumer_old,
    )

    @test demand_agent.commodity_indices == demand_agent_repeat.commodity_indices
    @test demand_agent.variable_names == demand_agent_repeat.variable_names


    # ------------------------------------------------------------
    # 4. End-to-end equilibrium with the new consumer spec syntax
    # ------------------------------------------------------------

    firm = GEMB.build_agent(
        GEMB.CESSpec([1.0]; es = 1.0, alpha = 1.0);
        output_indices = [1],
        demand_indices = [2],
        activity_start = 95.0,
        name = :firm,
    )

    household = GEMB.build_agent(
        GEMB.MarshallDemandConsumerSpec(
            (income, prices) -> [income / prices[1]],
        );
        demand_indices = [1],
        endowment_indices = [2],
        endowment_quantities = [100.0],
        name = :household,
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
    @test isapprox(result.prices, [1.0, 1.0]; atol = atol, rtol = rtol)
    @test isapprox(
        result.agent_variable_values[1][1],
        100.0;
        atol = atol,
        rtol = rtol,
    )
    @test maximum(abs, result.total_net_supply) <= 1.0e-8

    # ------------------------------------------------------------
    # 5. Consumer specs reject producer-style output mappings
    # ------------------------------------------------------------

    @test_throws ArgumentError GEMB.build_agent(
        mu_spec;
        output_indices = [1],
        demand_indices = [1],
        endowment_indices = [2],
        endowment_quantities = [100.0],
        demand_start = [50.0],
    )

    @test_throws ArgumentError GEMB.build_agent(
        demand_spec;
        output_indices = [1],
        demand_indices = [1],
        endowment_indices = [2],
        endowment_quantities = [100.0],
    )

end

println("GEMB consumer direct-dispatch V7 test passed.")
