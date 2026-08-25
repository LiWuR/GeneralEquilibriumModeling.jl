# gemb_intertemporalEquilibriumCESMarginal_nct2_nat2_v2

Source file: `examples/gemb_intertemporalEquilibriumCESMarginal_nct2_nat2_v2.jl`

````julia
# ================================================================
# gemb_intertemporalEquilibriumCESMarginal_nct2_nat2_v2.jl
#
# Intertemporal general equilibrium built with the current GEM/GEMB
# direct agent-building interface.
#
# IMPORTANT:
# This example intentionally does NOT use the high-level intertemporal
# specification layer:
#
#     CommoditySpec
#     CommodityRef
#     RelativePeriod
#     AgentTemplate
#     GEMBModel
#     add_agents! + build_model
#
# Instead, dated commodities are mapped manually to global commodity
# indices. This makes the example useful as a lower-level reference for
# constructing intertemporal models directly from ordinary GEMB agents.
#
# Commodity types:
#   1. product
#   2. labor
#
# Agent types:
#   1. repeated producer
#   2. one intertemporal consumer
#
# Commodity ordering:
#   1:np                 product in periods 1,...,np
#   (np+1):(2*np-1)      labor in periods 1,...,np-1
#
# Technology in each period t = 1,...,np-1:
#
#     product_(t+1) = 2 * sqrt(product_t * labor_t)
#
# Consumer:
#   - owns initial_product_endowment units of product in period 1;
#   - owns labor_endowment units of labor in every production period;
#   - has equal-share Cobb--Douglas preferences over product
#     consumption in all np periods;
#   - is represented by CESMarginalUtilitySpec, so the consumption
#     quantities and the budget multiplier are explicit MCP variables.
#
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
consumer_demand_floor = 1.0e-10

positive_price_floor = 1.0e-10
residual_tol = 1.0e-5


# ----------------------------------------------------------------
# 2. Manual dated-commodity indexing
#
# product_index(t) = t
# labor_index(t)   = np + t
# ----------------------------------------------------------------

product_indices = collect(1:np)
labor_indices = collect((np + 1):(2 * np - 1))

commodity_names = vcat(
    [Symbol(:product_, t) for t in 1:np],
    [Symbol(:labor_, t) for t in 1:(np - 1)],
)


# ----------------------------------------------------------------
# 3. Repeated producers
#
# Each producer uses:
#
#     product_t
#     labor_t
#
# and supplies:
#
#     product_(t+1)
#
# The same CESSpec is reused in every period. The dated commodity
# mapping is supplied separately through output_indices and
# demand_indices.
# ----------------------------------------------------------------

production_spec = CESSpec(
    [0.5, 0.5];
    es=1.0,
    alpha=2.0,
)

producers = [
    build_agent(
        production_spec;
        output_indices=[t + 1],
        demand_indices=[t, np + t],
        activity_start=producer_activity_start,
        name=Symbol(:producer_, t),
    )
    for t in 1:(np - 1)
]


# ----------------------------------------------------------------
# 4. Intertemporal consumer: marginal-utility/KKT formulation
#
# Equal-share Cobb--Douglas preferences imply
#
#     beta_t = 1 / np
#
# for every dated product.
#
# CESMarginalUtilitySpec with es=1.0 uses the scaled marginal
# utilities
#
#     MU_t = beta_t / x_t.
#
# Unlike the activity-demand consumer formulation, the consumer has
#
#     x_1, ..., x_np, lambda
#
# as explicit MCP variables, where lambda is the budget multiplier.
#
# wealth0 below is evaluated at the initial price vector p0 = 1.
# It is used only to initialize x and lambda. Equilibrium wealth
# remains endogenous through the equilibrium price vector.
# ----------------------------------------------------------------

wealth0 =
    initial_product_endowment +
    (np - 1) * labor_endowment

consumer_spec = CESMarginalUtilitySpec(
    fill(1.0 / np, np);
    es=1.0,
)

consumer = build_agent(
    consumer_spec;
    demand_indices=product_indices,
    endowment_indices=vcat(
        [1],
        labor_indices,
    ),
    endowment_quantities=vcat(
        [initial_product_endowment],
        fill(labor_endowment, np - 1),
    ),
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
    name=:consumer,
)


# ----------------------------------------------------------------
# 5. General-equilibrium model
#
# This is an ordinary GEM EquilibriumModel. Nothing in the model
# object is intertemporal-specific: intertemporal structure enters
# only through the dated commodity indices used by the agents.
#
# product_1 is the numeraire.
#
# Positive price lower bounds are stored in the equilibrium model,
# rather than passed separately as a solver-side price-floor option.
# ----------------------------------------------------------------

agents = vcat(
    producers,
    [consumer],
)

model = EquilibriumModel(
    agents,
    commodity_names;
    numeraire_index=1,
    numeraire_value=1.0,
    price_lower_bounds=fill(
        positive_price_floor,
        length(commodity_names),
    ),
    price_upper_bounds=fill(
        Inf,
        length(commodity_names),
    ),
)


# ----------------------------------------------------------------
# 6. Solve with the standard GEM MCP solver
# ----------------------------------------------------------------

result = solve_equilibrium_model_mcp_jump(
    model;
    p0=ones(length(commodity_names)),
    residual_tol=residual_tol,
    silent=true,
)


# ----------------------------------------------------------------
# 7. Results
# ----------------------------------------------------------------

product_prices =
    result.prices[product_indices]

labor_prices =
    result.prices[labor_indices]

producer_activities = [
    result.agent_variable_values[t][1]
    for t in 1:(np - 1)
]

consumer_variables =
    result.agent_variable_values[end]

consumer_demands =
    consumer_variables[1:np]

consumer_multiplier =
    consumer_variables[np + 1]

println()
println("Intertemporal CES equilibrium: marginal-utility formulation")
println("-----------------------------------------------------------")
println("Solved: ", result.solved)
println("Periods: ", np)
println("Commodities: ", length(commodity_names))
println("Agents: ", length(agents))
println("Consumer MCP variables: ", length(consumer_variables))
println("First product price: ", product_prices[1])
println("Last product price: ", product_prices[end])
println("First labor price: ", labor_prices[1])
println("Last labor price: ", labor_prices[end])
println("First producer activity: ", producer_activities[1])
println("Last producer activity: ", producer_activities[end])
println("First-period consumption: ", consumer_demands[1])
println("Last-period consumption: ", consumer_demands[end])
println("Consumer budget multiplier: ", consumer_multiplier)
println("Max natural residual: ", result.max_natural_residual)
println(
    "Max market-clearing residual: ",
    maximum(abs.(result.total_net_supply)),
)

````
