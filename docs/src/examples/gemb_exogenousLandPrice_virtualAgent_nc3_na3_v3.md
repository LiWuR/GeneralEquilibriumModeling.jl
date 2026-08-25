# gemb_exogenousLandPrice_virtualAgent_nc3_na3_v3

Source file: `examples/gemb_exogenousLandPrice_virtualAgent_nc3_na3_v3.jl`

````julia
# ================================================================
# gemb_exogenousLandPrice_virtualAgent_nc3_na3_v3.jl
#
# High-level GEMB validation of the virtual-agent representation of
# an auxiliary variable and its paired auxiliary condition.
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
# Original low-level closure:
#
#   landSupply = AuxiliaryVariable(...)
#   0 <= p_land - land_price  _|_  landSupply >= 0
#
# High-level virtual-agent closure:
#
#   landSupply  <->  virtual agent activity
#   p_land - land_price  <->  explicit activity condition
#
# The land owner supplies its activity level of land
# and spends all land income on output:
#
#   z_T = land supply
#   C_T = p_T * z_T / p_Y
#
# so its local net supply in [land, output] order is
#
#   [z_T, -p_T * z_T / p_Y].
#
# Benchmark equilibrium:
#   prices = [2, 1, 4]
#   producer activity = 100
#   virtual land-supply activity = 25
#
# No GEM AuxiliaryVariable or AuxiliaryEquation is used.
# ================================================================

using GEM
using GEMB

labor_endowment = 100.0
land_price = 4.0

model = GEMBModel(
    [:output, :labor, :land];
    numeraire=:labor,
    numeraire_value=1.0,
)

producer = add_agent!(
    model,
    CESSpec(
        [0.5, 0.5];
        es=1.0,
        alpha=2.0,
    );
    outputs=:output,
    demands=[:labor, :land],
    activity_start=100.0,
    name=:producer,
)

laborer = add_agent!(
    model,
    MarshallDemandConsumerSpec(
        (income, prices) -> [income / prices[1]],
    );
    demands=:output,
    endowments=:labor,
    endowment_quantities=labor_endowment,
    name=:laborer,
)

land_supplier_spec = ActivityDemandSpec(
    (
        activity,
        prices,
        observed_values,
    ) -> begin
        pY = prices[1]
        pT = observed_values[1]

        return [
            pT * activity / pY,
        ]
    end;
    producer_condition_function=
        (
            local_variables,
            local_prices,
            net_supply,
            observed_values,
        ) -> [
            local_prices[1] - land_price,
        ],
)

landOwner = add_agent!(
    model,
    land_supplier_spec;
    outputs=:land,
    demands=:output,
    observed_variables=[
        PriceVariableRef(:land),
    ],
    activity_start=25.0,
    activity_lower_bound=0.0,
    activity_upper_bound=Inf,
    name=:landOwner,
)

result = solve(
    model;
    p0=[2.0, 1.0, 4.0],
    residual_tol=1.0e-8,
    silent=true,
)

producer_activity =
    result.agent_variable_values[1][1]

land_supply =
    result.agent_variable_values[3][1]

println()
println("========== Exogenous land price: virtual-agent validation ==========")
println("Solved: ", result.solved)
println("Prices [output, labor, land]: ", result.prices)
println("Producer activity: ", producer_activity)
println("Land supply (virtual-agent activity): ", land_supply)
println("Producer net supply: ", result.agent_net_supplies[1])
println("Laborer net supply: ", result.agent_net_supplies[2])
println("Land-owner net supply: ", result.agent_net_supplies[3])
println("Total net supply: ", result.total_net_supply)
println("Max natural residual: ", result.max_natural_residual)
println("===================================================================")

@assert result.solved

@assert isapprox(
    result.prices,
    [2.0, 1.0, 4.0];
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert isapprox(
    producer_activity,
    100.0;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert isapprox(
    land_supply,
    25.0;
    atol=1.0e-7,
    rtol=1.0e-7,
)

@assert maximum(abs, result.total_net_supply) <= 1.0e-7
@assert result.max_natural_residual <= 1.0e-7

````
