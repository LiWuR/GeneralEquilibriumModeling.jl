# ================================================================
# test_stationary_nonconvex_multiple_equilibria_v1.jl
#
# Regression test for multiple stationary equilibria under a
# nonconvex production technology.
# ================================================================

module TestStationaryNonconvexMultipleEquilibriaV1

using Test
using GeneralEquilibriumModeling.GEM

const C_NONCONVEX = 0.01
const B_SCALE = 0.20
const TARGET_OUTPUT = 4.0
const HOUSEHOLD_FACTOR_ENDOWMENT = 0.5

h_nonconvex(d) = d^2 * (d^2 - 4.0)^2

h_nonconvex_prime(d) =
    2.0 * d * (d^2 - 4.0) * (3.0 * d^2 - 4.0)

function production(x)
    K = x[1]
    L = x[2]
    s = K + L
    d = K - L

    return s +
           C_NONCONVEX * h_nonconvex(d) +
           B_SCALE * (s - 4.0)
end

function marginal_product(x)
    K = x[1]
    L = x[2]
    d = K - L
    hp = h_nonconvex_prime(d)

    return [
        1.0 + B_SCALE + C_NONCONVEX * hp,
        1.0 + B_SCALE - C_NONCONVEX * hp,
    ]
end

firm_net_supply = ProductionNetSupply(
    [1],
    [1.0],
    [2, 3],
)

firm_conditions = ProductionStationarityConditions(
    production,
    marginal_product,
    firm_net_supply.input_positions,
)

stationary_firm = ProducerAgent(
    firm_net_supply.local_indices,
    firm_net_supply;
    variable_names=[
        :activity,
        :input_capital,
        :input_labor,
        :production_multiplier,
    ],
    variable_lower_bounds=[0.5, 0.75, 0.75, -Inf],
    variable_upper_bounds=[6.0, 3.75, 3.75, Inf],
    variable_start=[4.0, 2.0, 2.0, 1.0 / (1.0 + B_SCALE)],
    condition_rule=firm_conditions,
    name=:stationary_firm,
)

capital_conversion = ProducerAgent(
    [1, 2],
    (variables, prices) -> begin
        z = variables[1]
        [-z, z]
    end;
    variable_names=[:activity],
    variable_start=[1.5],
    name=:capital_conversion,
)

labor_conversion = ProducerAgent(
    [1, 3],
    (variables, prices) -> begin
        z = variables[1]
        [-z, z]
    end;
    variable_names=[:activity],
    variable_start=[1.5],
    name=:labor_conversion,
)

household = ConsumerAgent(
    [1, 2, 3],
    function (variables, prices)
        income = HOUSEHOLD_FACTOR_ENDOWMENT * prices[2] +
                 HOUSEHOLD_FACTOR_ENDOWMENT * prices[3]
        product_demand = income / prices[1]
        return [
            -product_demand,
            HOUSEHOLD_FACTOR_ENDOWMENT,
            HOUSEHOLD_FACTOR_ENDOWMENT,
        ]
    end;
    name=:household,
)

model = EquilibriumModel(
    [
        stationary_firm,
        capital_conversion,
        labor_conversion,
        household,
    ],
    [:product, :capital, :labor];
    numeraire_index=3,
    numeraire_value=1.0,
    price_lower_bounds=[0.1, 0.1, 0.1],
    price_upper_bounds=[Inf, Inf, Inf],
)

starts = [
    (
        name=:left,
        K=1.0,
        L=3.0,
        v0=[4.02, 1.03, 2.97, 0.82, 0.53, 2.47],
    ),
    (
        name=:middle,
        K=2.0,
        L=2.0,
        v0=[3.98, 2.03, 1.97, 0.85, 1.53, 1.47],
    ),
    (
        name=:right,
        K=3.0,
        L=1.0,
        v0=[4.02, 2.97, 1.03, 0.82, 2.47, 0.53],
    ),
]

results = Dict{Symbol, Any}()

for branch in starts
    results[branch.name] = solve_equilibrium_model_mcp_jump(
        model;
        v0=branch.v0,
        p0=[1.0, 1.0, 1.0],
        residual_tol=1.0e-8,
        silent=true,
    )
end

@testset "Nonconvex multiple stationary equilibria" begin
    for branch in starts
        result = results[branch.name]

        @test result.solved
        @test result.all_markets_clear
        @test result.prices ≈ [1.0, 1.0, 1.0] atol=1.0e-8 rtol=1.0e-8

        values = result.agent_variable_values[1]

        @test values[1] ≈ TARGET_OUTPUT atol=1.0e-8 rtol=1.0e-8
        @test values[2] ≈ branch.K atol=1.0e-7 rtol=1.0e-7
        @test values[3] ≈ branch.L atol=1.0e-7 rtol=1.0e-7
        @test values[4] ≈ 1.0 / (1.0 + B_SCALE) atol=1.0e-7 rtol=1.0e-7

        @test maximum(abs, result.agent_conditions[1]) <= 1.0e-8
        @test maximum(abs, result.total_net_supply) <= 1.0e-8
        @test result.max_natural_residual <= 1.0e-8
    end

    left = results[:left].agent_variable_values[1]
    middle = results[:middle].agent_variable_values[1]
    right = results[:right].agent_variable_values[1]

    @test abs(left[2] - middle[2]) > 0.5
    @test abs(middle[2] - right[2]) > 0.5
    @test abs(left[3] - right[3]) > 1.0
end

end # module TestStationaryNonconvexMultipleEquilibriaV1
