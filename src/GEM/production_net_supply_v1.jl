# ================================================================
# production_net_supply_v1.jl
#
# Pure production net-supply accounting map for GEM.
#
# The canonical local-variable order is
#
#   [activity, input_1, ..., input_m, production_multiplier].
#
# For output coefficients a_r and activity z, output supply is
#
#   a_r * z.
#
# Each endogenous input quantity x_i enters net supply as
#
#   -x_i.
#
# If the same commodity appears as both an output and an input, the two
# contributions are accumulated into one local net-supply component.
#
# The production multiplier does not enter net supply directly. It remains
# in the local-variable vector because production condition rules may use it.
#
# This module is behavior-neutral: it is shared by stationary-production and
# cost-minimization KKT behavior. It contains no JuMP/PATH code and constructs
# no agent objects.
# ================================================================

"""
    ProductionNetSupplyV1

Map producer activity and input quantities into local commodity net supply,
independently of the producer's equilibrium-condition rule.
"""
module ProductionNetSupplyV1

export ProductionNetSupply,
       production_net_supply

"""
    ProductionNetSupply(
        output_indices,
        output_coefficients,
        input_indices,
    )

Create a pure production net-supply accounting map.

The corresponding local-variable order is fixed as

    [activity, input_1, ..., input_m, production_multiplier]

where `m == length(input_indices)`.

For each output commodity `r`, net supply receives

    output_coefficients[r] * activity.

For each input commodity `i`, net supply receives

    -input_i.

Output and input commodity sets may overlap. In that case their contributions
are accumulated into one net-supply component.

The mapping is independent of the producer's behavioral condition rule.

For production-function agents using `ProductionStationarityConditions` or
`CostMinimizationKKTConditions`, the current GEM solver requires the
`net_supply_function` to be a `ProductionNetSupply` object rather than an
arbitrary Julia function.

This is a solver-structure requirement rather than an economic restriction.
When constructing JuMP expressions, the solver uses the structural information
stored in `ProductionNetSupply`, including the positions of input commodities
and the positions of the activity, input, and production-multiplier variables.

`ProductionNetSupply` is callable and therefore still behaves as a net-supply
mapping. An instance can be evaluated in the same way as a function using the
producer's local variables and local prices.
"""
struct ProductionNetSupply{T<:Real}
    local_indices::Vector{Int}
    output_indices::Vector{Int}
    output_positions::Vector{Int}
    output_coefficients::Vector{T}
    input_indices::Vector{Int}
    input_positions::Vector{Int}
    activity_variable_position::Int
    input_variable_positions::Vector{Int}
    multiplier_variable_position::Int
end

function _normalize_indices(
    value,
    description::AbstractString;
    allow_empty::Bool=false,
)
    indices = value isa Integer ? [Int(value)] : Int.(collect(value))
    !allow_empty && isempty(indices) && throw(ArgumentError(
        "$(description) cannot be empty.",
    ))
    all(>=(1), indices) || throw(ArgumentError(
        "$(description) must contain positive integers.",
    ))
    length(unique(indices)) == length(indices) || throw(ArgumentError(
        "$(description) cannot contain duplicates.",
    ))
    return indices
end

function _normalize_output_coefficients(output_indices, coefficients)
    n = length(output_indices)

    values = if coefficients === nothing
        ones(Float64, n)
    elseif coefficients isa Real
        n == 1 || throw(DimensionMismatch(
            "A scalar output coefficient is allowed only for one output commodity.",
        ))
        [Float64(coefficients)]
    else
        Float64.(collect(coefficients))
    end

    length(values) == n || throw(DimensionMismatch(
        "output_coefficients length must equal output_indices length.",
    ))
    all(isfinite, values) || throw(ArgumentError(
        "output_coefficients must all be finite.",
    ))
    all(>(0), values) || throw(ArgumentError(
        "output_coefficients must all be strictly positive.",
    ))
    return values
end

function _local_positions(local_indices, selected_indices)
    position = Dict(index => k for (k, index) in pairs(local_indices))
    return [position[index] for index in selected_indices]
end

function ProductionNetSupply(
    output_indices,
    output_coefficients,
    input_indices,
)
    outputs = _normalize_indices(output_indices, "output_indices")
    inputs = _normalize_indices(input_indices, "input_indices")
    coefficients = _normalize_output_coefficients(outputs, output_coefficients)

    local_indices = unique(vcat(outputs, inputs))
    output_positions = _local_positions(local_indices, outputs)
    input_positions = _local_positions(local_indices, inputs)

    m = length(inputs)
    activity_position = 1
    input_variable_positions = collect(2:(m + 1))
    multiplier_position = m + 2

    return ProductionNetSupply{eltype(coefficients)}(
        local_indices,
        outputs,
        output_positions,
        coefficients,
        inputs,
        input_positions,
        activity_position,
        input_variable_positions,
        multiplier_position,
    )
end

ProductionNetSupply(output_indices, input_indices) =
    ProductionNetSupply(output_indices, nothing, input_indices)

function _validate_local_arguments(
    mapping::ProductionNetSupply,
    local_variables,
    local_prices,
)
    expected_variable_count = length(mapping.input_variable_positions) + 2
    length(local_variables) == expected_variable_count || throw(DimensionMismatch(
        "Production net supply requires local_variables ordered as " *
        "[activity, inputs..., production_multiplier].",
    ))
    length(local_prices) == length(mapping.local_indices) || throw(DimensionMismatch(
        "local_prices length must equal the number of local commodity indices.",
    ))
    return nothing
end

"""
    production_net_supply(mapping, local_variables, local_prices[, observed_values])

Evaluate production net supply.

The result follows `mapping.local_indices`. Positive values are supplies and
negative values are demands.
"""
function production_net_supply(
    mapping::ProductionNetSupply,
    local_variables,
    local_prices,
)
    _validate_local_arguments(mapping, local_variables, local_prices)

    activity = local_variables[mapping.activity_variable_position]

    # Build zero quantities from an endogenous variable rather than from a
    # concrete numeric type. This keeps the helper compatible with scalar
    # expression types that will later be supplied by JuMP.
    zero_quantity = activity - activity
    supply = [zero_quantity for _ in mapping.local_indices]

    for k in eachindex(mapping.output_positions)
        supply[mapping.output_positions[k]] +=
            mapping.output_coefficients[k] * activity
    end

    for k in eachindex(mapping.input_positions)
        input_quantity = local_variables[mapping.input_variable_positions[k]]
        supply[mapping.input_positions[k]] -= input_quantity
    end

    return supply
end

function production_net_supply(
    mapping::ProductionNetSupply,
    local_variables,
    local_prices,
    observed_values,
)
    return production_net_supply(mapping, local_variables, local_prices)
end

(mapping::ProductionNetSupply)(local_variables, local_prices) =
    production_net_supply(mapping, local_variables, local_prices)

(mapping::ProductionNetSupply)(
    local_variables,
    local_prices,
    observed_values,
) = production_net_supply(
    mapping,
    local_variables,
    local_prices,
    observed_values,
)

end # module ProductionNetSupplyV1
