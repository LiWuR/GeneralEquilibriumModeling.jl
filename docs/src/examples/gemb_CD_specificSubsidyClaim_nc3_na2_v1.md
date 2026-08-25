# gemb_CD_specificSubsidyClaim_nc3_na2_v1

Source file: `examples/gemb_CD_specificSubsidyClaim_nc3_na2_v1.jl`

````julia
# ================================================================
# gemb_CD_specificSubsidyClaim_nc3_na2_v1.jl
#
# High-level GEMB example: Cobb--Douglas equilibrium with a
# specific subsidy represented directly through ActivityDemandSpec.
#
# This is the minimal high-level formulation:
#
#   - no GEMB source modification;
#   - no virtual commodity;
#   - no virtual agent;
#   - no endogenous claim_rate;
#   - no auxiliary variable or auxiliary equation.
#
# Commodities:
#   1. prod
#   2. lab
#   3. subsidy_claim
#
# Agents:
#   1. firm
#   2. consumer
#
# Firm technology:
#
#     y = prod^0.5 * lab^0.5
#
# Consumer preferences:
#
#     u = prod^0.8 * lab^0.2
#
# Consumer endowment:
#
#     100 units of labor
#      20 units of subsidy claims
#
# Specific subsidy:
#
#     t = -0.2 per unit of firm activity
#
# Claim settlement:
#
#     p_claim * q_claim = t * z
#
# hence
#
#     q_claim = t * z / p_claim.
#
# Since t < 0 and the equilibrium claim demand is positive, the
# equilibrium claim price is negative.
#
# Numeraire:
#
#     p_prod = 1
#
# Benchmark equilibrium:
#
#     prices        = [1.0, 0.36, -0.514285714285714]
#     firm activity = 51.4285714285714
#     claim demand  = 20.0
#
# This file solves the model immediately when included.
# ================================================================

using GEM
using GEMB


# ----------------------------------------------------------------
# 1. Parameters
# ----------------------------------------------------------------

const SPECIFIC_SUBSIDY_RATE = -0.2
const LABOR_ENDOWMENT = 100.0
const CLAIM_SUPPLY = 20.0

const BETA_FIRM = [0.5, 0.5]
const BETA_CONSUMER = [0.8, 0.2]


# ----------------------------------------------------------------
# 2. High-level GEMB model
#
# prod is the numeraire.
#
# The labor price is kept strictly positive because both Cobb--Douglas
# demand formulas divide by it.
#
# The subsidy-claim price is free because the equilibrium price is
# negative under a subsidy.
# ----------------------------------------------------------------

model = GEMBModel(
    [
        :prod,
        CommoditySpec(
            :lab;
            price_lower_bound=1.0e-10,
        ),
        CommoditySpec(
            :subsidy_claim;
            price_lower_bound=-Inf,
            price_upper_bound=Inf,
        ),
    ];
    numeraire=:prod,
    numeraire_value=1.0,
)


# ----------------------------------------------------------------
# 3. Firm
#
# ActivityDemandSpec returns the complete conditional demand vector
#
#     [prod_input, lab_input, claim_demand].
#
# The first two entries are ordinary Cobb--Douglas cost-minimizing
# inputs. The third entry directly implements the specific-subsidy
# settlement rule
#
#     p_claim * q_claim = t * z,
#
# so
#
#     q_claim = t * z / p_claim.
#
# Because this demand system is homogeneous in activity, the default
# UnitProfitConditions used by GEMB gives
#
#     unit ordinary input cost
#     + p_claim * unit claim demand
#     - p_prod
#     = 0,
#
# which simplifies to
#
#     unit ordinary input cost + t - p_prod = 0.
# ----------------------------------------------------------------

firm_spec = ActivityDemandSpec(
    function (activity, prices)
        p_prod, p_lab, p_claim = prices

        ordinary_inputs = GEMB.CES_input(
            BETA_FIRM,
            activity,
            [
                p_prod,
                p_lab,
            ];
            es=1.0,
            alpha=1.0,
        )

        claim_demand =
            SPECIFIC_SUBSIDY_RATE *
            activity /
            p_claim

        return [
            ordinary_inputs[1],
            ordinary_inputs[2],
            claim_demand,
        ]
    end,
)

firm = add_agent!(
    model,
    firm_spec;
    outputs=:prod,
    demands=[
        :prod,
        :lab,
        :subsidy_claim,
    ],
    activity_start=50.0,
    name=:firm,
)


# ----------------------------------------------------------------
# 4. Consumer
#
# The consumer has no agent variables, matching the original GEM
# specific-subsidy example.
#
# Income is the market value of the labor and claim endowments:
#
#     income =
#         100 * p_lab +
#          20 * p_claim.
#
# Cobb--Douglas Marshallian demands are
#
#     x_prod = 0.8 * income / p_prod
#     x_lab  = 0.2 * income / p_lab.
# ----------------------------------------------------------------

consumer_spec = MarshallDemandConsumerSpec(
    function (income, prices)
        p_prod, p_lab = prices

        return [
            BETA_CONSUMER[1] * income / p_prod,
            BETA_CONSUMER[2] * income / p_lab,
        ]
    end,
)

consumer = add_agent!(
    model,
    consumer_spec;
    demands=[
        :prod,
        :lab,
    ],
    endowments=[
        :lab,
        :subsidy_claim,
    ],
    endowment_quantities=[
        LABOR_ENDOWMENT,
        CLAIM_SUPPLY,
    ],
    name=:consumer,
)


# ----------------------------------------------------------------
# 5. Solve
# ----------------------------------------------------------------

result = solve(
    model;
    p0=[
        1.0,
        0.36,
        -0.5,
    ],
    residual_tol=1.0e-8,
    silent=true,
)


# ----------------------------------------------------------------
# 6. Results
# ----------------------------------------------------------------

firm_activity =
    result.agent_variable_values[1][1]

firm_claim_demand =
    -result.agent_net_supplies[1][3]

claim_price =
    result.prices[3]

claim_settlement_value =
    claim_price *
    firm_claim_demand

specific_subsidy_value =
    SPECIFIC_SUBSIDY_RATE *
    firm_activity


println(
    "========== GEMB specific subsidy: 3 commodities, 2 agents ==========",
)

println(
    "Solved:                    ",
    result.solved,
)

println(
    "Prices:                    ",
    result.prices,
)

println(
    "Firm activity:             ",
    firm_activity,
)

println(
    "Firm claim demand:         ",
    firm_claim_demand,
)

println(
    "Claim price:               ",
    claim_price,
)

println(
    "p_claim * claim demand:    ",
    claim_settlement_value,
)

println(
    "specific subsidy * output: ",
    specific_subsidy_value,
)

println(
    "Firm net supply:           ",
    result.agent_net_supplies[1],
)

println(
    "Consumer net supply:       ",
    result.agent_net_supplies[2],
)

println(
    "Total net supply:          ",
    result.total_net_supply,
)

println(
    "Max natural residual:      ",
    result.max_natural_residual,
)

println(
    "====================================================================",
)


# ----------------------------------------------------------------
# 7. Benchmark checks
#
# These are the analytical values of the corresponding low-level GEM
# example with t = -0.2.
# ----------------------------------------------------------------

expected_prices = [
    1.0,
    0.36,
    -18.0 / 35.0,
]

expected_activity =
    360.0 / 7.0

@assert result.solved
@assert result.mcp_solved
@assert result.all_markets_clear

@assert isapprox(
    result.prices,
    expected_prices;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert isapprox(
    firm_activity,
    expected_activity;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert isapprox(
    firm_claim_demand,
    CLAIM_SUPPLY;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert isapprox(
    claim_settlement_value,
    specific_subsidy_value;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert maximum(
    abs,
    result.total_net_supply,
) <= 1.0e-7

@assert result.max_natural_residual <= 1.0e-7

````
