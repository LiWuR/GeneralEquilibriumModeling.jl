# gemb_CD_endogenousClaimRate_nc3_na3_v2

Source file: `examples/gemb_CD_endogenousClaimRate_nc3_na3_v2.jl`

````julia
# ================================================================
# gemb_CD_endogenousClaimRate_nc3_na3_v2.jl
#
# High-level GEMB example: Cobb--Douglas equilibrium with an
# endogenous ad valorem claim rate represented by ConditionAgentSpec.
#
# No GEMB claim-rate machinery is used by the firm. Instead:
#
#   1. taxRateSetter is a ConditionAgentSpec whose variable :tax_rate is tau;
#   2. the firm observes tau through agent_variable_ref(...);
#   3. the firm directly computes claim demand as
#
#          q_claim = tau * base_cost / p_claim;
#
#   4. taxRateSetter imposes
#
#          tau * unit_base_cost = specific_subsidy_rate.
#
# Hence
#
#     p_claim * q_claim
#       = tau * base_cost
#       = specific_subsidy_rate * activity,
#
# so the endogenous ad valorem claim rate exactly reproduces the
# specific subsidy.
#
# Commodities:
#   1. prod
#   2. lab
#   3. subsidy_claim
#
# Agents:
#   1. taxRateSetter   (virtual policy agent)
#   2. firm
#   3. consumer
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
# Specific subsidy benchmark:
#
#     t = -0.2 per unit of firm activity
#
# Numeraire:
#
#     p_prod = 1
#
# Expected equilibrium:
#
#     prices        = [1.0, 0.36, -18/35]
#     firm activity = 360/7
#     tau            = -1/6
#     claim demand   = 20
#
# V2 uses ConditionAgentSpec for the policy variable.
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
# The subsidy-claim price is free because the equilibrium claim price
# is negative under a subsidy.
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
# 3. Virtual tax-rate setter
#
# ConditionAgentSpec gives the virtual policy agent one endogenous
# variable with no economic commodity demand or supply:
#
#     tax_rate = tau.
#
# Its condition is
#
#     tau * unit_base_cost - specific_subsidy_rate = 0.
#
# Therefore
#
#     tau = specific_subsidy_rate / unit_base_cost.
#
# The zero-net-supply adaptation is handled internally by GEMB.
# The selected benchmark has tau = -1/6, safely inside the bounds.
# ----------------------------------------------------------------

tax_rate_setter_spec = ConditionAgentSpec(
    (
        variables,
        observed_values,
    ) -> begin
        tau = variables[1]

        p_prod = observed_values[1]
        p_lab = observed_values[2]

        unit_base_cost = GEMB.CES_cost(
            BETA_FIRM,
            1.0,
            [
                p_prod,
                p_lab,
            ];
            es=1.0,
            alpha=1.0,
        )

        return [
            tau * unit_base_cost -
            SPECIFIC_SUBSIDY_RATE,
        ]
    end,
)

taxRateSetter = add_agent!(
    model,
    tax_rate_setter_spec;
    variable_names=:tax_rate,
    variable_start=-1.0 / 6.0,
    variable_lower_bounds=-0.99,
    variable_upper_bounds=Inf,
    observed_variables=[
        PriceVariableRef(:prod),
        PriceVariableRef(:lab),
    ],
    name=:taxRateSetter,
)


# ----------------------------------------------------------------
# 4. Firm
#
# The firm observes the endogenous tax rate tau from taxRateSetter.
#
# Ordinary Cobb--Douglas inputs are computed first. Their value is
#
#     base_cost = p' * x.
#
# The firm then directly determines claim demand:
#
#     q_claim = tau * base_cost / p_claim.
#
# Therefore claim expenditure is
#
#     p_claim * q_claim = tau * base_cost.
#
# Since the virtual policy condition implies
#
#     tau * unit_base_cost = specific_subsidy_rate,
#
# total claim expenditure becomes
#
#     specific_subsidy_rate * activity.
#
# Thus the model is equivalent to the direct specific-subsidy example,
# but the ad valorem rate is now endogenous.
# ----------------------------------------------------------------

firm_spec = ActivityDemandSpec(
    (
        activity,
        prices,
        observed_values,
    ) -> begin
        p_prod, p_lab, p_claim = prices
        tau = observed_values[1]

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

        base_cost =
            p_prod * ordinary_inputs[1] +
            p_lab * ordinary_inputs[2]

        claim_demand =
            tau *
            base_cost /
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
    observed_variables=[
        agent_variable_ref(
            :taxRateSetter,
            :tax_rate,
        ),
    ],
    activity_start=50.0,
    name=:firm,
)


# ----------------------------------------------------------------
# 5. Consumer
#
# The consumer has no own agent variables.
#
# Income is
#
#     income =
#         labor_endowment * p_lab +
#         claim_supply * p_claim.
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
# 6. Solve
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
# 7. Results
# ----------------------------------------------------------------

endogenous_tau =
    result.agent_variable_values[1][1]

firm_activity =
    result.agent_variable_values[2][1]

firm_claim_demand =
    -result.agent_net_supplies[2][3]

claim_price =
    result.prices[3]

unit_base_cost = GEMB.CES_cost(
    BETA_FIRM,
    1.0,
    result.prices[1:2];
    es=1.0,
    alpha=1.0,
)

claim_value =
    claim_price *
    firm_claim_demand

specific_subsidy_value =
    SPECIFIC_SUBSIDY_RATE *
    firm_activity

rate_setter_gap =
    endogenous_tau *
    unit_base_cost -
    SPECIFIC_SUBSIDY_RATE


println()
println(
    "========== GEMB endogenous claim rate: virtual-agent validation ==========",
)

println(
    "Solved:                         ",
    result.solved,
)

println(
    "Prices:                         ",
    result.prices,
)

println(
    "Endogenous claim rate tau:      ",
    endogenous_tau,
)

println(
    "Unit ordinary input cost:       ",
    unit_base_cost,
)

println(
    "tau * unit base cost:           ",
    endogenous_tau * unit_base_cost,
)

println(
    "Specific subsidy rate:          ",
    SPECIFIC_SUBSIDY_RATE,
)

println(
    "Tax-rate-setter condition gap:  ",
    rate_setter_gap,
)

println(
    "Firm activity:                  ",
    firm_activity,
)

println(
    "Firm claim demand:              ",
    firm_claim_demand,
)

println(
    "Claim price:                    ",
    claim_price,
)

println(
    "p_claim * claim demand:         ",
    claim_value,
)

println(
    "specific subsidy * activity:    ",
    specific_subsidy_value,
)

println(
    "Tax-rate-setter net supply:     ",
    result.agent_net_supplies[1],
)

println(
    "Firm net supply:                ",
    result.agent_net_supplies[2],
)

println(
    "Consumer net supply:            ",
    result.agent_net_supplies[3],
)

println(
    "Total net supply:               ",
    result.total_net_supply,
)

println(
    "Max natural residual:           ",
    result.max_natural_residual,
)

println(
    "==========================================================================",
)


# ----------------------------------------------------------------
# 8. Benchmark checks
#
# The endogenous-rate model should reproduce the direct specific-
# subsidy benchmark exactly.
# ----------------------------------------------------------------

expected_prices = [
    1.0,
    0.36,
    -18.0 / 35.0,
]

expected_activity =
    360.0 / 7.0

expected_tau =
    -1.0 / 6.0


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
    endogenous_tau,
    expected_tau;
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
    endogenous_tau * unit_base_cost,
    SPECIFIC_SUBSIDY_RATE;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert isapprox(
    claim_value,
    specific_subsidy_value;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert maximum(
    abs,
    result.agent_net_supplies[1],
) <= 1.0e-7

@assert maximum(
    abs,
    result.total_net_supply,
) <= 1.0e-7

@assert result.max_natural_residual <= 1.0e-7

````
