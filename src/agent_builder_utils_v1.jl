# ================================================================
# agent_builder_utils_v1.jl
#
# Shared normalization and validation helpers used by GEMB agent builders.
#
# This file is included directly into module GEMB.
# ================================================================

using GEM:
    AgentVariableRef,
    PriceVariableRef,
    AuxiliaryVariableRef

function _normalize_indices(value, description; allow_empty::Bool=true)
    value === nothing && return Int[]
    indices = value isa Integer ? [Int(value)] : Int.(collect(value))
    !allow_empty && isempty(indices) &&
        throw(ArgumentError("$(description) cannot be empty."))
    all(i -> i >= 1, indices) ||
        throw(ArgumentError("$(description) must contain positive integers."))
    length(unique(indices)) == length(indices) ||
        throw(ArgumentError("$(description) cannot contain duplicate indices."))
    return indices
end

_is_equilibrium_variable_ref(value) =
    value isa AgentVariableRef ||
    value isa PriceVariableRef ||
    value isa AuxiliaryVariableRef

function _normalize_observed_variables(value)
    value === nothing && return Any[]
    refs = _is_equilibrium_variable_ref(value) ? [value] : collect(value)
    all(_is_equilibrium_variable_ref, refs) || throw(ArgumentError(
        "observed_variables may contain only AgentVariableRef, " *
        "PriceVariableRef, or AuxiliaryVariableRef objects.",
    ))
    length(unique(refs)) == length(refs) || throw(ArgumentError(
        "observed_variables cannot contain duplicate references.",
    ))
    return refs
end

function _local_positions(local_indices, selected_indices)
    position = Dict(index => k for (k, index) in pairs(local_indices))
    return [position[index] for index in selected_indices]
end

function _normalize_endowment_quantities(endowment_indices, value)
    if isempty(endowment_indices)
        value === nothing && return Float64[]
        q = value isa Real ? [Float64(value)] : Float64.(collect(value))
        isempty(q) || throw(ArgumentError(
            "endowment_quantities must be empty when endowment_indices is empty.",
        ))
        return Float64[]
    end

    value === nothing && throw(ArgumentError(
        "endowment_quantities must be supplied with endowment_indices.",
    ))
    q = value isa Real ? [Float64(value)] : Float64.(collect(value))
    length(q) == length(endowment_indices) || throw(DimensionMismatch(
        "endowment_quantities length must equal endowment_indices length.",
    ))
    all(isfinite, q) || throw(ArgumentError("Endowment quantities must be finite."))
    all(x -> x >= 0, q) || throw(ArgumentError("Endowment quantities cannot be negative."))
    return q
end

function _normalize_vector(value, n, description)
    x = value isa Real ? fill(Float64(value), n) : Float64.(collect(value))
    length(x) == n || throw(DimensionMismatch(
        "$(description) length must equal the number of demand/input commodities.",
    ))
    return x
end

function _normalize_output_coefficients(output_indices, coefficients)
    if isempty(output_indices)
        coefficients === nothing && return Float64[]
        values = coefficients isa Real ?
            [Float64(coefficients)] : Float64.(collect(coefficients))
        isempty(values) || throw(ArgumentError(
            "output_coefficients must be empty when output_indices is empty.",
        ))
        return Float64[]
    end

    values = if coefficients === nothing
        ones(Float64, length(output_indices))
    elseif coefficients isa Real
        length(output_indices) == 1 || throw(DimensionMismatch(
            "Joint production requires output_coefficients to have one value per output.",
        ))
        [Float64(coefficients)]
    else
        Float64.(collect(coefficients))
    end

    length(values) == length(output_indices) || throw(DimensionMismatch(
        "output_coefficients length must equal output_indices length.",
    ))
    all(isfinite, values) || throw(ArgumentError("Output coefficients must be finite."))
    all(x -> x > 0, values) || throw(ArgumentError(
        "Output coefficients must be strictly positive.",
    ))
    return values
end

function _check_activity_arguments(
    activity_start,
    activity_lower_bound,
    activity_upper_bound,
)
    isfinite(activity_start) || throw(ArgumentError("activity_start must be finite."))
    !isnan(activity_lower_bound) && !isnan(activity_upper_bound) ||
        throw(ArgumentError("Activity bounds cannot contain NaN."))
    activity_lower_bound < activity_upper_bound ||
        throw(ArgumentError("activity_lower_bound must be below activity_upper_bound."))
    activity_lower_bound <= activity_start <= activity_upper_bound ||
        throw(ArgumentError("activity_start must lie within its bounds."))
    return nothing
end

function _check_marginal_arguments(
    marginal_function,
    demands,
    demand_start,
    demand_lower_bounds,
    demand_upper_bounds,
    multiplier_start,
    multiplier_lower_bound,
    multiplier_upper_bound,
    observed_variables,
)
    m = length(demands)
    starts = _normalize_vector(demand_start, m, "demand_start")
    lower = _normalize_vector(demand_lower_bounds, m, "demand_lower_bounds")
    upper = _normalize_vector(demand_upper_bounds, m, "demand_upper_bounds")

    all(isfinite, starts) || throw(ArgumentError("Demand starts must be finite."))
    all(x -> !isnan(x), lower) && all(x -> !isnan(x), upper) ||
        throw(ArgumentError("Demand bounds cannot contain NaN."))
    all(lower .>= 0) || throw(ArgumentError("Demand lower bounds cannot be negative."))
    all(lower .< upper) || throw(ArgumentError("Demand bounds are invalid."))
    all((lower .<= starts) .& (starts .<= upper)) ||
        throw(ArgumentError("Demand starts must lie within their bounds."))

    isfinite(multiplier_start) || throw(ArgumentError("Budget multiplier start must be finite."))
    !isnan(multiplier_lower_bound) && !isnan(multiplier_upper_bound) ||
        throw(ArgumentError("Budget multiplier bounds cannot contain NaN."))
    multiplier_lower_bound >= 0 ||
        throw(ArgumentError("Budget multiplier lower bound cannot be negative."))
    multiplier_lower_bound < multiplier_upper_bound ||
        throw(ArgumentError("Budget multiplier bounds are invalid."))
    multiplier_lower_bound <= multiplier_start <= multiplier_upper_bound ||
        throw(ArgumentError("Budget multiplier start must lie within its bounds."))

    demand0 = copy(starts)
    if applicable(marginal_function, demand0)
        mu0 = marginal_function(demand0)
        mu0 isa AbstractVector || throw(ArgumentError(
            "marginal_function must return a vector.",
        ))
        length(mu0) == m || throw(DimensionMismatch(
            "marginal_function output length must equal demand count.",
        ))
        all(x -> x isa Real && isfinite(x), mu0) || throw(ArgumentError(
            "marginal_function must return a finite real vector at demand_start.",
        ))
    else
        probe_observed = zeros(Float64, length(observed_variables))
        applicable(marginal_function, demand0, probe_observed) ||
            throw(ArgumentError(
                "marginal_function must accept (demand) or (demand, observed_values).",
            ))
    end

    return (starts=starts, lower=lower, upper=upper)
end
