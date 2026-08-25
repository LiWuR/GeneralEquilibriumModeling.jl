# ================================================================
# consumer_specs_v1.jl
#
# User-facing consumer behavior specifications for GEMB.
#
# A consumer specification describes behavioral logic only. It does not
# contain commodity indices, endowments, starting values, variable bounds,
# observed-variable references, or an agent name. Those belong to the
# economic-agent mapping layer and are supplied to build_agent(spec; ...).
# ================================================================

export AbstractConsumerSpec,
       MarginalUtilityConsumerSpec,
       MarshallDemandConsumerSpec


abstract type AbstractConsumerSpec end


"""
    MarginalUtilityConsumerSpec(marginal_function)

Describe a consumer by an explicit marginal-utility function.

The function may accept either

    marginal_function(demand)

or

    marginal_function(demand, observed_values)

as already supported by GEMB's validated marginal-utility builder path.
Commodity mappings and endowments are supplied later to `build_agent`.
"""
struct MarginalUtilityConsumerSpec{F} <: AbstractConsumerSpec
    marginal_function::F
end


"""
    MarshallDemandConsumerSpec(demand_function)

Describe a consumer by an explicit Marshall-demand function.

The function may accept either

    demand_function(income, prices)

or

    demand_function(income, prices, observed_values)

as already supported by GEMB's validated direct-demand builder path.
Commodity mappings and endowments are supplied later to `build_agent`.
"""
struct MarshallDemandConsumerSpec{F} <: AbstractConsumerSpec
    demand_function::F
end
