# ================================================================
# gemb_CES_tax_nc4_na3_v3.jl
#
# GEMB example: use an ad valorem claim to shift industrial structure.
#
# Public high-level claim interface:
#
#     claim_rate = tau
#     claim = CommodityRef(:claim)
#
# Commodities:
#   1. wheat
#   2. iron
#   3. labor
#   4. claim
#
# Agents:
#   1. wheat_producer
#   2. iron_producer
#   3. laborer
#
# Policy mechanism:
#   - the wheat producer supplies one claim unit together with each unit
#     of wheat output;
#   - the iron producer must acquire claims according to claim_rate;
#   - the equilibrium claim price transfers value from iron production
#     toward wheat production.
#
# Numeraire:
#   wheat price = 1
#
# The file solves automatically when included.
# ================================================================

using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


# ----------------------------------------------------------------
# 1. Parameters
# ----------------------------------------------------------------

const TAX_RATE = 0.10
const LABOR_SUPPLY = 100.0


# ----------------------------------------------------------------
# 2. High-level model container
# ----------------------------------------------------------------

gemb_model =
    GEMBModel(
        [
            :wheat,
            :iron,
            :labor,
            :claim,
        ];
        numeraire=:wheat,
        numeraire_value=1.0,
    )


# ----------------------------------------------------------------
# 3. Wheat producer
#
# Technology:
#
#     y_wheat =
#         5 * x_wheat^0.6 * x_iron^0.1 * x_labor^0.3
#
# The producer supplies:
#
#     1 unit wheat
#     1 unit claim
#
# per unit of activity.
# ----------------------------------------------------------------

add_agent!(
    gemb_model,
    CESSpec(
        [0.6, 0.1, 0.3];
        alpha=5.0,
    );
    outputs=[
        :wheat,
        :claim,
    ],
    demands=[
        :wheat,
        :iron,
        :labor,
    ],
    activity_start=1900.0,
    name=:wheat_producer,
)


# ----------------------------------------------------------------
# 4. Iron producer
#
# Technology:
#
#     y_iron =
#         3 * x_wheat^0.4 * x_iron^0.4 * x_labor^0.2
#
# The ad valorem policy is expressed entirely with the public high-level
# claim interface:
#
#     claim_rate = TAX_RATE
#     claim      = CommodityRef(:claim)
#
# If B is ordinary input expenditure, signed claim expenditure is
#
#     TAX_RATE * B.
#
# Zero profit therefore implies
#
#     p_iron * z_iron = (1 + TAX_RATE) * B.
# ----------------------------------------------------------------

add_agent!(
    gemb_model,
    CESSpec(
        [0.4, 0.4, 0.2];
        alpha=3.0,
    );
    outputs=:iron,
    demands=[
        :wheat,
        :iron,
        :labor,
    ],
    claim_rate=TAX_RATE,
    claim=CommodityRef(
        :claim,
    ),
    activity_start=600.0,
    name=:iron_producer,
)


# ----------------------------------------------------------------
# 5. Laborer
#
# Utility:
#
#     u =
#         x_wheat^0.2 * x_iron^0.7 * x_labor^0.1
#
# Endowment:
#
#     100 units of labor.
#
# alpha = 1 / 100 keeps the activity variable equal to per-worker
# utility while demand is aggregated over the 100 workers.
# ----------------------------------------------------------------

add_agent!(
    gemb_model,
    CESSpec(
        [0.2, 0.7, 0.1];
        alpha=1.0 / LABOR_SUPPLY,
    );
    demands=[
        :wheat,
        :iron,
        :labor,
    ],
    endowments=:labor,
    endowment_quantities=LABOR_SUPPLY,
    activity_start=2.0,
    name=:laborer,
)


# ----------------------------------------------------------------
# 6. Solve directly from GEMBModel
# ----------------------------------------------------------------

result =
    solve(
        gemb_model;
        p0=[
            1.0,
            2.3,
            10.0,
            0.06,
        ],
        residual_tol=1.0e-8,
        silent=true,
    )


# ----------------------------------------------------------------
# 7. Results
# ----------------------------------------------------------------

wheat_activity =
    result.agent_variable_values[1][1]

iron_activity =
    result.agent_variable_values[2][1]

laborer_utility =
    result.agent_variable_values[3][1]

claim_price =
    result.prices[4]

println(
    "========== GEMB CES claim policy: 4 commodities, 3 agents ==========",
)

println(
    "Solved:               ",
    result.solved,
)

println(
    "Prices:               ",
    result.prices,
)

println(
    "Wheat activity:       ",
    wheat_activity,
)

println(
    "Iron activity:        ",
    iron_activity,
)

println(
    "Laborer utility:      ",
    laborer_utility,
)

println(
    "Claim price:          ",
    claim_price,
)

println(
    "Wheat claim revenue rate: ",
    claim_price / result.prices[1],
)

println(
    "Total net supply:     ",
    result.total_net_supply,
)

println(
    "Max natural residual: ",
    result.max_natural_residual,
)

println(
    "====================================================================",
)


# ----------------------------------------------------------------
# 8. Benchmark checks
#
# The high-level GEMBModel formulation is economically identical to the
# previous low-level integer-index formulation.
# ----------------------------------------------------------------

@assert result.solved
@assert result.mcp_solved

@assert isapprox(
    result.prices,
    [
        1.0,
        2.344561,
        9.956287,
        0.06521739,
    ];
    atol=1.0e-5,
    rtol=1.0e-5,
)

@assert isapprox(
    wheat_activity,
    1991.257;
    atol=1.0e-2,
    rtol=1.0e-5,
)

@assert isapprox(
    iron_activity,
    609.287;
    atol=1.0e-2,
    rtol=1.0e-5,
)

@assert isapprox(
    laborer_utility,
    1.954426;
    atol=1.0e-5,
    rtol=1.0e-5,
)

@assert maximum(
    abs,
    result.total_net_supply,
) <= 1.0e-6

@assert result.max_natural_residual <= 1.0e-7
