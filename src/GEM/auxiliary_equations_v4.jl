# ================================================================
# auxiliary_equations_v4.jl
#
# Scalar model-level auxiliary equations for GEM V25.
#
# V3 preserves the V2 equation API but uses the V25-compatible reference
# union from EquilibriumVariableRefsV3. In particular, AgentVariableRef is
# the exact AgentVariableRef type used by current builders and agents.
# ================================================================

"""
    AuxiliaryEquationsV4

Define scalar model-level equations paired with auxiliary MCP variables and
evaluate them from explicitly declared equilibrium observations.
"""
module AuxiliaryEquationsV4

using ..EquilibriumVariableRefsV3:
    AgentVariableRef,
    PriceVariableRef,
    AuxiliaryVariableRef,
    EquilibriumVariableRef,
    is_equilibrium_variable_ref

export AuxiliaryEquation,
       auxiliary_equation_name,
       auxiliary_equation_paired_variable,
       auxiliary_equation_paired_variable_name,
       auxiliary_equation_function,
       auxiliary_equation_observed_variables,
       auxiliary_equation_observed_variable_count,
       auxiliary_equation_value

"""
    AuxiliaryEquation(name, paired_variable, equation_function;
                      observed_variables=[])

Define a scalar equilibrium equation paired with one auxiliary variable.
`equation_function` receives the values of `observed_variables` in their
declared order and must return one scalar value.
"""
struct AuxiliaryEquation{F}
    name::Symbol
    paired_variable::AuxiliaryVariableRef
    equation_function::F
    observed_variables::Vector{EquilibriumVariableRef}
end

function _check_equation_name(name::Symbol)
    isempty(String(name)) &&
        throw(ArgumentError("Auxiliary equation name cannot be empty."))
    return nothing
end

function _check_paired_variable(ref::AuxiliaryVariableRef)
    isempty(String(ref.variable_name)) &&
        throw(ArgumentError(
            "Auxiliary equation paired variable name cannot be empty.",
        ))
    return nothing
end

function _copy_and_check_observed_variables(observed_variables::AbstractVector)
    all(is_equilibrium_variable_ref, observed_variables) ||
        throw(ArgumentError(
            "Auxiliary equation observed_variables must contain only " *
            "AgentVariableRef, PriceVariableRef, or AuxiliaryVariableRef objects.",
        ))

    refs = EquilibriumVariableRef[ref for ref in observed_variables]

    length(unique(refs)) == length(refs) ||
        throw(ArgumentError(
            "Auxiliary equation observed_variables cannot contain duplicates.",
        ))

    return refs
end

function AuxiliaryEquation(
    name::Symbol,
    paired_variable::AuxiliaryVariableRef,
    equation_function;
    observed_variables::AbstractVector=EquilibriumVariableRef[],
)
    _check_equation_name(name)
    _check_paired_variable(paired_variable)
    refs = _copy_and_check_observed_variables(observed_variables)

    return AuxiliaryEquation{typeof(equation_function)}(
        name,
        paired_variable,
        equation_function,
        refs,
    )
end

function AuxiliaryEquation(
    name::Symbol,
    paired_variable::Symbol,
    equation_function;
    observed_variables::AbstractVector=EquilibriumVariableRef[],
)
    return AuxiliaryEquation(
        name,
        AuxiliaryVariableRef(paired_variable),
        equation_function;
        observed_variables=observed_variables,
    )
end

"""
    auxiliary_equation_name(equation)

Return the symbolic name of an auxiliary equation.
"""
auxiliary_equation_name(equation::AuxiliaryEquation) = equation.name

"""
    auxiliary_equation_paired_variable(equation)

Return the auxiliary-variable reference paired with an equation.
"""
auxiliary_equation_paired_variable(equation::AuxiliaryEquation) =
    equation.paired_variable

"""
    auxiliary_equation_paired_variable_name(equation)

Return the name of the auxiliary variable paired with an equation.
"""
auxiliary_equation_paired_variable_name(equation::AuxiliaryEquation) =
    equation.paired_variable.variable_name

"""
    auxiliary_equation_function(equation)

Return the function defining an auxiliary equation.
"""
auxiliary_equation_function(equation::AuxiliaryEquation) =
    equation.equation_function

"""
    auxiliary_equation_observed_variables(equation)

Return a copy of the variable references observed by an equation.
"""
auxiliary_equation_observed_variables(equation::AuxiliaryEquation) =
    copy(equation.observed_variables)

"""
    auxiliary_equation_observed_variable_count(equation)

Return the number of variables observed by an auxiliary equation.
"""
auxiliary_equation_observed_variable_count(equation::AuxiliaryEquation) =
    length(equation.observed_variables)

function _check_scalar_equation_value(value)
    if value isa AbstractArray || value isa Tuple || value isa NamedTuple
        throw(ArgumentError(
            "Auxiliary equation function must return one scalar value.",
        ))
    end
    return value
end

"""
    auxiliary_equation_value(equation, observed_values)

Evaluate `equation` from values supplied in the order of its declared
observed-variable references.
"""
function auxiliary_equation_value(
    equation::AuxiliaryEquation,
    observed_values::AbstractVector,
)
    expected = auxiliary_equation_observed_variable_count(equation)
    length(observed_values) == expected ||
        throw(DimensionMismatch(
            "Auxiliary equation observed_values length must equal " *
            "the number of observed_variables ($(expected)).",
        ))

    applicable(equation.equation_function, observed_values) ||
        throw(ArgumentError(
            "Auxiliary equation function must accept one argument: " *
            "observed_values.",
        ))

    value = equation.equation_function(observed_values)
    return _check_scalar_equation_value(value)
end

(equation::AuxiliaryEquation)(observed_values::AbstractVector) =
    auxiliary_equation_value(equation, observed_values)

end # module AuxiliaryEquationsV4
