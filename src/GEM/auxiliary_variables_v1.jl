# ================================================================
# auxiliary_variables_v1.jl
#
# Model-layer definition of endogenous auxiliary variables for GEM V25.
#
# This file introduces only AuxiliaryVariable. It intentionally does not
# modify NetSupplyEquilibriumModel, JuMP/PATH layouts, observed-variable
# resolution, or auxiliary equations.
#
# An AuxiliaryVariable represents one model-level endogenous variable that
# will later be paired with one auxiliary equation in the MCP.
# ================================================================

"""
    AuxiliaryVariablesV1

Define bounded, fixed, or free model-level variables that are paired with
auxiliary equilibrium equations.
"""
module AuxiliaryVariablesV1

export AuxiliaryVariable,
       auxiliary_variable_name,
       auxiliary_variable_lower_bound,
       auxiliary_variable_upper_bound,
       auxiliary_variable_start

"""
    AuxiliaryVariable(name; start=nothing, lower_bound=-Inf, upper_bound=Inf)

Define a model-level auxiliary variable with MCP bounds and a starting value.
If `start` is omitted, a finite value compatible with the bounds is selected.
"""
struct AuxiliaryVariable{T<:Real}
    name::Symbol
    lower_bound::T
    upper_bound::T
    start::T
end

function _check_auxiliary_name(name::Symbol)
    isempty(String(name)) &&
        throw(ArgumentError("Auxiliary variable name cannot be empty."))
    return nothing
end

function _check_auxiliary_bounds(lower_bound::Real, upper_bound::Real)
    isnan(lower_bound) &&
        throw(ArgumentError("Auxiliary variable lower_bound cannot be NaN."))
    isnan(upper_bound) &&
        throw(ArgumentError("Auxiliary variable upper_bound cannot be NaN."))
    lower_bound < upper_bound ||
        throw(ArgumentError(
            "Auxiliary variable lower_bound must be strictly below upper_bound.",
        ))
    return nothing
end

function _default_auxiliary_start(lower_bound::T, upper_bound::T) where {T<:Real}
    if isfinite(lower_bound) && isfinite(upper_bound)
        return lower_bound + (upper_bound - lower_bound) / T(2)
    elseif isfinite(lower_bound)
        return lower_bound + one(T)
    elseif isfinite(upper_bound)
        return upper_bound - one(T)
    end
    return zero(T)
end

function AuxiliaryVariable(
    name::Symbol;
    start::Union{Nothing,Real}=nothing,
    lower_bound::Real=-Inf,
    upper_bound::Real=Inf,
)
    _check_auxiliary_name(name)
    _check_auxiliary_bounds(lower_bound, upper_bound)

    if start === nothing
        T = promote_type(
            typeof(float(lower_bound)),
            typeof(float(upper_bound)),
        )
        lower = convert(T, lower_bound)
        upper = convert(T, upper_bound)
        start_value = _default_auxiliary_start(lower, upper)
    else
        isfinite(start) ||
            throw(ArgumentError("Auxiliary variable start must be finite."))
        T = promote_type(
            typeof(float(lower_bound)),
            typeof(float(upper_bound)),
            typeof(float(start)),
        )
        lower = convert(T, lower_bound)
        upper = convert(T, upper_bound)
        start_value = convert(T, start)
    end

    lower <= start_value <= upper ||
        throw(ArgumentError(
            "Auxiliary variable start must lie within its bounds.",
        ))

    return AuxiliaryVariable{T}(name, lower, upper, start_value)
end

"""
    auxiliary_variable_name(variable)

Return the symbolic name of an auxiliary variable.
"""
auxiliary_variable_name(variable::AuxiliaryVariable) = variable.name

"""
    auxiliary_variable_lower_bound(variable)

Return the lower MCP bound of an auxiliary variable.
"""
auxiliary_variable_lower_bound(variable::AuxiliaryVariable) = variable.lower_bound

"""
    auxiliary_variable_upper_bound(variable)

Return the upper MCP bound of an auxiliary variable.
"""
auxiliary_variable_upper_bound(variable::AuxiliaryVariable) = variable.upper_bound

"""
    auxiliary_variable_start(variable)

Return the starting value of an auxiliary variable.
"""
auxiliary_variable_start(variable::AuxiliaryVariable) = variable.start

Base.:(==)(a::AuxiliaryVariable, b::AuxiliaryVariable) =
    a.name == b.name &&
    a.lower_bound == b.lower_bound &&
    a.upper_bound == b.upper_bound &&
    a.start == b.start

Base.hash(variable::AuxiliaryVariable, h::UInt) =
    hash(
        variable.start,
        hash(
            variable.upper_bound,
            hash(variable.lower_bound, hash(variable.name, h)),
        ),
    )

end # module AuxiliaryVariablesV1
