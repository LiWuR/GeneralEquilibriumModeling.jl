# gemb_exogenousLandPrice_nc3_na3_v6

Source file: `examples/gemb_exogenousLandPrice_nc3_na3_v6.jl`

````julia
# ================================================================
# gemb_exogenousLandPrice_nc3_na3_v6.jl
#
# Three commodities:
#   1. output
#   2. labor
#   3. land
#
# Three agents:
#   1. producer
#   2. laborer
#   3. land owner
#
# Closure:
#   p_labor = 1                 (numeraire)
#   p_land  = land_price        (auxiliary equation)
#   landSupply is endogenous    (auxiliary variable)
#
# Benchmark equilibrium:
#   prices = [2, 1, 4]
#   producer activity = 100
#   landSupply = 25
# ================================================================

using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB


# ----------------------------------------------------------------
# 1. Parameters
# ----------------------------------------------------------------

labor_endowment = 100.0
land_price = 4.0


# ----------------------------------------------------------------
# 2. Exogenous land price / endogenous land supply closure
# ----------------------------------------------------------------
#
# landSupply is an endogenous auxiliary variable.
#
# The auxiliary equation is paired with landSupply:
#
#     0 <= p_land - land_price  _|_  landSupply >= 0.
#
# Since landSupply > 0 at the benchmark equilibrium,
#
#     p_land = land_price.
#

landSupply = AuxiliaryVariable(
    :landSupply;
    start=25.0,
    lower_bound=0.0,
    upper_bound=Inf,
)

landPriceEq = AuxiliaryEquation(
    :landPriceEq,
    :landSupply,
    values -> values[1] - land_price;
    observed_variables=[
        PriceVariableRef(:land),
    ],
)


# ----------------------------------------------------------------
# 3. Producer
# ----------------------------------------------------------------
#
# Technology:
#
#     Y = 2 * sqrt(L * T)
#
# represented by a Cobb-Douglas CES specification.
#
# The producer has constant returns to scale, so the default
# UnitProfitConditions() gives zero unit profit.
#

producer = build_agent(
    CESSpec(
        [0.5, 0.5];
        es=1.0,
        alpha=2.0,
    );
    output_indices=[1],
    demand_indices=[2, 3],
    activity_start=100.0,
    name=:producer,
)


# ----------------------------------------------------------------
# 4. Laborer
# ----------------------------------------------------------------
#
# The laborer has a fixed labor endowment and spends all labor
# income on output:
#
#     C_L = p_L * labor_endowment / p_Y.
#
# Hence its budget is balanced identically.
#

laborer = build_agent(
    MarshallDemandConsumerSpec(
        (income, prices) -> [income / prices[1]],
    );
    demand_indices=[1],
    endowment_indices=[2],
    endowment_quantities=[labor_endowment],
    name=:laborer,
)


# ----------------------------------------------------------------
# 5. Land owner
# ----------------------------------------------------------------
#
# The land owner observes the endogenous auxiliary variable
# landSupply. The auxiliary variable determines the endogenous amount
# of land supplied; the land owner receives the corresponding land
# income and spends all of it on output:
#
#     C_T = p_T * landSupply / p_Y.
#
# Local commodity order is [output, land], so net supply is
#
#     [-C_T, landSupply].
#
# The land owner has no own endogenous variable.
#

landOwner = NetSupplyAgent(
    [1, 3],
    (local_variables, local_prices, observed_values) -> begin
        qT = observed_values[1]
        pY = local_prices[1]
        pT = local_prices[2]

        return [
            -pT * qT / pY,
            qT,
        ]
    end;
    variable_names=Symbol[],
    observed_variables=[
        AuxiliaryVariableRef(:landSupply),
    ],
    name=:landOwner,
)


# ----------------------------------------------------------------
# 6. Equilibrium model
# ----------------------------------------------------------------
#
# Labor is the numeraire:
#
#     p_L = 1.
#
# The endogenous variables are therefore:
#
#     producer activity,
#     p_output,
#     p_land,
#     landSupply.
#

model = NetSupplyEquilibriumModel(
    AbstractNetSupplyAgent[
        producer,
        laborer,
        landOwner,
    ],
    [:output, :labor, :land];
    auxiliary_variables=[
        landSupply,
    ],
    auxiliary_equations=[
        landPriceEq,
    ],
    numeraire_index=2,
    numeraire_value=1.0,
)


# ----------------------------------------------------------------
# 7. Solve
# ----------------------------------------------------------------

result = solve_equilibrium_model_mcp_jump(
    model;
    p0=[2.0, 1.0, 4.0],
    auxiliary0=[25.0],
)


# ----------------------------------------------------------------
# 8. Results
# ----------------------------------------------------------------

println()
println("========== Exogenous land-price equilibrium ==========")
println("Solved: ", result.solved)
println("Prices [output, labor, land]: ", result.prices)
println("Producer activity: ", result.agent_variable_values[1][1])
println("Land supply: ", result.auxiliary_values[:landSupply])
println("Producer net supply: ", result.agent_net_supplies[1])
println("Laborer net supply: ", result.agent_net_supplies[2])
println("Land-owner net supply: ", result.agent_net_supplies[3])
println("Total net supply: ", result.total_net_supply)
println("Max natural residual: ", result.max_natural_residual)

````
