using Test
using GEM
using GEMB

const ATOL = 1.0e-8
const RTOL = 1.0e-8


@testset "GEMB -> GEM baseline equilibrium" begin

    # ------------------------------------------------------------
    # 1. Firm constructed by GEMB
    #
    # 1 unit labor -> 1 unit product
    # ------------------------------------------------------------

    firm = GEMB.build_agent(
        GEMB.CESSpec(
            [1.0];
            es = 1.0,
            alpha = 1.0,
        );
        output_indices = [1],
        output_coefficients = [1.0],
        demand_indices = [2],
        activity_start = 95.0,
        name = :firm,
    )

    @test firm isa GEM.NetSupplyAgent


    # ------------------------------------------------------------
    # 2. Household constructed by GEMB
    #
    # The household owns 100 units of labor and spends all income
    # on the product.
    # ------------------------------------------------------------

    household = GEMB.build_agent(
        GEMB.MarshallDemandConsumerSpec(
            (income, prices) -> [
                income / prices[1],
            ],
        );
        demand_indices = [1],
        endowment_indices = [2],
        endowment_quantities = [100.0],
        name = :household,
    )

    @test household isa GEM.NetSupplyAgent


    # ------------------------------------------------------------
    # 3. GEM equilibrium model
    # ------------------------------------------------------------

    model = GEM.NetSupplyEquilibriumModel(
        [firm, household],
        [:product, :labor];
        numeraire_index = 2,
        numeraire_value = 1.0,
    )


    # ------------------------------------------------------------
    # 4. Solve entirely with GEM
    # ------------------------------------------------------------

    result = GEM.solve_equilibrium_model_mcp_jump(
        model;
        p0 = [1.0, 1.0],
        residual_tol = 1.0e-8,
        silent = true,
    )


    # ------------------------------------------------------------
    # 5. Analytic equilibrium
    # ------------------------------------------------------------

    @test result.solved

    @test isapprox(
        result.prices,
        [1.0, 1.0];
        atol = ATOL,
        rtol = RTOL,
    )

    @test isapprox(
        result.agent_variable_values[1][1],
        100.0;
        atol = ATOL,
        rtol = RTOL,
    )

    @test maximum(abs, result.total_net_supply) <= ATOL

    @test result.max_natural_residual <= ATOL

    @test result isa GEM.EquilibriumResult

    @test result.solved
    @test result.prices ≈ [1.0, 1.0]
    @test result.agent_variable_values[1][1] ≈ 100.0
    @test result.max_natural_residual <= 1.0e-8

    @test :prices in propertynames(result)
    @test :solved in keys(result)

    raw = GEM.raw_result(result)

    @test raw isa NamedTuple
    @test raw.prices == result.prices
    @test raw.solved == result.solved
end




println("GEMB -> GEM baseline integration test passed.")