# ================================================================
# equilibrium_jump_model_v2.jl
#
# Unified GEM JuMP equilibrium-variable layer.
#
# V2 keeps the unified layout introduced in V1 and adds a model-level
# EquilibriumVariableData layer between layout resolution and JuMP variable
# creation. The three responsibilities are now explicit:
#
#   1. EquilibriumJumpLayout
#      global endogenous-variable order and reference resolution;
#
#   2. EquilibriumVariableData
#      canonical global names, lower bounds, upper bounds, and starts;
#
#   3. EquilibriumJumpVariables
#      JuMP.VariableRef objects created from EquilibriumVariableData.
#
# The global endogenous-variable order is
#
#   [agent variables;
#    nonnumeraire prices;
#    auxiliary variables].
#
# The numeraire price is not an endogenous JuMP variable. A
# PriceVariableRef to the numeraire resolves to its fixed numeric value.
# ================================================================

"""
    EquilibriumJumpModelV2

Define the canonical global variable layout, numeric bounds and starts, and
JuMP variable references used to assemble a GEM complementarity model.
"""
module EquilibriumJumpModelV2

import JuMP

using ..EquilibriumAgentCoreV1:
    AgentVariableRef

using ..EquilibriumVariableRefsV3:
    PriceVariableRef,
    AuxiliaryVariableRef,
    EquilibriumVariableRef,
    is_equilibrium_variable_ref

using ..EquilibriumNetSupplyModelV11:
    NetSupplyEquilibriumModel

export EquilibriumJumpLayout,
       EquilibriumVariableResolution,
       EquilibriumVariableData,
       EquilibriumJumpVariables,
       resolve_equilibrium_variable_ref,
       resolve_equilibrium_variable_refs,
       equilibrium_variable_position,
       equilibrium_reference_value,
       is_endogenous_resolution,
       is_fixed_resolution,
       build_equilibrium_variable_data,
       build_equilibrium_jump_variables!,
       equilibrium_jump_reference,
       equilibrium_jump_references,
       effective_price_bounds,
       effective_price_start


# ----------------------------------------------------------------
# 1. Global equilibrium-variable layout
# ----------------------------------------------------------------

"""
    EquilibriumVariableResolution

Resolution of one equilibrium-variable reference.

An endogenous reference has `position > 0` and `fixed_value === nothing`.
A fixed reference, currently the numeraire price, has `position == 0` and a
finite `fixed_value`.
"""
struct EquilibriumVariableResolution{T<:Real}
    position::Int
    fixed_value::Union{Nothing,T}

    function EquilibriumVariableResolution{T}(
        position::Integer,
        fixed_value::Union{Nothing,T},
    ) where {T<:Real}
        p = Int(position)
        p >= 0 || throw(ArgumentError(
            "Equilibrium-variable resolution position cannot be negative.",
        ))

        if p == 0
            fixed_value === nothing && throw(ArgumentError(
                "A fixed equilibrium-variable resolution requires fixed_value.",
            ))
            isfinite(fixed_value) || throw(ArgumentError(
                "A fixed equilibrium-variable value must be finite.",
            ))
        else
            fixed_value === nothing || throw(ArgumentError(
                "An endogenous equilibrium-variable resolution cannot also " *
                "contain a fixed value.",
            ))
        end

        return new{T}(p, fixed_value)
    end
end

function _endogenous_resolution(position::Integer)
    return EquilibriumVariableResolution{Float64}(Int(position), nothing)
end

function _fixed_resolution(value::Real)
    return EquilibriumVariableResolution{Float64}(0, Float64(value))
end

"""
    is_endogenous_resolution(resolution)

Return `true` if a resolution refers to an endogenous variable.
"""
is_endogenous_resolution(resolution::EquilibriumVariableResolution) =
    resolution.position > 0

"""
    is_fixed_resolution(resolution)

Return `true` if a resolution refers to a fixed numeric value.
"""
is_fixed_resolution(resolution::EquilibriumVariableResolution) =
    resolution.position == 0


"""
    EquilibriumJumpLayout(model)

Global ordering and lookup tables for all endogenous GEM variables. Variables
are ordered as agent variables, nonnumeraire prices, and auxiliary variables.
"""
struct EquilibriumJumpLayout{T<:Real}
    number_of_agent_variables::Int
    agent_variable_ranges::Vector{UnitRange{Int}}
    agent_variable_position::Dict{Tuple{Symbol,Symbol},Int}

    nonnumeraire_indices::Vector{Int}
    number_of_price_variables::Int
    price_variable_position::Vector{Int}
    commodity_index::Dict{Symbol,Int}
    numeraire_index::Int
    numeraire_value::T

    number_of_auxiliary_variables::Int
    auxiliary_variable_range::UnitRange{Int}
    auxiliary_variable_position::Dict{Symbol,Int}

    number_of_variables::Int
    variable_names::Vector{Symbol}
end

function EquilibriumJumpLayout(model::NetSupplyEquilibriumModel)
    number_of_agent_variables = sum(length(agent.variable_names) for agent in model.agents)

    agent_ranges = Vector{UnitRange{Int}}(undef, length(model.agents))
    agent_positions = Dict{Tuple{Symbol,Symbol},Int}()
    variable_names = Symbol[]

    next_position = 1
    for (i, agent) in pairs(model.agents)
        nv = length(agent.variable_names)
        first_position = next_position
        last_position = next_position + nv - 1
        agent_ranges[i] = first_position:last_position

        for (k, variable_name) in pairs(agent.variable_names)
            position = first_position + k - 1
            key = (agent.name, variable_name)
            haskey(agent_positions, key) && error(
                "Internal error: duplicate agent-variable layout key $(key).",
            )
            agent_positions[key] = position
            push!(variable_names, Symbol(agent.name, :__, variable_name))
        end

        next_position += nv
    end

    next_position == number_of_agent_variables + 1 || error(
        "Internal error: agent-variable layout size is inconsistent.",
    )

    ncommodities = length(model.commodity_names)
    nonnumeraire_indices = Int[
        i for i in 1:ncommodities if i != model.numeraire_index
    ]
    number_of_price_variables = length(nonnumeraire_indices)
    price_positions = zeros(Int, ncommodities)

    for commodity in nonnumeraire_indices
        price_positions[commodity] = next_position
        push!(variable_names, Symbol(:price__, model.commodity_names[commodity]))
        next_position += 1
    end

    number_of_auxiliary_variables = length(model.auxiliary_variables)
    auxiliary_first = next_position
    auxiliary_last = next_position + number_of_auxiliary_variables - 1
    auxiliary_range = auxiliary_first:auxiliary_last
    auxiliary_positions = Dict{Symbol,Int}()

    for auxiliary in model.auxiliary_variables
        position = next_position
        haskey(auxiliary_positions, auxiliary.name) && error(
            "Internal error: duplicate auxiliary-variable layout key $(auxiliary.name).",
        )
        auxiliary_positions[auxiliary.name] = position
        push!(variable_names, Symbol(:auxiliary__, auxiliary.name))
        next_position += 1
    end

    number_of_variables =
        number_of_agent_variables +
        number_of_price_variables +
        number_of_auxiliary_variables

    next_position == number_of_variables + 1 || error(
        "Internal error: global equilibrium-variable layout size is inconsistent.",
    )
    length(variable_names) == number_of_variables || error(
        "Internal error: global variable-name count does not match layout size.",
    )

    return EquilibriumJumpLayout(
        number_of_agent_variables,
        agent_ranges,
        agent_positions,
        nonnumeraire_indices,
        number_of_price_variables,
        price_positions,
        copy(model.commodity_index),
        model.numeraire_index,
        model.numeraire_value,
        number_of_auxiliary_variables,
        auxiliary_range,
        auxiliary_positions,
        number_of_variables,
        variable_names,
    )
end


# ----------------------------------------------------------------
# 2. Model-level reference resolution
# ----------------------------------------------------------------

"""
    resolve_equilibrium_variable_ref(layout, ref)

Resolve an agent-variable, price, or auxiliary-variable reference to an
endogenous position or a fixed numeraire value.
"""
function resolve_equilibrium_variable_ref(
    layout::EquilibriumJumpLayout,
    ref::AgentVariableRef,
)
    key = (ref.agent_name, ref.variable_name)
    position = get(layout.agent_variable_position, key, 0)
    position > 0 || throw(ArgumentError(
        "Unresolved agent variable reference " *
        "$(ref.agent_name).$(ref.variable_name).",
    ))
    return _endogenous_resolution(position)
end

function resolve_equilibrium_variable_ref(
    layout::EquilibriumJumpLayout,
    ref::PriceVariableRef,
)
    commodity = get(layout.commodity_index, ref.commodity_name, 0)
    commodity > 0 || throw(ArgumentError(
        "Unresolved commodity price reference $(ref.commodity_name).",
    ))

    if commodity == layout.numeraire_index
        return _fixed_resolution(layout.numeraire_value)
    end

    position = layout.price_variable_position[commodity]
    position > 0 || error(
        "Internal error: nonnumeraire price has no global variable position.",
    )
    return _endogenous_resolution(position)
end

function resolve_equilibrium_variable_ref(
    layout::EquilibriumJumpLayout,
    ref::AuxiliaryVariableRef,
)
    position = get(layout.auxiliary_variable_position, ref.variable_name, 0)
    position > 0 || throw(ArgumentError(
        "Unresolved auxiliary variable reference $(ref.variable_name).",
    ))
    return _endogenous_resolution(position)
end

function resolve_equilibrium_variable_ref(
    layout::EquilibriumJumpLayout,
    ref::EquilibriumVariableRef,
)
    throw(ArgumentError(
        "Unsupported equilibrium-variable reference type $(typeof(ref)).",
    ))
end

"""
    resolve_equilibrium_variable_refs(layout, refs)

Resolve a vector of equilibrium-variable references in its declared order.
"""
function resolve_equilibrium_variable_refs(
    layout::EquilibriumJumpLayout,
    refs::AbstractVector,
)
    all(is_equilibrium_variable_ref, refs) || throw(ArgumentError(
        "refs may contain only AgentVariableRef, PriceVariableRef, or " *
        "AuxiliaryVariableRef objects.",
    ))

    return EquilibriumVariableResolution[
        resolve_equilibrium_variable_ref(layout, ref)
        for ref in refs
    ]
end

"""
    equilibrium_variable_position(layout, ref)

Return the global endogenous-variable position for a reference.

The numeraire price is fixed rather than endogenous, so its position is 0.
"""
function equilibrium_variable_position(
    layout::EquilibriumJumpLayout,
    ref::EquilibriumVariableRef,
)
    return resolve_equilibrium_variable_ref(layout, ref).position
end

"""
    equilibrium_reference_value(layout, ref, global_values)

Resolve one reference to a numeric value at a complete endogenous point.
"""
function equilibrium_reference_value(
    layout::EquilibriumJumpLayout,
    ref::EquilibriumVariableRef,
    global_values::AbstractVector,
)
    length(global_values) == layout.number_of_variables || throw(DimensionMismatch(
        "global_values length must equal layout.number_of_variables " *
        "($(layout.number_of_variables)).",
    ))

    resolution = resolve_equilibrium_variable_ref(layout, ref)
    if is_endogenous_resolution(resolution)
        return global_values[resolution.position]
    end
    return resolution.fixed_value
end


# ----------------------------------------------------------------
# 3. Canonical global variable data
# ----------------------------------------------------------------

"""
    EquilibriumVariableData(names, lower_bounds, upper_bounds, start_values)

Canonical numeric data for all endogenous equilibrium variables.

The vectors are ordered exactly as `EquilibriumJumpLayout.variable_names`:

    [agent variables; nonnumeraire prices; auxiliary variables].

This type deliberately contains no JuMP objects. It is therefore reusable by
solver front ends that need only names, bounds, and starting values.
"""
struct EquilibriumVariableData
    names::Vector{Symbol}
    lower_bounds::Vector{Float64}
    upper_bounds::Vector{Float64}
    start_values::Vector{Float64}

    function EquilibriumVariableData(
        names::AbstractVector{Symbol},
        lower_bounds::AbstractVector{<:Real},
        upper_bounds::AbstractVector{<:Real},
        start_values::AbstractVector{<:Real},
    )
        n = length(names)
        length(lower_bounds) == n || throw(DimensionMismatch(
            "lower_bounds length must equal names length.",
        ))
        length(upper_bounds) == n || throw(DimensionMismatch(
            "upper_bounds length must equal names length.",
        ))
        length(start_values) == n || throw(DimensionMismatch(
            "start_values length must equal names length.",
        ))

        lower = Float64.(lower_bounds)
        upper = Float64.(upper_bounds)
        starts = Float64.(start_values)

        all(x -> !isnan(x), lower) && all(x -> !isnan(x), upper) ||
            throw(ArgumentError(
                "Equilibrium-variable bounds cannot contain NaN.",
            ))
        all(lower .< upper) || throw(ArgumentError(
            "Each equilibrium-variable lower bound must be strictly below its upper bound.",
        ))
        all(isfinite, starts) || throw(ArgumentError(
            "Equilibrium-variable start values must be finite.",
        ))
        all((lower .<= starts) .& (starts .<= upper)) || throw(ArgumentError(
            "Equilibrium-variable start values must lie within their bounds.",
        ))

        return new(
            Symbol.(collect(names)),
            lower,
            upper,
            starts,
        )
    end
end


# ----------------------------------------------------------------
# 4. Agent-variable starts and bounds
# ----------------------------------------------------------------

function _flatten_agent_defaults(model::NetSupplyEquilibriumModel)
    starts = Float64[]
    lower = Float64[]
    upper = Float64[]

    for agent in model.agents
        append!(starts, Float64.(agent.variable_start))
        append!(lower, Float64.(agent.variable_lower_bounds))
        append!(upper, Float64.(agent.variable_upper_bounds))
    end

    return (starts=starts, lower=lower, upper=upper)
end

function _resolve_agent_start(
    model::NetSupplyEquilibriumModel,
    layout::EquilibriumJumpLayout,
    v0,
)
    defaults = _flatten_agent_defaults(model)

    length(defaults.starts) == layout.number_of_agent_variables || error(
        "Internal error: agent start-value count is incompatible with layout.",
    )
    length(defaults.lower) == layout.number_of_agent_variables || error(
        "Internal error: agent lower-bound count is incompatible with layout.",
    )
    length(defaults.upper) == layout.number_of_agent_variables || error(
        "Internal error: agent upper-bound count is incompatible with layout.",
    )

    starts = if v0 === nothing
        defaults.starts
    else
        values = Float64.(collect(v0))
        length(values) == layout.number_of_agent_variables || throw(DimensionMismatch(
            "v0 length must equal the number of endogenous agent variables.",
        ))
        values
    end

    all(isfinite, starts) || throw(ArgumentError(
        "Agent-variable start values must be finite.",
    ))
    all((defaults.lower .<= starts) .& (starts .<= defaults.upper)) ||
        throw(ArgumentError(
            "Agent-variable start values must lie within their bounds.",
        ))

    return (
        starts=starts,
        lower=defaults.lower,
        upper=defaults.upper,
    )
end


# ----------------------------------------------------------------
# 5. Price starts and bounds
# ----------------------------------------------------------------

function _normalize_price_override(value, n::Int, description::String)
    if value isa Real
        return fill(Float64(value), n)
    end

    values = Float64.(collect(value))
    length(values) == n || throw(DimensionMismatch(
        "$(description) length must equal the number of commodities.",
    ))
    return values
end

"""
    effective_price_bounds(model; price_floor=nothing,
                           price_upper_bound=nothing)

Return validated effective lower and upper bounds for all commodity prices.
Optional overrides replace the corresponding bounds stored in `model`.
"""
function effective_price_bounds(
    model::NetSupplyEquilibriumModel;
    price_floor=nothing,
    price_upper_bound=nothing,
)
    n = length(model.commodity_names)
    lower = Float64.(model.price_lower_bounds)
    upper = Float64.(model.price_upper_bounds)

    length(lower) == n || error(
        "Internal error: model price lower-bound count is inconsistent.",
    )
    length(upper) == n || error(
        "Internal error: model price upper-bound count is inconsistent.",
    )

    if price_floor !== nothing
        lower = _normalize_price_override(
            price_floor,
            n,
            "price_floor",
        )
    end

    if price_upper_bound !== nothing
        upper = _normalize_price_override(
            price_upper_bound,
            n,
            "price_upper_bound",
        )
    end

    all(x -> !isnan(x), lower) && all(x -> !isnan(x), upper) ||
        throw(ArgumentError("Price bounds cannot contain NaN."))
    all(lower .< upper) || throw(ArgumentError(
        "Each effective price lower bound must be strictly below its upper bound.",
    ))

    numeraire = model.numeraire_index
    value = Float64(model.numeraire_value)
    lower[numeraire] <= value <= upper[numeraire] || throw(ArgumentError(
        "The fixed numeraire value must lie within its effective price bounds.",
    ))

    return (lower=lower, upper=upper)
end

function _default_price_start(
    model::NetSupplyEquilibriumModel,
    lower,
    upper,
)
    n = length(model.commodity_names)
    starts = Vector{Float64}(undef, n)

    for i in 1:n
        if i == model.numeraire_index
            starts[i] = Float64(model.numeraire_value)
        elseif lower[i] <= 1.0 <= upper[i]
            starts[i] = 1.0
        elseif isfinite(lower[i]) && isfinite(upper[i])
            starts[i] = lower[i] + (upper[i] - lower[i]) / 2
        elseif isfinite(lower[i])
            starts[i] = lower[i] + 1.0
        elseif isfinite(upper[i])
            starts[i] = upper[i] - 1.0
        else
            starts[i] = 0.0
        end
    end

    return starts
end

"""
    effective_price_start(model, lower, upper; p0=nothing)

Return a validated start vector for all commodity prices, including the fixed
numeraire value.
"""
function effective_price_start(
    model::NetSupplyEquilibriumModel,
    lower::AbstractVector,
    upper::AbstractVector;
    p0=nothing,
)
    n = length(model.commodity_names)
    length(lower) == n || throw(DimensionMismatch(
        "lower length must equal the number of commodities.",
    ))
    length(upper) == n || throw(DimensionMismatch(
        "upper length must equal the number of commodities.",
    ))

    starts = if p0 === nothing
        _default_price_start(model, lower, upper)
    else
        values = Float64.(collect(p0))
        length(values) == n || throw(DimensionMismatch(
            "p0 length must equal the number of commodities.",
        ))
        values
    end

    all(isfinite, starts) || throw(ArgumentError(
        "Price start values must all be finite.",
    ))
    all((lower .<= starts) .& (starts .<= upper)) || throw(ArgumentError(
        "Price start values must lie within their effective bounds.",
    ))

    numeraire = model.numeraire_index
    isapprox(
        starts[numeraire],
        Float64(model.numeraire_value);
        rtol=0.0,
        atol=0.0,
    ) || throw(ArgumentError(
        "p0 at the numeraire index must equal the fixed numeraire value.",
    ))

    return starts
end


# ----------------------------------------------------------------
# 6. Auxiliary-variable starts and bounds
# ----------------------------------------------------------------

function _resolve_auxiliary_start(
    model::NetSupplyEquilibriumModel,
    layout::EquilibriumJumpLayout,
    auxiliary0,
)
    starts = Float64[
        Float64(variable.start)
        for variable in model.auxiliary_variables
    ]
    lower = Float64[
        Float64(variable.lower_bound)
        for variable in model.auxiliary_variables
    ]
    upper = Float64[
        Float64(variable.upper_bound)
        for variable in model.auxiliary_variables
    ]

    length(starts) == layout.number_of_auxiliary_variables || error(
        "Internal error: auxiliary start-value count is incompatible with layout.",
    )
    length(lower) == layout.number_of_auxiliary_variables || error(
        "Internal error: auxiliary lower-bound count is incompatible with layout.",
    )
    length(upper) == layout.number_of_auxiliary_variables || error(
        "Internal error: auxiliary upper-bound count is incompatible with layout.",
    )

    if auxiliary0 !== nothing
        starts = Float64.(collect(auxiliary0))
        length(starts) == layout.number_of_auxiliary_variables ||
            throw(DimensionMismatch(
                "auxiliary0 length must equal the number of auxiliary variables.",
            ))
    end

    all(isfinite, starts) || throw(ArgumentError(
        "Auxiliary-variable start values must be finite.",
    ))
    all((lower .<= starts) .& (starts .<= upper)) || throw(ArgumentError(
        "Auxiliary-variable start values must lie within their bounds.",
    ))

    return (starts=starts, lower=lower, upper=upper)
end


# ----------------------------------------------------------------
# 7. Global variable-data assembly
# ----------------------------------------------------------------

function _check_layout_model_compatibility(
    model::NetSupplyEquilibriumModel,
    layout::EquilibriumJumpLayout,
)
    layout.number_of_agent_variables ==
        sum(length(agent.variable_names) for agent in model.agents) ||
        throw(ArgumentError(
            "The supplied layout is incompatible with model agent variables.",
        ))

    layout.number_of_price_variables == length(model.commodity_names) - 1 ||
        throw(ArgumentError(
            "The supplied layout is incompatible with model commodity prices.",
        ))

    layout.number_of_auxiliary_variables == length(model.auxiliary_variables) ||
        throw(ArgumentError(
            "The supplied layout is incompatible with model auxiliary variables.",
        ))

    layout.number_of_variables ==
        layout.number_of_agent_variables +
        layout.number_of_price_variables +
        layout.number_of_auxiliary_variables ||
        throw(ArgumentError(
            "The supplied layout has an inconsistent total variable count.",
        ))

    layout.numeraire_index == model.numeraire_index || throw(ArgumentError(
        "The supplied layout uses a different numeraire index than the model.",
    ))
    layout.numeraire_value == model.numeraire_value || throw(ArgumentError(
        "The supplied layout uses a different numeraire value than the model.",
    ))

    return nothing
end


"""
    build_equilibrium_variable_data(model[, layout]; kwargs...)

Build canonical names, bounds, and starting values for all endogenous
variables in `layout` order.
"""
function build_equilibrium_variable_data(
    model::NetSupplyEquilibriumModel,
    layout::EquilibriumJumpLayout=EquilibriumJumpLayout(model);
    v0=nothing,
    p0=nothing,
    auxiliary0=nothing,
    price_floor=nothing,
    price_upper_bound=nothing,
)
    _check_layout_model_compatibility(model, layout)

    agent_data = _resolve_agent_start(model, layout, v0)
    price_bounds = effective_price_bounds(
        model;
        price_floor=price_floor,
        price_upper_bound=price_upper_bound,
    )
    price_starts = effective_price_start(
        model,
        price_bounds.lower,
        price_bounds.upper;
        p0=p0,
    )
    auxiliary_data = _resolve_auxiliary_start(model, layout, auxiliary0)

    n = layout.number_of_variables
    lower_bounds = Vector{Float64}(undef, n)
    upper_bounds = Vector{Float64}(undef, n)
    start_values = Vector{Float64}(undef, n)

    # Agent variables occupy the first block in canonical order.
    for position in 1:layout.number_of_agent_variables
        lower_bounds[position] = agent_data.lower[position]
        upper_bounds[position] = agent_data.upper[position]
        start_values[position] = agent_data.starts[position]
    end

    # Nonnumeraire prices are inserted at their global layout positions.
    for commodity in layout.nonnumeraire_indices
        position = layout.price_variable_position[commodity]
        position > 0 || error(
            "Internal error: nonnumeraire price has no global variable position.",
        )
        lower_bounds[position] = price_bounds.lower[commodity]
        upper_bounds[position] = price_bounds.upper[commodity]
        start_values[position] = price_starts[commodity]
    end

    # Auxiliary variables occupy the final block in canonical order.
    for (k, position) in pairs(collect(layout.auxiliary_variable_range))
        lower_bounds[position] = auxiliary_data.lower[k]
        upper_bounds[position] = auxiliary_data.upper[k]
        start_values[position] = auxiliary_data.starts[k]
    end

    return EquilibriumVariableData(
        copy(layout.variable_names),
        lower_bounds,
        upper_bounds,
        start_values,
    )
end


# ----------------------------------------------------------------
# 8. JuMP variable container and construction
# ----------------------------------------------------------------

"""
    EquilibriumJumpVariables

Container for the JuMP variables and fixed price references corresponding to
one `EquilibriumJumpLayout`.
"""
struct EquilibriumJumpVariables
    agent_variables::Vector{JuMP.VariableRef}
    price_variables::Vector{JuMP.VariableRef}
    auxiliary_variables::Vector{JuMP.VariableRef}
    variables::Vector{JuMP.VariableRef}
    prices::Vector{Any}
    lower_bounds::Vector{Float64}
    upper_bounds::Vector{Float64}
    start_values::Vector{Float64}
end

function _make_variable!(
    jump_model,
    name::Symbol,
    lower_bound::Real,
    upper_bound::Real,
    start::Real,
)
    lb = Float64(lower_bound)
    ub = Float64(upper_bound)
    x0 = Float64(start)

    !isnan(lb) && !isnan(ub) || throw(ArgumentError(
        "JuMP variable bounds cannot contain NaN.",
    ))
    lb < ub || throw(ArgumentError(
        "JuMP variable lower bound must be strictly below its upper bound.",
    ))
    isfinite(x0) || throw(ArgumentError(
        "JuMP variable start value must be finite.",
    ))
    lb <= x0 <= ub || throw(ArgumentError(
        "JuMP variable start value must lie within its bounds.",
    ))

    variable = JuMP.@variable(jump_model, base_name=String(name))
    isfinite(lb) && JuMP.set_lower_bound(variable, lb)
    isfinite(ub) && JuMP.set_upper_bound(variable, ub)
    JuMP.set_start_value(variable, x0)
    return variable
end

function _variable_block(
    variables::Vector{JuMP.VariableRef},
    first_position::Int,
    count::Int,
)
    count >= 0 || error("Internal error: JuMP variable block count cannot be negative.")
    count == 0 && return JuMP.VariableRef[]

    last_position = first_position + count - 1
    1 <= first_position <= last_position <= length(variables) || error(
        "Internal error: JuMP variable block lies outside the global variable vector.",
    )
    return variables[first_position:last_position]
end

"""
    build_equilibrium_jump_variables!(jump_model, model[, layout]; kwargs...)

Create all endogenous JuMP variables from canonical `EquilibriumVariableData`
and return their structured references.
"""
function build_equilibrium_jump_variables!(
    jump_model,
    model::NetSupplyEquilibriumModel,
    layout::EquilibriumJumpLayout=EquilibriumJumpLayout(model);
    v0=nothing,
    p0=nothing,
    auxiliary0=nothing,
    price_floor=nothing,
    price_upper_bound=nothing,
)
    data = build_equilibrium_variable_data(
        model,
        layout;
        v0=v0,
        p0=p0,
        auxiliary0=auxiliary0,
        price_floor=price_floor,
        price_upper_bound=price_upper_bound,
    )

    length(data.names) == layout.number_of_variables || error(
        "Internal error: global variable-data count does not match layout size.",
    )

    variables = JuMP.VariableRef[]
    sizehint!(variables, layout.number_of_variables)
    for position in 1:layout.number_of_variables
        push!(
            variables,
            _make_variable!(
                jump_model,
                data.names[position],
                data.lower_bounds[position],
                data.upper_bounds[position],
                data.start_values[position],
            ),
        )
    end

    agent_variables = _variable_block(
        variables,
        1,
        layout.number_of_agent_variables,
    )
    price_variables = _variable_block(
        variables,
        layout.number_of_agent_variables + 1,
        layout.number_of_price_variables,
    )
    auxiliary_variables = _variable_block(
        variables,
        layout.number_of_agent_variables + layout.number_of_price_variables + 1,
        layout.number_of_auxiliary_variables,
    )

    prices = Any[zero(Float64) for _ in model.commodity_names]
    for commodity in eachindex(model.commodity_names)
        if commodity == layout.numeraire_index
            prices[commodity] = Float64(layout.numeraire_value)
        else
            position = layout.price_variable_position[commodity]
            position > 0 || error(
                "Internal error: nonnumeraire price has no global JuMP position.",
            )
            prices[commodity] = variables[position]
        end
    end

    return EquilibriumJumpVariables(
        agent_variables,
        price_variables,
        auxiliary_variables,
        variables,
        prices,
        copy(data.lower_bounds),
        copy(data.upper_bounds),
        copy(data.start_values),
    )
end


# ----------------------------------------------------------------
# 9. Reference resolution to JuMP variables or fixed values
# ----------------------------------------------------------------

"""
    equilibrium_jump_reference(variables, layout, ref)

Resolve one model-level reference to its JuMP variable or fixed value.
"""
function equilibrium_jump_reference(
    variables::EquilibriumJumpVariables,
    layout::EquilibriumJumpLayout,
    ref::EquilibriumVariableRef,
)
    resolution = resolve_equilibrium_variable_ref(layout, ref)

    if is_endogenous_resolution(resolution)
        1 <= resolution.position <= length(variables.variables) || error(
            "Internal error: resolved equilibrium-variable position is outside " *
            "the JuMP variable vector.",
        )
        return variables.variables[resolution.position]
    end

    return Float64(resolution.fixed_value)
end

"""
    equilibrium_jump_references(variables, layout, refs)

Resolve a vector of model-level references in declared order.
"""
function equilibrium_jump_references(
    variables::EquilibriumJumpVariables,
    layout::EquilibriumJumpLayout,
    refs::AbstractVector,
)
    all(is_equilibrium_variable_ref, refs) || throw(ArgumentError(
        "refs may contain only AgentVariableRef, PriceVariableRef, or " *
        "AuxiliaryVariableRef objects.",
    ))

    return Any[
        equilibrium_jump_reference(variables, layout, ref)
        for ref in refs
    ]
end

end # module EquilibriumJumpModelV2
