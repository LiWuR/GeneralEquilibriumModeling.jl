# ================================================================
# gemb_intertemporalEquilibrium_endogenousInterestRate_nct2_nat3_v1.jl
#
# GEMB example: four-period pure-exchange monetary equilibrium with
# endogenous primitive interest rates.
#
# Commodity types:
#   1. labor
#   2. money
#
# Agent types:
#   1. interestRateDeterminer  (virtual condition agent)
#   2. laborer
#   3. moneyOwner
#
# The virtual agent endogenizes r1, r2, and r3 through the
# interest--interest-payment relations. The terminal condition
# r4 = +Inf is represented exactly by the finite limiting full price
#
#   terminal_full_price = lim_{r4 -> Inf} p_labor_4 * (1 + r4).
#
# The file solves the model immediately when included and verifies
# the numerical solution against the analytical benchmark.
# ================================================================

using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


# ----------------------------------------------------------------
# 1. Parameters
# ----------------------------------------------------------------

beta = [0.4, 0.3, 0.2, 0.1]
labor_endowment = fill(100.0, 4)
money_endowment = ones(4)


# ----------------------------------------------------------------
# 2. Dated commodities
#
# The first three labor commodities form one structured group.
# labor_4 is declared separately because its equilibrium price is zero
# when r4 = +Inf. Money is one four-period structured group.
# ----------------------------------------------------------------

labor = CommoditySpec(
    :labor;
    axes=(period=1:3,),
    price_lower_bound=1.0e-10,
)

money = CommoditySpec(
    :money;
    axes=(period=1:4,),
    price_lower_bound=1.0e-10,
)

model = GEMBModel(
    [
        labor,
        :labor_4,
        money,
    ];
    numeraire=CommodityRef(
        :labor;
        period=1,
    ),
    numeraire_value=1.0,
)


# ----------------------------------------------------------------
# 3. Virtual interest-rate determiner
#
# Variables:
#
#   r1, r2, r3, terminal_full_price
#
# Conditions:
#
#   r1 * (p6 + p7 + p8) = p5
#   r2 * (p7 + p8)      = p6
#   r3 * p8             = p7
#   terminal_full_price * omega4 = p8
#
# The variables are free, so the four paired conditions are imposed
# as equalities. The virtual agent has no economic commodity supply.
# ----------------------------------------------------------------

interest_rate_spec = ConditionAgentSpec(
    (variables, prices) -> begin
        r1, r2, r3, terminal_full_price = variables
        p5, p6, p7, p8 = prices

        return [
            r1 * (p6 + p7 + p8) - p5,
            r2 * (p7 + p8) - p6,
            r3 * p8 - p7,
            terminal_full_price * labor_endowment[4] - p8,
        ]
    end,
)

interestRateDeterminer = add_agent!(
    model,
    interest_rate_spec;
    variable_names=[
        :r1,
        :r2,
        :r3,
        :terminal_full_price,
    ],
    variable_start=[
        1.0 / 3.0,
        1.0 / 2.0,
        1.0,
        1.0 / 3.0,
    ],
    variable_lower_bounds=(-Inf),
    variable_upper_bounds=Inf,
    observed_variables=[
        PriceVariableRef(Symbol(:money_, i))
        for i in 1:4
    ],
    name=:interestRateDeterminer,
)


# ----------------------------------------------------------------
# 4. Common Marshall-demand specification
#
# For periods 1--3:
#
#   x_i = beta_i * income / (p_labor_i * (1 + r_i))
#   m_i = r_i * beta_i * income / ((1 + r_i) * p_money_i)
#
# For period 4, r4 = +Inf is represented by its exact limit:
#
#   x_4 = beta_4 * income / terminal_full_price
#   m_4 = beta_4 * income / p_money_4
# ----------------------------------------------------------------

consumer_spec = MarshallDemandConsumerSpec(
    function (income, prices, observed_values)
        rates = observed_values[1:3]
        terminal_full_price = observed_values[4]

        labor_demand =
            beta[1:3] .* income ./
            (prices[1:3] .* (1 .+ rates))

        money_demand =
            rates .* beta[1:3] .* income ./
            ((1 .+ rates) .* prices[5:7])

        return vcat(
            labor_demand,
            beta[4] * income / terminal_full_price,
            money_demand,
            beta[4] * income / prices[8],
        )
    end,
)

observed_interest_variables = [
    agent_variable_ref(:interestRateDeterminer, :r1),
    agent_variable_ref(:interestRateDeterminer, :r2),
    agent_variable_ref(:interestRateDeterminer, :r3),
    agent_variable_ref(
        :interestRateDeterminer,
        :terminal_full_price,
    ),
]

all_commodities = [
    CommodityRef(:labor),
    :labor_4,
    CommodityRef(:money),
]


# ----------------------------------------------------------------
# 5. Laborer
# ----------------------------------------------------------------

laborer = add_agent!(
    model,
    consumer_spec;
    demands=all_commodities,
    endowments=[
        CommodityRef(:labor),
        :labor_4,
    ],
    endowment_quantities=labor_endowment,
    observed_variables=observed_interest_variables,
    name=:laborer,
)


# ----------------------------------------------------------------
# 6. Money owner
# ----------------------------------------------------------------

moneyOwner = add_agent!(
    model,
    consumer_spec;
    demands=all_commodities,
    endowments=CommodityRef(:money),
    endowment_quantities=money_endowment,
    observed_variables=observed_interest_variables,
    name=:moneyOwner,
)


# ----------------------------------------------------------------
# 7. Solve
# ----------------------------------------------------------------

result = solve(
    model;
    p0=[
        1.0,
        2.0 / 3.0,
        1.0 / 3.0,
        1.0e-3,
        100.0 / 3.0,
        100.0 / 3.0,
        100.0 / 3.0,
        100.0 / 3.0,
    ],
    residual_tol=1.0e-8,
    silent=true,
)


# ----------------------------------------------------------------
# 8. Results
# ----------------------------------------------------------------

endogenous_variables = result.agent_variable_values[1]
rates = endogenous_variables[1:3]
terminal_full_price = endogenous_variables[4]
p = result.prices

laborer_income = sum(p[1:4] .* labor_endowment)
money_owner_income = sum(p[5:8] .* money_endowment)

println()
println("========== GEMB four-period endogenous-interest equilibrium ==========")
println("Solved:                     ", result.solved)
println("Prices:                     ", p)
println("Primitive rates:            ", rates)
println("Terminal full price:        ", terminal_full_price)
println("Laborer income:             ", laborer_income)
println("Money owner income:         ", money_owner_income)
println("Max natural residual:       ", result.max_natural_residual)
println("=====================================================================")


# ----------------------------------------------------------------
# 9. Analytical benchmark
# ----------------------------------------------------------------

expected_rates = [
    beta[1] / beta[2] - 1.0,
    beta[2] / beta[3] - 1.0,
    beta[3] / beta[4] - 1.0,
]

expected_prices = [
    1.0,
    2.0 / 3.0,
    1.0 / 3.0,
    0.0,
    100.0 / 3.0,
    100.0 / 3.0,
    100.0 / 3.0,
    100.0 / 3.0,
]

@assert result.solved
@assert result.mcp_solved
@assert result.all_markets_clear

@assert isapprox(
    rates,
    expected_rates;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert isapprox(
    p,
    expected_prices;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert isapprox(
    terminal_full_price,
    1.0 / 3.0;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert isapprox(
    laborer_income,
    200.0;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert isapprox(
    money_owner_income,
    400.0 / 3.0;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert maximum(abs, result.agent_conditions[1]) <= 1.0e-7
@assert maximum(abs, result.total_net_supply) <= 1.0e-7
@assert result.max_natural_residual <= 1.0e-7
