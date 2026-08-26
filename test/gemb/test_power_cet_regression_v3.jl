# ================================================================
# test_power_cet_regression_v3.jl
#
# Self-contained regression entry for the GEMB Power/CET extension.
#
# V2 fully absorbs the previously separate tests:
#
#   test_power_cet_specs_v1.jl
#   test_CES_CET_equilibrium_v1.jl
#
# and therefore contains no include() dependency on either file.
#
# Coverage:
#   1. PowerProductionSpec formulas and validation.
#   2. Power default TotalProfitConditions and explicit override.
#   3. CETSpec formulas, et interface, and fixed-share et=0 limit.
#   4. CET output_spec routing and backward-compatible fixed outputs.
#   5. Power input technology combined with CET outputs.
#   6. Repeated positional dispatch for Power/CET.
#   7. CES-input + CET-output end-to-end general equilibrium.
#   8. Endogenous CET output reallocation after a demand-composition shock.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


# ----------------------------------------------------------------
# 1. Explicit condition-rule integration
# ----------------------------------------------------------------

@testset "GEMB Power/CET condition-rule integration" begin
    power = PowerProductionSpec(
        alpha=1.0,
        theta=0.5,
    )

    power_default = build_agent(
        power;
        output_indices=[1],
        output_coefficients=[1.0],
        demand_indices=[2],
        activity_start=2.0,
        name=:power_default,
    )

    @test agent_condition_rule(
        power_default,
    ) isa TotalProfitConditions

    power_override = build_agent(
        power;
        output_indices=[1],
        output_coefficients=[1.0],
        demand_indices=[2],
        activity_start=2.0,
        condition_rule=UnitProfitConditions(),
        name=:power_override,
    )

    @test agent_condition_rule(
        power_override,
    ) isa UnitProfitConditions

    cet = CETSpec(
        [0.5, 0.5];
        et=1.0,
        alpha=1.0,
    )

    ces_cet = build_agent(
        CESSpec(
            [1.0];
            es=0.0,
            alpha=1.0,
        );
        output_indices=[1, 2],
        output_spec=cet,
        demand_indices=[3],
        activity_start=4.0,
        name=:ces_cet,
    )

    @test agent_condition_rule(
        ces_cet,
    ) isa UnitProfitConditions

    power_cet = build_agent(
        power;
        output_indices=[1, 2],
        output_spec=cet,
        demand_indices=[3],
        activity_start=2.0,
        name=:power_cet,
    )

    @test agent_condition_rule(
        power_cet,
    ) isa TotalProfitConditions

    power_repeat = build_agent(
        power;
        output_indices=[1],
        output_coefficients=[1.0],
        demand_indices=[2],
        activity_start=2.0,
        name=:power_repeat,
    )

    @test agent_condition_rule(
        power_repeat,
    ) isa TotalProfitConditions

    ces_cet_repeat = build_agent(
        CESSpec(
            [1.0];
            es=0.0,
            alpha=1.0,
        );
        output_indices=[1, 2],
        output_spec=cet,
        demand_indices=[3],
        activity_start=4.0,
        name=:ces_cet_repeat,
    )

    @test agent_condition_rule(
        ces_cet_repeat,
    ) isa UnitProfitConditions
end


# ----------------------------------------------------------------
# 2. Focused PowerProductionSpec and CETSpec regression
# ----------------------------------------------------------------

@testset "GEMB PowerProductionSpec and CETSpec" begin

    # ------------------------------------------------------------
    # 2A. PowerProductionSpec
    # ------------------------------------------------------------

    power = PowerProductionSpec(
        alpha=1.0,
        theta=0.5,
    )

    @test power.alpha == 1.0
    @test power.theta == 0.5

    @test activity_demand(
        power,
        2.0,
        [1.0],
    ) ≈ [4.0]

    @test_throws ArgumentError PowerProductionSpec(
        alpha=0.0,
        theta=0.5,
    )

    @test_throws ArgumentError PowerProductionSpec(
        alpha=1.0,
        theta=0.0,
    )

    @test_throws DimensionMismatch activity_demand(
        power,
        2.0,
        [1.0, 1.0],
    )

    power_firm = build_agent(
        power;
        output_indices=[1],
        output_coefficients=[1.0],
        demand_indices=[2],
        activity_start=2.0,
        name=:power_firm,
    )

    @test power_firm isa GEM.NetSupplyAgent

    @test agent_condition_rule(
        power_firm,
    ) isa TotalProfitConditions

    # At z = 2, f(x) = sqrt(x) implies x = 4.
    # With p_output = 2 and p_input = 1, total revenue and total
    # cost both equal 4.
    power_supply = agent_net_supply(
        power_firm,
        [2.0],
        [2.0, 1.0],
    )

    @test power_supply ≈ [
        2.0,
        -4.0,
    ]

    @test -sum(
        [2.0, 1.0] .* power_supply,
    ) ≈ 0.0

    power_unit_override = build_agent(
        power;
        output_indices=[1],
        output_coefficients=[1.0],
        demand_indices=[2],
        activity_start=2.0,
        condition_rule=UnitProfitConditions(),
        name=:power_unit_override,
    )

    @test agent_condition_rule(
        power_unit_override,
    ) isa UnitProfitConditions

    @test_throws ArgumentError build_agent(
        power;
        demand_indices=[1],
        endowment_indices=[1],
        endowment_quantities=[1.0],
        activity_start=1.0,
    )

    @test_throws DimensionMismatch build_agent(
        power;
        output_indices=[1],
        demand_indices=[2, 3],
        activity_start=1.0,
    )


    # ------------------------------------------------------------
    # 2B. CETSpec
    # ------------------------------------------------------------

    cet_fixed = CETSpec(
        [0.25, 0.75];
        et=0.0,
        alpha=1.0,
    )

    @test cet_fixed.et == 0.0
    @test !hasproperty(
        cet_fixed,
        :es,
    )

    @test activity_supply(
        cet_fixed,
        4.0,
        [10.0, 1.0],
    ) ≈ [
        1.0,
        3.0,
    ]

    cet = CETSpec(
        [0.25, 0.75];
        et=1.0,
        alpha=1.0,
    )

    output_prices = [
        2.0,
        1.0,
    ]

    outputs = activity_supply(
        cet,
        4.0,
        output_prices,
    )

    # CET supply ratio:
    # y1/y2 = (beta1/beta2) * (p1/p2)^et = 2/3.
    @test outputs[1] / outputs[2] ≈ 2.0 / 3.0

    revenue_power_sum =
        0.25 * output_prices[1]^2 +
        0.75 * output_prices[2]^2

    unit_revenue =
        sqrt(
            revenue_power_sum,
        )

    @test sum(
        output_prices .* outputs,
    ) ≈ 4.0 * unit_revenue

    @test_throws ArgumentError CETSpec(
        [0.5, 0.5];
        et=-0.1,
    )

    @test_throws ArgumentError CETSpec(
        [0.0, 0.0];
        et=1.0,
    )

    @test_throws DimensionMismatch activity_supply(
        cet,
        1.0,
        [1.0],
    )

    @test_throws ArgumentError activity_supply(
        cet,
        1.0,
        [-1.0, 1.0],
    )


    # ------------------------------------------------------------
    # 2C. CES input demand + CET output supply
    # ------------------------------------------------------------

    input_spec = CESSpec(
        [1.0];
        es=0.0,
        alpha=1.0,
    )

    cet_firm = build_agent(
        input_spec;
        output_indices=[1, 2],
        output_spec=cet,
        demand_indices=[3],
        activity_start=4.0,
        name=:cet_firm,
    )

    @test cet_firm isa GEM.NetSupplyAgent

    @test agent_condition_rule(
        cet_firm,
    ) isa UnitProfitConditions

    cet_prices = [
        2.0,
        1.0,
        1.0,
    ]

    cet_supply = agent_net_supply(
        cet_firm,
        [4.0],
        cet_prices,
    )

    expected_outputs = activity_supply(
        cet,
        4.0,
        cet_prices[1:2],
    )

    @test cet_supply[1:2] ≈ expected_outputs
    @test cet_supply[3] ≈ -4.0

    cet_firm_repeat = build_agent(
        input_spec;
        output_indices=[1, 2],
        output_spec=cet,
        demand_indices=[3],
        activity_start=4.0,
        name=:cet_firm_repeat,
    )

    @test agent_net_supply(
        cet_firm_repeat,
        [4.0],
        cet_prices,
    ) ≈ cet_supply

    @test_throws ArgumentError build_agent(
        input_spec;
        output_indices=[1, 2],
        output_coefficients=[0.5, 0.5],
        output_spec=cet,
        demand_indices=[3],
        activity_start=4.0,
    )


    # ------------------------------------------------------------
    # 2D. Power input technology + CET outputs
    # ------------------------------------------------------------

    power_cet = CETSpec(
        [0.5, 0.5];
        et=0.0,
        alpha=1.0,
    )

    power_cet_firm = build_agent(
        power;
        output_indices=[1, 2],
        output_spec=power_cet,
        demand_indices=[3],
        activity_start=2.0,
        name=:power_cet_firm,
    )

    @test agent_condition_rule(
        power_cet_firm,
    ) isa TotalProfitConditions

    power_cet_prices = [
        2.0,
        2.0,
        1.0,
    ]

    power_cet_supply = agent_net_supply(
        power_cet_firm,
        [2.0],
        power_cet_prices,
    )

    @test power_cet_supply ≈ [
        1.0,
        1.0,
        -4.0,
    ]

    @test -sum(
        power_cet_prices .* power_cet_supply,
    ) ≈ 0.0


    # ------------------------------------------------------------
    # 2E. Existing fixed-output API remains unchanged
    # ------------------------------------------------------------

    fixed_output_firm = build_agent(
        input_spec;
        output_indices=[1, 2],
        output_coefficients=[0.25, 0.75],
        demand_indices=[3],
        activity_start=4.0,
        name=:fixed_output_firm,
    )

    fixed_supply = agent_net_supply(
        fixed_output_firm,
        [4.0],
        [1.0, 1.0, 1.0],
    )

    @test fixed_supply ≈ [
        1.0,
        3.0,
        -4.0,
    ]

    @test agent_condition_rule(
        fixed_output_firm,
    ) isa UnitProfitConditions
end


# ----------------------------------------------------------------
# 3. End-to-end CES-input / CET-output equilibrium
# ----------------------------------------------------------------

function make_ces_cet_regression_model(
    good_1_share::Real,
)
    input_spec = CESSpec(
        [0.5, 0.5];
        es=1.0,
        alpha=2.0,
    )

    output_spec = CETSpec(
        [0.5, 0.5];
        et=1.0,
        alpha=1.0,
    )

    firm = build_agent(
        input_spec;
        output_indices=[1, 2],
        output_spec=output_spec,
        demand_indices=[3, 4],
        activity_start=100.0,
        name=:firm,
    )

    household = build_agent(
        MarshallDemandConsumerSpec(
            (
                income,
                prices,
            ) -> [
                good_1_share *
                income /
                prices[1],

                (1.0 - good_1_share) *
                income /
                prices[2],
            ],
        );
        demand_indices=[1, 2],
        endowment_indices=[3, 4],
        endowment_quantities=[
            50.0,
            50.0,
        ],
        name=:household,
    )

    model = NetSupplyEquilibriumModel(
        [
            firm,
            household,
        ],
        [
            :good_1,
            :good_2,
            :labor,
            :capital,
        ];
        numeraire_index=3,
        numeraire_value=1.0,
        price_lower_bounds=fill(
            1.0e-8,
            4,
        ),
        price_upper_bounds=fill(
            Inf,
            4,
        ),
    )

    return (
        model,
        firm,
        output_spec,
    )
end


@testset "GEMB CES input + CET output equilibrium" begin
    atol = 1.0e-7
    rtol = 1.0e-7

    # ------------------------------------------------------------
    # 3A. Symmetric benchmark
    # ------------------------------------------------------------

    symmetric_model,
    symmetric_firm,
    symmetric_cet =
        make_ces_cet_regression_model(
            0.5,
        )

    @test agent_condition_rule(
        symmetric_firm,
    ) isa UnitProfitConditions

    @test symmetric_cet.et == 1.0

    symmetric_result =
        solve_equilibrium_model_mcp_jump(
            symmetric_model;
            p0=[
                1.0,
                1.0,
                1.0,
                1.0,
            ],
            residual_tol=1.0e-8,
            silent=true,
        )

    @test symmetric_result.solved
    @test symmetric_result.mcp_solved
    @test symmetric_result.all_markets_clear

    @test isapprox(
        symmetric_result.prices,
        [
            1.0,
            1.0,
            1.0,
            1.0,
        ];
        atol=atol,
        rtol=rtol,
    )

    symmetric_activity =
        symmetric_result.agent_variable_values[1][1]

    symmetric_firm_supply =
        symmetric_result.agent_net_supplies[1]

    @test isapprox(
        symmetric_activity,
        100.0;
        atol=atol,
        rtol=rtol,
    )

    @test isapprox(
        symmetric_firm_supply,
        [
            50.0,
            50.0,
            -50.0,
            -50.0,
        ];
        atol=atol,
        rtol=rtol,
    )

    @test maximum(
        abs,
        symmetric_result.total_net_supply,
    ) <= atol

    @test symmetric_result.max_natural_residual <= 1.0e-8

    symmetric_profit = sum(
        symmetric_result.prices .*
        symmetric_firm_supply,
    )

    @test isapprox(
        symmetric_profit,
        0.0;
        atol=atol,
        rtol=rtol,
    )


    # ------------------------------------------------------------
    # 3B. Good-1-biased benchmark
    # ------------------------------------------------------------

    biased_model,
    biased_firm,
    biased_cet =
        make_ces_cet_regression_model(
            0.8,
        )

    biased_result =
        solve_equilibrium_model_mcp_jump(
            biased_model;
            p0=[
                1.25,
                0.65,
                1.0,
                1.0,
            ],
            residual_tol=1.0e-8,
            silent=true,
        )

    expected_p2 =
        sqrt(
            2.0 / 5.0,
        )

    expected_p1 =
        2.0 * expected_p2

    expected_prices = [
        expected_p1,
        expected_p2,
        1.0,
        1.0,
    ]

    @test biased_result.solved
    @test biased_result.mcp_solved
    @test biased_result.all_markets_clear

    @test isapprox(
        biased_result.prices,
        expected_prices;
        atol=atol,
        rtol=rtol,
    )

    biased_activity =
        biased_result.agent_variable_values[1][1]

    biased_firm_supply =
        biased_result.agent_net_supplies[1]

    @test isapprox(
        biased_activity,
        100.0;
        atol=atol,
        rtol=rtol,
    )

    expected_outputs = activity_supply(
        biased_cet,
        100.0,
        expected_prices[1:2],
    )

    @test isapprox(
        biased_firm_supply[1:2],
        expected_outputs;
        atol=atol,
        rtol=rtol,
    )

    @test isapprox(
        biased_firm_supply[3:4],
        [
            -50.0,
            -50.0,
        ];
        atol=atol,
        rtol=rtol,
    )


    # ------------------------------------------------------------
    # 3C. CET price-response checks
    # ------------------------------------------------------------

    symmetric_price_ratio =
        symmetric_result.prices[1] /
        symmetric_result.prices[2]

    biased_price_ratio =
        biased_result.prices[1] /
        biased_result.prices[2]

    symmetric_output_ratio =
        symmetric_firm_supply[1] /
        symmetric_firm_supply[2]

    biased_output_ratio =
        biased_firm_supply[1] /
        biased_firm_supply[2]

    @test isapprox(
        symmetric_price_ratio,
        1.0;
        atol=atol,
        rtol=rtol,
    )

    @test isapprox(
        symmetric_output_ratio,
        1.0;
        atol=atol,
        rtol=rtol,
    )

    @test isapprox(
        biased_price_ratio,
        2.0;
        atol=atol,
        rtol=rtol,
    )

    @test isapprox(
        biased_output_ratio,
        2.0;
        atol=atol,
        rtol=rtol,
    )

    @test isapprox(
        biased_output_ratio,
        biased_price_ratio^biased_cet.et;
        atol=atol,
        rtol=rtol,
    )

    @test biased_price_ratio >
        symmetric_price_ratio

    @test biased_output_ratio >
        symmetric_output_ratio

    @test maximum(
        abs,
        biased_result.total_net_supply,
    ) <= atol

    @test biased_result.max_natural_residual <= 1.0e-8

    biased_profit = sum(
        biased_result.prices .*
        biased_firm_supply,
    )

    @test isapprox(
        biased_profit,
        0.0;
        atol=atol,
        rtol=rtol,
    )
end


println(
    "GEMB Power/CET self-contained regression passed."
)
