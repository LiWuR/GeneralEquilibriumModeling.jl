# ================================================================
# gemb_intertemporalEquilibrium_variableClaim_nct3_nat3_v1.jl
#
# Intertemporal CES equilibrium with period-varying ad valorem claims.
#
# Main purpose:
#
#   demonstrate ByPeriod(...) inside an economically complete
#   intertemporal equilibrium with dated claim commodities.
#
# Final GEMB architecture:
#
#   dated commodities      -> CommoditySpec / CommodityRef
#   repeated producer      -> AgentTemplate / add_agents!
#   concrete households    -> add_agent!
#   relative dates         -> RelativePeriod
#   period-varying values  -> ByPeriod
#   low-level GEM model    -> build_model
#
# The file solves automatically when included.
# ================================================================

using GEM
using GEMB


# ----------------------------------------------------------------
# 1. Parameters
# ----------------------------------------------------------------

np = 3

initial_product_endowment = 150.0
labor_endowment = 100.0

# One producer exists in each production period t = 1, ..., np-1.
#
# The two values below are matched to template position:
#
#     period 1 -> 0.05
#     period 2 -> 0.20
#
# A plain vector would keep its ordinary vector meaning. Wrapping it in
# ByPeriod explicitly gives it period-varying template semantics.
claim_rates = [
    0.05,
    0.20,
]

claim_endowment = 10.0

producer_activity_start = 100.0
household_activity_start = 100.0
claim_owner_activity_start = 10.0

positive_price_floor = 1.0e-10


# ----------------------------------------------------------------
# 2. Dated commodity groups
# ----------------------------------------------------------------

product =
    CommoditySpec(
        :product;
        axes=(
            type=1:1,
            period=1:np,
        ),
        price_lower_bound=positive_price_floor,
    )

labor =
    CommoditySpec(
        :labor;
        axes=(
            type=1:1,
            period=1:(np - 1),
        ),
        price_lower_bound=positive_price_floor,
    )

claim =
    CommoditySpec(
        :claim;
        axes=(
            type=[:tax],
            period=1:(np - 1),
        ),
        price_lower_bound=positive_price_floor,
    )


# ----------------------------------------------------------------
# 3. Model container
# ----------------------------------------------------------------

gemb_model =
    GEMBModel(
        [
            product,
            labor,
            claim,
        ];
        numeraire=CommodityRef(
            :product;
            type=1,
            period=1,
        ),
        numeraire_value=1.0,
    )


# ----------------------------------------------------------------
# 4. Repeated producer with period-varying claim_rate
#
# In each period t = 1, ..., np-1:
#
#     product_t + labor_t -> product_(t+1)
#
# The producer also demands a dated claim commodity. The ad valorem
# claim rate varies across periods through ByPeriod.
# ----------------------------------------------------------------

producer =
    AgentTemplate(
        :producer,
        CESSpec(
            [
                0.5,
                0.5,
            ];
            es=1.0,
            alpha=2.0,
        );
        periods=1:(np - 1),
        demands=[
            CommodityRef(
                :product;
                type=1,
                period=RelativePeriod(0),
            ),
            CommodityRef(
                :labor;
                type=1,
                period=RelativePeriod(0),
            ),
        ],
        outputs=[
            CommodityRef(
                :product;
                type=1,
                period=RelativePeriod(1),
            ),
        ],
        claim_rate=ByPeriod(
            claim_rates,
        ),
        claim=CommodityRef(
            :claim;
            type=:tax,
            period=RelativePeriod(0),
        ),
        activity_start=producer_activity_start,
    )

producer_agents =
    add_agents!(
        gemb_model,
        producer,
    )


# ----------------------------------------------------------------
# 5. Household
#
# The household is one concrete intertemporal consumer. It supplies the
# initial product stock and labor in production periods, and consumes the
# dated product path.
# ----------------------------------------------------------------

household =
    add_agent!(
        gemb_model,
        CESSpec(
            fill(
                1.0 / np,
                np,
            );
            es=1.0,
            alpha=1.0,
        );
        name=:household,
        demands=[
            CommodityRef(
                :product;
                type=1,
            ),
        ],
        endowments=[
            CommodityRef(
                :product;
                type=1,
                period=1,
            ),
            CommodityRef(
                :labor;
                type=1,
            ),
        ],
        endowment_quantities=vcat(
            [
                initial_product_endowment,
            ],
            fill(
                labor_endowment,
                np - 1,
            ),
        ),
        activity_start=household_activity_start,
    )


# ----------------------------------------------------------------
# 6. Claim owner
#
# The claim owner supplies a fixed quantity of each dated claim commodity
# and consumes the dated product path.
# ----------------------------------------------------------------

claim_owner =
    add_agent!(
        gemb_model,
        CESSpec(
            fill(
                1.0 / np,
                np,
            );
            es=1.0,
            alpha=1.0,
        );
        name=:claimOwner,
        demands=[
            CommodityRef(
                :product;
                type=1,
            ),
        ],
        endowments=[
            CommodityRef(
                :claim;
                type=:tax,
            ),
        ],
        endowment_quantities=fill(
            claim_endowment,
            np - 1,
        ),
        activity_start=claim_owner_activity_start,
    )


# ----------------------------------------------------------------
# 7. Build and solve
# ----------------------------------------------------------------

model =
    build_model(
        gemb_model,
    )

result =
    solve_equilibrium_model_mcp_jump(
        model;
        p0=ones(
            length(
                model.commodity_names,
            ),
        ),
        residual_tol=1.0e-8,
        silent=true,
    )


# ----------------------------------------------------------------
# 8. Extract dated equilibrium objects
# ----------------------------------------------------------------

product_range =
    1:np

labor_range =
    (np + 1):(2 * np - 1)

claim_range =
    (2 * np):(3 * np - 2)

product_prices =
    result.prices[
        product_range
    ]

labor_prices =
    result.prices[
        labor_range
    ]

claim_prices =
    result.prices[
        claim_range
    ]

producer_activities = [
    result.agent_variable_values[t][1]
    for t in 1:(np - 1)
]

producer_claim_net_supplies = [
    result.agent_net_supplies[t][end]
    for t in 1:(np - 1)
]

producer_claim_demands =
    -producer_claim_net_supplies


# ----------------------------------------------------------------
# 9. Period-by-period diagnostics
# ----------------------------------------------------------------

println()
println("Intertemporal CES equilibrium with variable claims")
println("-------------------------------------------------")
println("Solved: ", result.solved)
println("Periods: ", np)
println("Commodities: ", length(model.commodity_names))
println("Agents: ", length(model.agents))
println()

println("Period-by-period producer/claim results")
println("---------------------------------------")

for t in 1:(np - 1)
    println(
        "period ",
        t,
        ": claim_rate=",
        claim_rates[t],
        ", activity=",
        producer_activities[t],
        ", claim_price=",
        claim_prices[t],
        ", claim_demand=",
        producer_claim_demands[t],
    )
end

println()
println("Product prices: ", product_prices)
println("Labor prices: ", labor_prices)
println("Claim prices: ", claim_prices)
println("Producer activities: ", producer_activities)
println("Producer claim demands: ", producer_claim_demands)
println("Max natural residual: ", result.max_natural_residual)

println(
    "Max market-clearing residual: ",
    maximum(
        abs.(
            result.total_net_supply,
        ),
    ),
)

println(
    "Max claim-market residual: ",
    maximum(
        abs.(
            result.total_net_supply[
                claim_range
            ],
        ),
    ),
)


# ----------------------------------------------------------------
# 10. Compact consistency checks
# ----------------------------------------------------------------

@assert result.solved

@assert length(
    producer_agents,
) == np - 1

@assert length(
    claim_prices,
) == np - 1

@assert length(
    producer_claim_demands,
) == np - 1
