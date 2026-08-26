# ================================================================
# producer_specs_v1.jl
#
# User-facing producer behavior specifications for GEMB.
#
# A producer specification describes technology/behavior only. It does not
# contain commodity indices, output coefficients, starts, variable bounds,
# observed-variable references, endowments, or an agent name. Those belong
# to the economic-agent mapping layer and are supplied to build_agent.
# ================================================================

export AbstractProducerSpec,
       ProductionFunctionSpec


abstract type AbstractProducerSpec end


"""
    ProductionFunctionSpec(
        production_function,
        marginal_product_function;
        behavior=:stationary,
    )

Describe a producer by a production function and a corresponding marginal-
product function.

`behavior` selects the existing GEM production-condition path:

- `:stationary` for first-order stationary production conditions;
- `:cost_min` for cost-minimization KKT conditions.

The production function may accept either

    production_function(inputs)

or

    production_function(inputs, observed_values)

and the marginal-product function may analogously accept either

    marginal_product_function(inputs)

or

    marginal_product_function(inputs, observed_values)

Commodity mappings, output coefficients, activity/input starts and bounds,
observed variables, and the agent name are supplied later to `build_agent`.
"""
struct ProductionFunctionSpec{F,G} <: AbstractProducerSpec
    production_function::F
    marginal_product_function::G
    production_behavior::Symbol

    function ProductionFunctionSpec(
        production_function::F,
        marginal_product_function::G;
        behavior::Symbol=:stationary,
    ) where {F,G}
        behavior in (:stationary, :cost_min) || throw(ArgumentError(
            "behavior must be :stationary or :cost_min.",
        ))
        return new{F,G}(
            production_function,
            marginal_product_function,
            behavior,
        )
    end
end
