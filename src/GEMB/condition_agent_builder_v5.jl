# ================================================================
# condition_agent_builder_v5.jl
#
# Builder for GEMB ConditionAgentSpec.
#
# V5 fixes compatibility with the current GEM NetSupplyAgent constructor:
# the obsolete `activity_structure` keyword is no longer passed.
#
# Design:
#
#   - no economic commodity demand or supply;
#   - commodity index 1 is attached internally only because GEM requires
#     a nonempty commodity-index vector;
#   - net supply for that placeholder commodity is identically zero;
#   - conditions are supplied through ExplicitAgentConditions;
#   - users see only variables, observed values, and conditions.
# ================================================================

using ..GEM:
    ExplicitAgentConditions,
    NetSupplyAgent

export build_agent


# ----------------------------------------------------------------
# 1. Variable-name normalization
# ----------------------------------------------------------------

function _normalize_condition_agent_variable_names(
    value,
)
    names =
        if value isa Symbol
            [value]
        elseif value isa AbstractVector
            collect(value)
        else
            throw(ArgumentError(
                "variable_names must be a Symbol or a vector of Symbols.",
            ))
        end

    isempty(names) && throw(ArgumentError(
        "ConditionAgentSpec requires at least one agent variable.",
    ))

    all(x -> x isa Symbol, names) || throw(ArgumentError(
        "variable_names must contain only Symbols.",
    ))

    length(unique(names)) == length(names) || throw(ArgumentError(
        "variable_names cannot contain duplicates.",
    ))

    return Symbol.(names)
end


# ----------------------------------------------------------------
# 2. Variable-vector normalization
# ----------------------------------------------------------------

function _normalize_condition_agent_vector(
    value,
    n::Integer,
    description::AbstractString;
    default,
)
    x =
        if value === nothing
            fill(Float64(default), n)
        elseif value isa Real
            fill(Float64(value), n)
        else
            Float64.(collect(value))
        end

    length(x) == n || throw(DimensionMismatch(
        "$(description) length must equal the number of condition-agent variables.",
    ))

    return x
end


function _check_condition_agent_variable_arguments(
    variable_start,
    variable_lower_bounds,
    variable_upper_bounds,
)
    all(isfinite, variable_start) || throw(ArgumentError(
        "Condition-agent variable starts must be finite.",
    ))

    all(x -> !isnan(x), variable_lower_bounds) &&
        all(x -> !isnan(x), variable_upper_bounds) ||
        throw(ArgumentError(
            "Condition-agent variable bounds cannot contain NaN.",
        ))

    all(variable_lower_bounds .< variable_upper_bounds) ||
        throw(ArgumentError(
            "Each condition-agent variable lower bound must be below its upper bound.",
        ))

    all(
        (variable_lower_bounds .<= variable_start) .&
        (variable_start .<= variable_upper_bounds),
    ) || throw(ArgumentError(
        "Condition-agent variable starts must lie within their bounds.",
    ))

    return nothing
end


# ----------------------------------------------------------------
# 3. Commodity-mapping validation
# ----------------------------------------------------------------

function _condition_agent_mapping_is_empty(
    value,
)
    value === nothing &&
        return true

    value isa AbstractVector &&
        return isempty(value)

    return false
end


function _check_condition_agent_commodity_arguments(
    output_indices,
    demand_indices,
    endowment_indices,
    output_coefficients,
    endowment_quantities,
    claim_index,
    claim_rate,
)
    for (value, description) in (
        (output_indices, "output_indices"),
        (demand_indices, "demand_indices"),
        (endowment_indices, "endowment_indices"),
    )
        _condition_agent_mapping_is_empty(value) || throw(ArgumentError(
            "ConditionAgentSpec has no economic commodity mapping; " *
            "$(description) must be empty.",
        ))
    end

    output_coefficients === nothing || throw(ArgumentError(
        "ConditionAgentSpec does not accept output_coefficients.",
    ))

    endowment_quantities === nothing || throw(ArgumentError(
        "ConditionAgentSpec does not accept endowment_quantities.",
    ))

    claim_index === nothing || throw(ArgumentError(
        "ConditionAgentSpec does not accept a claim commodity.",
    ))

    claim_rate === nothing || throw(ArgumentError(
        "ConditionAgentSpec does not accept claim_rate.",
    ))

    return nothing
end


# ----------------------------------------------------------------
# 4. Public condition-function signature validation
# ----------------------------------------------------------------

function _check_condition_agent_function_signature(
    spec::ConditionAgentSpec,
    variable_start,
    observed_variables,
)
    probe_observed =
        zeros(Float64, length(observed_variables))

    applicable(
        spec.condition_function,
        copy(variable_start),
        probe_observed,
    ) || throw(ArgumentError(
        "ConditionAgentSpec condition_function must accept " *
        "(variables, observed_values).",
    ))

    return nothing
end


# ----------------------------------------------------------------
# 5. Condition-function adapter
# ----------------------------------------------------------------

function _condition_agent_condition_rule(
    spec::ConditionAgentSpec,
)
    condition_function = function (
        local_variables,
        local_prices,
        net_supply,
        observed_values,
    )
        conditions =
            spec.condition_function(
                local_variables,
                observed_values,
            )

        conditions isa AbstractVector || throw(ArgumentError(
            "ConditionAgentSpec condition_function must return a vector.",
        ))

        length(conditions) == length(local_variables) ||
            throw(DimensionMismatch(
                "ConditionAgentSpec condition_function must return one " *
                "condition value for each agent variable.",
            ))

        return conditions
    end

    return ExplicitAgentConditions(
        condition_function,
    )
end


# ----------------------------------------------------------------
# 6. Zero-net-supply adapter
# ----------------------------------------------------------------

function _condition_agent_zero_net_supply(
    local_variables,
    local_prices,
    observed_values=Any[],
)
    # Commodity 1 is only a structural placeholder required by GEM.
    # Multiplication by zero preserves compatibility with numeric and
    # symbolic/JuMP price values while contributing no market flow.
    return [
        0 * local_prices[1],
    ]
end


# ----------------------------------------------------------------
# 7. Public builder
# ----------------------------------------------------------------

"""
    build_agent(
        spec::ConditionAgentSpec;
        variable_names,
        variable_start=nothing,
        variable_lower_bounds=nothing,
        variable_upper_bounds=nothing,
        observed_variables=Any[],
        name=:agent,
        ...
    )

Build a GEM agent whose endogenous variables are paired with the explicit
conditions in `spec` and whose economic commodity net supply is identically
zero.

The public condition function is called as

    condition_function(variables, observed_values)

and must return one condition value for each endogenous variable.

For compatibility with `GEMBModel.add_agent!`, the builder accepts
`output_indices`, `demand_indices`, and `endowment_indices`, but only when
they are empty. Claims, output coefficients, and endowment quantities are
not meaningful for a condition agent and are rejected.

Internally the resulting GEM `NetSupplyAgent` references commodity index 1
only to satisfy GEM's nonempty commodity-index requirement. Its net supply
for that placeholder commodity is always zero.

Defaults:

    variable_start        = 0
    variable_lower_bounds = -Inf
    variable_upper_bounds = Inf
"""
function build_agent(
    spec::ConditionAgentSpec;
    output_indices=Int[],
    demand_indices=Int[],
    endowment_indices=Int[],
    output_coefficients=nothing,
    endowment_quantities=nothing,
    claim_index=nothing,
    claim_rate=nothing,
    variable_names,
    variable_start=nothing,
    variable_lower_bounds=nothing,
    variable_upper_bounds=nothing,
    observed_variables=Any[],
    name::Symbol=:agent,
)
    _check_condition_agent_commodity_arguments(
        output_indices,
        demand_indices,
        endowment_indices,
        output_coefficients,
        endowment_quantities,
        claim_index,
        claim_rate,
    )

    names =
        _normalize_condition_agent_variable_names(
            variable_names,
        )

    n =
        length(names)

    start =
        _normalize_condition_agent_vector(
            variable_start,
            n,
            "variable_start";
            default=0.0,
        )

    lower =
        _normalize_condition_agent_vector(
            variable_lower_bounds,
            n,
            "variable_lower_bounds";
            default=-Inf,
        )

    upper =
        _normalize_condition_agent_vector(
            variable_upper_bounds,
            n,
            "variable_upper_bounds";
            default=Inf,
        )

    _check_condition_agent_variable_arguments(
        start,
        lower,
        upper,
    )

    observed =
        _normalize_observed_variables(
            observed_variables,
        )

    _check_condition_agent_function_signature(
        spec,
        start,
        observed,
    )

    condition_rule =
        _condition_agent_condition_rule(
            spec,
        )

    return NetSupplyAgent(
        [1],
        _condition_agent_zero_net_supply;
        variable_names=names,
        variable_lower_bounds=lower,
        variable_upper_bounds=upper,
        variable_start=start,
        observed_variables=observed,
        condition_rule=condition_rule,
        name=name,
    )
end
