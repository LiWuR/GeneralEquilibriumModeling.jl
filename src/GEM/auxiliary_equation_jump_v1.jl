# ================================================================
# auxiliary_equation_jump_v1.jl
#
# Unified JuMP layer for GEM auxiliary equations.
#
# This module combines the former
#
#   auxiliary_equation_jump_expressions_v4.jl
#   auxiliary_equation_mcp_constraints_v5.jl
#
# responsibilities into one coherent pipeline:
#
#   AuxiliaryEquation
#       -> direct JuMP scalar expression
#       -> pairing with the declared auxiliary variable
#       -> optional JuMP complementarity constraint.
#
# It does not build agent conditions, market-clearing conditions, or call PATH.
# ================================================================

"""
    AuxiliaryEquationJumpV1

Trace model-level auxiliary equations into JuMP expressions, evaluate the
built expressions, and pair them with auxiliary MCP variables.
"""
module AuxiliaryEquationJumpV1

import JuMP
using JuMP

using ..AuxiliaryEquationsV4:
    AuxiliaryEquation,
    auxiliary_equation_name,
    auxiliary_equation_paired_variable,
    auxiliary_equation_observed_variables,
    auxiliary_equation_value

using ..EquilibriumNetSupplyModelV11:
    NetSupplyEquilibriumModel

using ..EquilibriumJumpModelV2:
    EquilibriumJumpLayout,
    EquilibriumJumpVariables,
    resolve_equilibrium_variable_ref,
    is_endogenous_resolution,
    equilibrium_jump_reference,
    equilibrium_jump_references

export AuxiliaryEquationJumpExpressions,
       AuxiliaryEquationMCPConstraints,
       build_auxiliary_equation_jump_expression,
       build_auxiliary_equation_jump_expressions,
       auxiliary_jump_expression_value,
       auxiliary_jump_expression_values,
       add_auxiliary_equation_mcp_constraints!


# ----------------------------------------------------------------
# 1. Direct JuMP-expression representation
# ----------------------------------------------------------------

"""
    AuxiliaryEquationJumpExpressions

Direct JuMP-expression representation of all model auxiliary equations and
their paired variables.
"""
struct AuxiliaryEquationJumpExpressions
    equation_names::Vector{Symbol}
    expressions::Vector{Any}
    observed_values::Vector{Vector{Any}}
    paired_variables::Vector{JuMP.VariableRef}
    paired_variable_positions::Vector{Int}
end

function _validate_jump_scalar(value, equation_name::Symbol)
    if value isa Bool
        throw(ArgumentError(
            "Auxiliary equation $(equation_name) must return a numeric or " *
            "JuMP scalar expression, not Bool.",
        ))
    end

    if value isa Real
        isfinite(value) || throw(ArgumentError(
            "Auxiliary equation $(equation_name) returned a nonfinite " *
            "constant value.",
        ))
        return value
    end

    value isa JuMP.AbstractJuMPScalar || throw(ArgumentError(
        "Auxiliary equation $(equation_name) must return one real scalar " *
        "or JuMP.AbstractJuMPScalar; got $(typeof(value)).",
    ))

    return value
end

"""
    build_auxiliary_equation_jump_expression(equation, jump_variables, layout)

Construct one auxiliary-equation JuMP expression by direct function tracing.

The equation function receives its declared observed variables in exactly the
order stored in `equation.observed_variables`. A numeraire PriceVariableRef is
resolved to the fixed numeraire value; all other supported references resolve
to JuMP variables.
"""
function build_auxiliary_equation_jump_expression(
    equation::AuxiliaryEquation,
    jump_variables::EquilibriumJumpVariables,
    layout::EquilibriumJumpLayout,
)
    refs = auxiliary_equation_observed_variables(equation)
    observed_values = equilibrium_jump_references(
        jump_variables,
        layout,
        refs,
    )

    expression = try
        auxiliary_equation_value(equation, observed_values)
    catch err
        throw(ArgumentError(
            "Auxiliary equation $(auxiliary_equation_name(equation)) cannot " *
            "construct a direct JuMP expression. Ensure that its " *
            "equation_function accepts JuMP variables and fixed numeric " *
            "values for all declared observed variables. Original error: " *
            sprint(showerror, err),
        ))
    end

    return (
        expression=_validate_jump_scalar(
            expression,
            auxiliary_equation_name(equation),
        ),
        observed_values=observed_values,
    )
end

"""
    build_auxiliary_equation_jump_expressions(model, jump_variables, layout)

Construct direct JuMP expressions for all auxiliary equations in model order.
"""
function build_auxiliary_equation_jump_expressions(
    model::NetSupplyEquilibriumModel,
    jump_variables::EquilibriumJumpVariables,
    layout::EquilibriumJumpLayout,
)
    length(model.auxiliary_equations) == layout.number_of_auxiliary_variables ||
        throw(ArgumentError(
            "The supplied layout is incompatible with the model's auxiliary equations.",
        ))

    equation_names = Symbol[]
    expressions = Any[]
    observed_values = Vector{Vector{Any}}()
    paired_variables = JuMP.VariableRef[]
    paired_positions = Int[]

    for equation in model.auxiliary_equations
        built = build_auxiliary_equation_jump_expression(
            equation,
            jump_variables,
            layout,
        )

        paired_ref = auxiliary_equation_paired_variable(equation)
        resolution = resolve_equilibrium_variable_ref(layout, paired_ref)
        is_endogenous_resolution(resolution) || error(
            "Internal error: an auxiliary equation paired variable must be endogenous.",
        )

        paired_variable = equilibrium_jump_reference(
            jump_variables,
            layout,
            paired_ref,
        )
        paired_variable isa JuMP.VariableRef || error(
            "Internal error: an auxiliary equation paired variable did not " *
            "resolve to a JuMP.VariableRef.",
        )

        push!(equation_names, auxiliary_equation_name(equation))
        push!(expressions, built.expression)
        push!(observed_values, built.observed_values)
        push!(paired_variables, paired_variable)
        push!(paired_positions, resolution.position)
    end

    length(expressions) == length(model.auxiliary_equations) || error(
        "Internal error: auxiliary-equation expression count is inconsistent.",
    )

    return AuxiliaryEquationJumpExpressions(
        equation_names,
        expressions,
        observed_values,
        paired_variables,
        paired_positions,
    )
end


# ----------------------------------------------------------------
# 2. Evaluation of already-built auxiliary expressions
# ----------------------------------------------------------------

function _point_lookup(
    jump_variables::EquilibriumJumpVariables,
    point::AbstractVector,
)
    length(point) == length(jump_variables.variables) || throw(DimensionMismatch(
        "point length must equal the number of endogenous JuMP variables.",
    ))
    all(x -> x isa Real && isfinite(x), point) || throw(ArgumentError(
        "point must contain only finite real values.",
    ))

    return Dict{JuMP.VariableRef,Float64}(
        variable => Float64(point[i])
        for (i, variable) in pairs(jump_variables.variables)
    )
end

"""
    auxiliary_jump_expression_value(expression, jump_variables, point)

Evaluate one already-built JuMP scalar expression at an arbitrary point.
"""
function auxiliary_jump_expression_value(
    expression,
    jump_variables::EquilibriumJumpVariables,
    point::AbstractVector,
)
    lookup = _point_lookup(jump_variables, point)

    if expression isa Real
        isfinite(expression) || throw(ArgumentError(
            "Cannot evaluate a nonfinite constant auxiliary expression.",
        ))
        return Float64(expression)
    end

    expression isa JuMP.AbstractJuMPScalar || throw(ArgumentError(
        "expression must be a real scalar or JuMP.AbstractJuMPScalar.",
    ))

    value = JuMP.value(variable -> lookup[variable], expression)
    value isa Real && isfinite(value) || throw(ArgumentError(
        "Auxiliary JuMP expression evaluated to a nonfinite or nonreal value.",
    ))
    return Float64(value)
end

"""
    auxiliary_jump_expression_values(built, jump_variables, point)

Evaluate all already-built auxiliary-equation expressions at one point.
"""
function auxiliary_jump_expression_values(
    built::AuxiliaryEquationJumpExpressions,
    jump_variables::EquilibriumJumpVariables,
    point::AbstractVector,
)
    return Float64[
        auxiliary_jump_expression_value(expression, jump_variables, point)
        for expression in built.expressions
    ]
end


# ----------------------------------------------------------------
# 3. MCP complementarity binding
# ----------------------------------------------------------------

"""
    AuxiliaryEquationMCPConstraints

Container for JuMP complementarity constraints created from auxiliary
equations and their paired variables.
"""
struct AuxiliaryEquationMCPConstraints
    equation_names::Vector{Symbol}
    constraints::Vector{Any}
    expressions::Vector{Any}
    paired_variables::Vector{JuMP.VariableRef}
    paired_variable_positions::Vector{Int}
end

function _validate_auxiliary_jump_expressions(
    built::AuxiliaryEquationJumpExpressions,
)
    n = length(built.equation_names)

    length(built.expressions) == n || error(
        "Internal error: auxiliary expression count is inconsistent.",
    )
    length(built.observed_values) == n || error(
        "Internal error: auxiliary observed-value count is inconsistent.",
    )
    length(built.paired_variables) == n || error(
        "Internal error: auxiliary paired-variable count is inconsistent.",
    )
    length(built.paired_variable_positions) == n || error(
        "Internal error: auxiliary paired-variable position count is inconsistent.",
    )

    all(position -> position > 0, built.paired_variable_positions) || error(
        "Internal error: every auxiliary equation must be paired with an endogenous variable.",
    )
    length(unique(built.paired_variable_positions)) == n || error(
        "Internal error: auxiliary equations cannot share a paired variable position.",
    )

    return n
end

"""
    add_auxiliary_equation_mcp_constraints!(jump_model, built)

Add one JuMP complementarity constraint for each auxiliary equation.

For equation `g_k` paired with auxiliary variable `a_k`, this adds

    g_k(x) complements a_k

using the bounds already attached to `a_k`. Therefore a free auxiliary
variable forces `g_k(x) = 0`, while a bounded auxiliary variable follows the
usual MCP lower-bound/interior/upper-bound sign conditions.
"""
function add_auxiliary_equation_mcp_constraints!(
    jump_model,
    built::AuxiliaryEquationJumpExpressions,
)
    n = _validate_auxiliary_jump_expressions(built)
    constraints = Any[]

    for k in 1:n
        expression = built.expressions[k]
        variable = built.paired_variables[k]

        push!(
            constraints,
            @constraint(
                jump_model,
                expression ⟂ variable,
            ),
        )
    end

    return AuxiliaryEquationMCPConstraints(
        copy(built.equation_names),
        constraints,
        copy(built.expressions),
        copy(built.paired_variables),
        copy(built.paired_variable_positions),
    )
end

end # module AuxiliaryEquationJumpV1
