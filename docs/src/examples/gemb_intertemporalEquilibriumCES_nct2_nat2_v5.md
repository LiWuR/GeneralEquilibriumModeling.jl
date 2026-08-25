# gemb_intertemporalEquilibriumCES_nct2_nat2_v5

Source file: `examples/gemb_intertemporalEquilibriumCES_nct2_nat2_v5.jl`

````julia
# ================================================================
# gemb_intertemporalEquilibriumCES_nct2_nat2_v5.jl
#
# Intertemporal pure-exchange/production equilibrium using the final
# GEMB AgentTemplate architecture.
#
# Repeated producers use AgentTemplate. The intertemporal consumer is one
# concrete agent and therefore uses ordinary add_agent!.
#
# Two consumer formulations are available:
#
#   :activity_demand
#       CESSpec with one utility/activity variable.
#
#   :marginal_utility
#       CESMarginalUtilitySpec with dated consumption variables and one
#       budget multiplier.
#
# Change `consumer_formulation` to compare the two formulations.
# The file solves automatically when included.
# ================================================================

using GEM
using GEMB


# ----------------------------------------------------------------
# 1. Parameters
# ----------------------------------------------------------------

np = 200

initial_product_endowment = 150.0
labor_endowment = 100.0

producer_activity_start = 100.0
consumer_activity_start = 100.0

consumer_demand_floor = 1.0e-10
positive_price_floor = 1.0e-10

consumer_formulation = :activity_demand

consumer_formulation in (
    :activity_demand,
    :marginal_utility,
) || throw(ArgumentError(
    "consumer_formulation must be :activity_demand or :marginal_utility."
))


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


# ----------------------------------------------------------------
# 3. Model container
# ----------------------------------------------------------------

gemb_model =
    GEMBModel(
        [
            product,
            labor,
        ];
        numeraire=CommodityRef(
            :product;
            type=1,
            period=1,
        ),
        numeraire_value=1.0,
    )


# ----------------------------------------------------------------
# 4. Repeated producer
#
# In each period t = 1, ..., np-1:
#
#     product_t + labor_t -> product_(t+1)
#
# with
#
#     product_(t+1) = 2 * sqrt(product_t * labor_t).
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
        activity_start=producer_activity_start,
    )

add_agents!(
    gemb_model,
    producer,
)


# ----------------------------------------------------------------
# 5. Intertemporal consumer
#
# The consumer is one concrete agent. CommodityRef with omitted `period`
# selects the whole dated path.
# ----------------------------------------------------------------

consumer_demands = [
    CommodityRef(
        :product;
        type=1,
    ),
]

consumer_endowments = [
    CommodityRef(
        :product;
        type=1,
        period=1,
    ),
    CommodityRef(
        :labor;
        type=1,
    ),
]

consumer_endowment_quantities =
    vcat(
        [
            initial_product_endowment,
        ],
        fill(
            labor_endowment,
            np - 1,
        ),
    )

if consumer_formulation == :activity_demand
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
        name=:consumer,
        demands=consumer_demands,
        endowments=consumer_endowments,
        endowment_quantities=consumer_endowment_quantities,
        activity_start=consumer_activity_start,
    )
else
    wealth0 =
        initial_product_endowment +
        (np - 1) *
        labor_endowment

    add_agent!(
        gemb_model,
        CESMarginalUtilitySpec(
            fill(
                1.0 / np,
                np,
            );
            es=1.0,
        );
        name=:consumer,
        demands=consumer_demands,
        endowments=consumer_endowments,
        endowment_quantities=consumer_endowment_quantities,
        demand_start=fill(
            wealth0 / np,
            np,
        ),
        demand_lower_bounds=fill(
            consumer_demand_floor,
            np,
        ),
        multiplier_start=1.0 / wealth0,
        multiplier_lower_bound=0.0,
    )
end


# ----------------------------------------------------------------
# 6. Build and solve
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
# 7. Results
# ----------------------------------------------------------------

product_prices =
    result.prices[
        1:np
    ]

labor_prices =
    result.prices[
        (np + 1):(2 * np - 1)
    ]

producer_activities = [
    result.agent_variable_values[t][1]
    for t in 1:(np - 1)
]

consumer_variables =
    result.agent_variable_values[end]

println()
println("Intertemporal CES equilibrium")
println("-----------------------------")
println("Solved: ", result.solved)
println("Consumer formulation: ", consumer_formulation)
println("Periods: ", np)
println("Commodities: ", length(model.commodity_names))
println("Agents: ", length(model.agents))
println("First product price: ", product_prices[1])
println("Last product price: ", product_prices[end])
println("First labor price: ", labor_prices[1])
println("Last labor price: ", labor_prices[end])
println("First producer activity: ", producer_activities[1])
println("Last producer activity: ", producer_activities[end])
println("Consumer MCP variables: ", length(consumer_variables))
println("Max natural residual: ", result.max_natural_residual)
println(
    "Max market-clearing residual: ",
    maximum(
        abs.(
            result.total_net_supply,
        ),
    ),
)

````
