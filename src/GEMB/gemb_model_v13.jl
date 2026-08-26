# ================================================================
# gemb_model_v13.jl
#
# High-level equilibrium-model container for GEMB.
#
# Direct dated-agent RelativePeriod integration STEP 7B.
#
# Relative to V12:
#
#   - add_agent! materializes RelativePeriod values inside CommodityRef
#     selectors using the concrete AgentRef supplied through name;
#   - outputs, demands, endowments, and claim therefore share one ordinary
#     add_agent! commodity-materialization path;
#   - the generic GEMB layer defines only the materialization hook;
#   - the RelativePeriod-specific method remains in the intertemporal
#     extension layer;
#   - existing observed AgentRef materialization remains unchanged.
#
# Earlier V12 changes:
#
#   - add_agent! accepts high-level agent_variable_ref(...) objects through
#     observed_variables;
#   - structured target AgentRefs are materialized to GEM.AgentVariableRef
#     without requiring the target agent to exist yet;
#   - forward references therefore remain valid until final GEM model
#     validation;
#   - ordinary GEM AgentVariableRef / PriceVariableRef /
#     AuxiliaryVariableRef inputs remain unchanged;
#   - context-dependent AgentRef selector values are materialized through the
#     extension hook defined in agent_ref_v2.jl.
#
# Earlier V11 changes:
#
#   - adds internal absolute AgentRef / Symbol resolution against GEMBModel;
#   - keeps structured identity authoritative while preserving flat Symbol
#     compatibility;
#   - provides the generic resolution target used later by the intertemporal
#     AgentRef + RelativePeriod extension.
#
# The AgentRef registration behavior introduced in V10 is unchanged.
#
# Earlier V10 changes:
#
#   - GEMBModel stores structured AgentRef identities explicitly;
#   - add_agent! accepts name::Symbol or name::AgentRef;
#   - Symbol names are normalized to AgentRef(symbol);
#   - AgentRef is encoded to a deterministic flat Symbol only when the
#     existing GEM build_agent API is called;
#   - model state maintains AgentRef <-> position and flat Symbol <-> position;
#   - structured-identity and flat-name collisions are rejected transactionally;
#   - RelativePeriod is still NOT interpreted by AgentRef in this step.
#
# This file is included directly into module GEMB.
# ================================================================


"""
    GEMBModel(
        commodity_declarations;
        numeraire=nothing,
        numeraire_value=1.0,
        solver=GEM.solve_equilibrium_model_mcp_jump,
    )

Create a mutable high-level GEMB model container backed by `CommoditySpace`.

Each entry in `commodity_declarations` may be either:

- a `Symbol`, interpreted as a simple zero-axis commodity; or
- a `CommoditySpec`, which may define structured commodity axes and bounds.

`numeraire` may be either a `Symbol` or a `CommodityRef`, but it must resolve
to exactly one concrete commodity. If omitted, the first concrete commodity
is used.

For a structured commodity group, a group-name `Symbol` is shorthand for
`CommodityRef(symbol)` and therefore may match multiple concrete commodities.
Flat generated commodity names remain accepted as a compatibility fallback.

The model stores the selected numeraire as the canonical flat commodity name.

Economic agents may later be added with either a simple `Symbol` name or an
absolute `AgentRef`. `Symbol` is shorthand for `AgentRef(symbol)`. The
structured identity is retained by `GEMBModel`, while GEM receives only the
deterministic flat `Symbol` generated from that identity.
"""
mutable struct GEMBModel{T<:Real,S}
    commodity_space::CommoditySpace
    commodity_names::Vector{Symbol}
    commodity_index::Dict{Symbol,Int}

    agents::Vector{GEM.AbstractNetSupplyAgent}
    agent_refs::Vector{AgentRef}
    agent_index::Dict{Symbol,Int}
    agent_ref_index::Dict{AgentRef,Int}

    numeraire::Symbol
    numeraire_value::T
    solver::S
end


# ----------------------------------------------------------------
# Commodity-selector resolution against CommoditySpace
# ----------------------------------------------------------------

function _available_commodity_groups(
    space::CommoditySpace,
)
    return join(
        repr.([
            spec.name
            for spec in space.specs
        ]),
        ", ",
    )
end


function _available_flat_commodity_names(
    flat_index::Dict{Symbol,Int},
)
    names = collect(keys(flat_index))
    sort!(
        names;
        by=name -> flat_index[name],
    )

    return join(
        repr.(names),
        ", ",
    )
end


function _resolve_commodity_item(
    space::CommoditySpace,
    flat_index::Dict{Symbol,Int},
    ref::CommodityRef,
)
    return _resolve_commodity_ref(
        space,
        ref,
    )
end


function _resolve_commodity_item(
    space::CommoditySpace,
    flat_index::Dict{Symbol,Int},
    name::Symbol,
)
    # Preferred meaning: a commodity-group Symbol is syntax sugar for
    # CommodityRef(name). This lets :product select the full structured
    # :product group.
    if haskey(
        space.spec_by_name,
        name,
    )
        return _resolve_commodity_ref(
            space,
            CommodityRef(name),
        )
    end

    # Compatibility fallback: accept a canonical flat GEM commodity name,
    # such as :product_1, when no commodity group has that name.
    if haskey(
        flat_index,
        name,
    )
        return [
            flat_index[name],
        ]
    end

    throw(ArgumentError(
        "Unknown commodity selector $(repr(name)). Available commodity " *
        "groups: " *
        _available_commodity_groups(space) *
        ". Available flat commodities: " *
        _available_flat_commodity_names(flat_index) *
        ".",
    ))
end


function _resolve_commodity_item(
    ::CommoditySpace,
    ::Dict{Symbol,Int},
    selector,
)
    throw(ArgumentError(
        "Each commodity selector must be a Symbol or CommodityRef; got " *
        "$(typeof(selector)).",
    ))
end


function _resolve_commodity_selection(
    ::CommoditySpace,
    ::Dict{Symbol,Int},
    ::Nothing;
    allow_duplicates::Bool=false,
)
    return Int[]
end


function _resolve_commodity_selection(
    space::CommoditySpace,
    flat_index::Dict{Symbol,Int},
    selector::Union{Symbol,CommodityRef};
    allow_duplicates::Bool=false,
)
    return _resolve_commodity_item(
        space,
        flat_index,
        selector,
    )
end


function _resolve_commodity_selection(
    space::CommoditySpace,
    flat_index::Dict{Symbol,Int},
    selectors::AbstractVector;
    allow_duplicates::Bool=false,
)
    resolved = Int[]

    for selector in selectors
        append!(
            resolved,
            _resolve_commodity_item(
                space,
                flat_index,
                selector,
            ),
        )
    end

    if !allow_duplicates &&
       length(unique(resolved)) != length(resolved)
        throw(ArgumentError(
            "Commodity selection contains overlapping commodities.",
        ))
    end

    return resolved
end


function _resolve_commodity_selection(
    ::CommoditySpace,
    ::Dict{Symbol,Int},
    selector;
    allow_duplicates::Bool=false,
)
    throw(ArgumentError(
        "Commodity selector must be nothing, a Symbol, a CommodityRef, " *
        "or an AbstractVector containing Symbol/CommodityRef entries; got " *
        "$(typeof(selector)).",
    ))
end


function _resolve_one_commodity(
    space::CommoditySpace,
    flat_index::Dict{Symbol,Int},
    selector;
    role::AbstractString="commodity selector",
)
    resolved =
        _resolve_commodity_selection(
            space,
            flat_index,
            selector,
        )

    length(resolved) == 1 || throw(ArgumentError(
        "$(role) must resolve to exactly one concrete commodity; " *
        "matched $(length(resolved)).",
    ))

    return only(resolved)
end


function GEMBModel(
    commodity_declarations::AbstractVector;
    numeraire=nothing,
    numeraire_value::Real=1.0,
    solver=GEM.solve_equilibrium_model_mcp_jump,
)
    space = CommoditySpace(
        commodity_declarations,
    )

    names = copy(
        space.commodity_names,
    )

    flat_index = Dict(
        name => i
        for (i, name) in pairs(names)
    )

    numeraire_index = if numeraire === nothing
        1
    else
        _resolve_one_commodity(
            space,
            flat_index,
            numeraire;
            role="numeraire",
        )
    end

    selected_numeraire =
        names[numeraire_index]

    isfinite(numeraire_value) && numeraire_value > 0 || throw(ArgumentError(
        "numeraire_value must be finite and positive.",
    ))

    lower =
        space.price_lower_bounds[numeraire_index]

    upper =
        space.price_upper_bounds[numeraire_index]

    lower <= numeraire_value <= upper || throw(ArgumentError(
        "numeraire_value must lie within the price bounds of the " *
        "numeraire commodity.",
    ))

    T = promote_type(
        Float64,
        typeof(numeraire_value),
    )

    return GEMBModel{T,typeof(solver)}(
        space,
        names,
        flat_index,
        GEM.AbstractNetSupplyAgent[],
        AgentRef[],
        Dict{Symbol,Int}(),
        Dict{AgentRef,Int}(),
        selected_numeraire,
        T(numeraire_value),
        solver,
    )
end


# ----------------------------------------------------------------
# GEMBModel commodity resolution
# ----------------------------------------------------------------

function _available_commodity_names(
    model::GEMBModel,
)
    return join(
        repr.(model.commodity_names),
        ", ",
    )
end


function _resolve_commodity_index(
    model::GEMBModel,
    selector,
)
    return _resolve_one_commodity(
        model.commodity_space,
        model.commodity_index,
        selector;
        role="commodity selector",
    )
end


"""
    _resolve_commodities(model, selector)

Resolve high-level commodity selectors to the integer commodity indices used
by the existing GEMB `build_agent` API.

Accepted selector forms:

- `nothing`;
- a `Symbol`;
- a `CommodityRef`;
- an `AbstractVector` containing `Symbol` and/or `CommodityRef` entries.

A commodity-group `Symbol` is shorthand for `CommodityRef(symbol)`.
Consequently, `:product` may select an entire structured commodity group.
A canonical flat commodity name such as `:product_1` remains accepted as a
compatibility fallback.

For a single `CommodityRef`, concrete commodities follow the canonical order
of `CommoditySpace`. For a vector of selectors, selector-block order is
preserved and each block uses canonical order internally.

Overlapping selections are rejected.
"""
function _resolve_commodities(
    model::GEMBModel,
    selector,
)
    return _resolve_commodity_selection(
        model.commodity_space,
        model.commodity_index,
        selector,
    )
end


# ----------------------------------------------------------------
# Agent identity and insertion helpers
# ----------------------------------------------------------------

function _normalize_agent_ref(
    ref::AgentRef,
)
    return ref
end


function _normalize_agent_ref(
    name::Symbol,
)
    return AgentRef(name)
end


function _normalize_agent_ref(
    name,
)
    throw(ArgumentError(
        "Agent name must be a Symbol or AgentRef; got $(typeof(name)).",
    ))
end


"""
    _resolve_agent_ref(model, ref)

Resolve one absolute agent identity to its unique position in `model.agents`.

For an explicit `AgentRef`, structural identity is authoritative.

For a `Symbol`, an existing flat GEM agent name is accepted first for backward
compatibility. If no flat name exists, the symbol is interpreted as
`AgentRef(symbol)`.

This function intentionally has no RelativePeriod semantics. The
intertemporal layer must first convert a relative `AgentRef` to an absolute
one.
"""
function _resolve_agent_ref(
    model::GEMBModel,
    ref::AgentRef,
)
    position =
        get(
            model.agent_ref_index,
            ref,
            0,
        )

    position > 0 || throw(ArgumentError(
        "Unknown agent identity $(repr(ref)).",
    ))

    return position
end


function _resolve_agent_ref(
    model::GEMBModel,
    name::Symbol,
)
    flat_position =
        get(
            model.agent_index,
            name,
            0,
        )

    flat_position > 0 &&
        return flat_position

    return _resolve_agent_ref(
        model,
        AgentRef(name),
    )
end


function _resolve_agent_ref(
    model::GEMBModel,
    selector,
)
    throw(ArgumentError(
        "Agent selector must be a Symbol or AgentRef; got " *
        "$(typeof(selector)).",
    ))
end


"""
    _resolve_agent_name(model, ref)

Return the flat GEM agent name associated with one resolved agent identity.
"""
function _resolve_agent_name(
    model::GEMBModel,
    selector,
)
    position =
        _resolve_agent_ref(
            model,
            selector,
        )

    return GEM.agent_name(
        model.agents[position],
    )
end


function _check_new_agent_identity(
    model::GEMBModel,
    ref::AgentRef,
    flat_name::Symbol,
)
    haskey(
        model.agent_ref_index,
        ref,
    ) && throw(ArgumentError(
        "Agent identity $(repr(ref)) already exists in GEMBModel.",
    ))

    haskey(
        model.agent_index,
        flat_name,
    ) && throw(ArgumentError(
        "Flat agent name $(repr(flat_name)) already exists in GEMBModel. " *
        "This may indicate a collision between a simple Symbol name and a " *
        "structured AgentRef.",
    ))

    return nothing
end


# ----------------------------------------------------------------
# High-level commodity-reference materialization
# ----------------------------------------------------------------

"""
    _materialize_commodity_selector_value(
        axis_name,
        value,
        observer_ref,
    )

Materialize one CommodityRef selector value in the context of the concrete
agent being added.

The general GEMB layer leaves ordinary absolute selector values unchanged.
Intertemporal extensions add a more-specific method for `RelativePeriod`.
"""
function _materialize_commodity_selector_value(
    axis_name::Symbol,
    value,
    observer_ref::AgentRef,
)
    return value
end


"""
    _materialize_commodity_ref(observer_ref, ref)

Convert a possibly context-dependent CommodityRef into an absolute
CommodityRef for one concrete agent.

Ordinary selector values pass through unchanged. Context-dependent selector
types are handled through `_materialize_commodity_selector_value` dispatch.
"""
function _materialize_commodity_ref(
    observer_ref::AgentRef,
    ref::CommodityRef,
)
    selector_names =
        keys(
            ref.selectors,
        )

    isempty(selector_names) &&
        return ref

    values =
        Tuple(
            _materialize_commodity_selector_value(
                selector_name,
                getproperty(
                    ref.selectors,
                    selector_name,
                ),
                observer_ref,
            )
            for selector_name in selector_names
        )

    selectors =
        NamedTuple{selector_names}(
            values,
        )

    return CommodityRef(
        ref.name;
        selectors...,
    )
end


_materialize_add_agent_commodity_selector(
    ::AgentRef,
    ::Nothing,
) = nothing


_materialize_add_agent_commodity_selector(
    ::AgentRef,
    selector::Symbol,
) = selector


function _materialize_add_agent_commodity_selector(
    observer_ref::AgentRef,
    selector::CommodityRef,
)
    return _materialize_commodity_ref(
        observer_ref,
        selector,
    )
end


function _materialize_add_agent_commodity_selector(
    observer_ref::AgentRef,
    selectors::AbstractVector,
)
    return [
        _materialize_add_agent_commodity_selector(
            observer_ref,
            selector,
        )
        for selector in selectors
    ]
end


function _materialize_add_agent_commodity_selector(
    ::AgentRef,
    selector,
)
    # Preserve the existing add_agent! validation boundary. Unsupported
    # selector types are passed through and rejected by _resolve_commodities
    # or _resolve_claim_index with the established high-level error.
    return selector
end


# ----------------------------------------------------------------
# High-level observed-variable materialization
# ----------------------------------------------------------------

function _materialize_observed_variable_ref(
    observer_ref::AgentRef,
    ref::_StructuredAgentVariableRef,
)
    target_ref =
        _materialize_agent_ref(
            observer_ref,
            ref.agent,
        )

    target_name =
        _flat_agent_name(
            target_ref,
        )

    return GEM.AgentVariableRef(
        target_name,
        ref.variable_name,
    )
end


function _materialize_observed_variable_ref(
    observer_ref::AgentRef,
    ref,
)
    # Preserve existing GEM reference objects and let build_agent retain its
    # established validation for unsupported reference types.
    return ref
end


function _normalize_high_level_observed_variables(
    observer_ref::AgentRef,
    value,
)
    value === nothing &&
        return nothing

    if value isa _StructuredAgentVariableRef
        return _materialize_observed_variable_ref(
            observer_ref,
            value,
        )
    end

    if value isa GEM.AgentVariableRef ||
       value isa GEM.PriceVariableRef ||
       value isa GEM.AuxiliaryVariableRef
        return value
    end

    refs =
        collect(
            value,
        )

    return [
        _materialize_observed_variable_ref(
            observer_ref,
            ref,
        )
        for ref in refs
    ]
end


function _normalize_add_agent_observed_variables(
    observer_ref::AgentRef,
    kwargs,
)
    normalized =
        (; kwargs...)

    :observed_variables in keys(normalized) ||
        return normalized

    observed =
        _normalize_high_level_observed_variables(
            observer_ref,
            normalized.observed_variables,
        )

    return merge(
        normalized,
        (
            observed_variables=observed,
        ),
    )
end


function _check_add_agent_keywords(
    kwargs,
)
    forbidden = (
        :output_indices,
        :demand_indices,
        :endowment_indices,
        :claim_index,
    )

    supplied = [
        key
        for key in forbidden
        if key in keys(kwargs)
    ]

    isempty(supplied) || throw(ArgumentError(
        "add_agent! uses high-level commodity selectors through outputs, " *
        "demands, endowments, and claim. Do not pass low-level index " *
        "keyword(s): " *
        join(repr.(supplied), ", ") * ".",
    ))

    return nothing
end


function _resolve_claim_index(
    model::GEMBModel,
    claim,
    kwargs,
)
    claim === nothing &&
        return nothing

    (:claim_rate in keys(kwargs)) || throw(ArgumentError(
        "claim requires claim_rate to be specified.",
    ))

    return _resolve_one_commodity(
        model.commodity_space,
        model.commodity_index,
        claim;
        role="claim",
    )
end


"""
    add_agent!(
        model::GEMBModel,
        spec;
        outputs=nothing,
        demands=nothing,
        endowments=nothing,
        claim=nothing,
        name,
        kwargs...,
    )

Construct an economic agent using high-level commodity selectors and add the
completed agent to `model`.

`outputs`, `demands`, and `endowments` may each use:

- a `Symbol`;
- a `CommodityRef`;
- a vector containing `Symbol` and/or `CommodityRef`;
- `nothing`.

`claim` may use a `Symbol` or `CommodityRef` but must resolve to exactly one
concrete commodity.

`name` may be either:

- a `Symbol`, interpreted as `AgentRef(name)`; or
- an absolute `AgentRef`.

The `AgentRef` is retained by `GEMBModel`. A deterministic flat `Symbol` is
generated only for the existing GEM `build_agent` interface.

Before commodity resolution, CommodityRef selectors are materialized in the
context of the concrete `AgentRef` supplied through `name`. This allows an
intertemporal extension to interpret `RelativePeriod` while leaving ordinary
absolute selectors unchanged.

All resulting commodity selectors are then resolved through the model's
`CommoditySpace`, after which the existing integer-based `build_agent`
multiple-dispatch API is used unchanged.

`observed_variables` may additionally contain values created by

    agent_variable_ref(AgentRef(...), :variable_name)

These structured targets are converted to ordinary `GEM.AgentVariableRef`
objects before `build_agent` is called. Target existence is deliberately not
checked at this stage, preserving GEM's forward-reference behavior.

The operation is transactional with respect to `model`: identity checks,
commodity resolution, observed-reference materialization, and `build_agent`
must all succeed before any agent collection or agent-index mapping is
modified.
"""
function add_agent!(
    model::GEMBModel,
    spec;
    outputs=nothing,
    demands=nothing,
    endowments=nothing,
    claim=nothing,
    name,
    kwargs...,
)
    agent_ref =
        _normalize_agent_ref(
            name,
        )

    flat_name =
        _flat_agent_name(
            agent_ref,
        )

    _check_new_agent_identity(
        model,
        agent_ref,
        flat_name,
    )

    _check_add_agent_keywords(
        kwargs,
    )

    build_kwargs =
        _normalize_add_agent_observed_variables(
            agent_ref,
            kwargs,
        )

    materialized_outputs =
        _materialize_add_agent_commodity_selector(
            agent_ref,
            outputs,
        )

    materialized_demands =
        _materialize_add_agent_commodity_selector(
            agent_ref,
            demands,
        )

    materialized_endowments =
        _materialize_add_agent_commodity_selector(
            agent_ref,
            endowments,
        )

    materialized_claim =
        _materialize_add_agent_commodity_selector(
            agent_ref,
            claim,
        )

    output_indices =
        _resolve_commodities(
            model,
            materialized_outputs,
        )

    demand_indices =
        _resolve_commodities(
            model,
            materialized_demands,
        )

    endowment_indices =
        _resolve_commodities(
            model,
            materialized_endowments,
        )

    claim_index =
        _resolve_claim_index(
            model,
            materialized_claim,
            build_kwargs,
        )

    agent = if claim_index === nothing
        build_agent(
            spec;
            output_indices=output_indices,
            demand_indices=demand_indices,
            endowment_indices=endowment_indices,
            name=flat_name,
            build_kwargs...,
        )
    else
        build_agent(
            spec;
            output_indices=output_indices,
            demand_indices=demand_indices,
            endowment_indices=endowment_indices,
            claim_index=claim_index,
            name=flat_name,
            build_kwargs...,
        )
    end

    # Commit all aligned agent-registry state only after construction succeeds.
    push!(
        model.agents,
        agent,
    )

    push!(
        model.agent_refs,
        agent_ref,
    )

    position =
        length(model.agents)

    model.agent_index[flat_name] =
        position

    model.agent_ref_index[agent_ref] =
        position

    return agent
end


# ----------------------------------------------------------------
# GEM model materialization
# ----------------------------------------------------------------

"""
    build_model(model::GEMBModel)

Materialize the current high-level `GEMBModel` as a fresh
`GEM.EquilibriumModel`.

The flat commodity ordering and price bounds come from the model's
`CommoditySpace`. Existing agents already use integer commodity indices in
that same fixed ordering. Agent identities have already been encoded to flat
GEM names when each agent was added, while `model.agent_refs` retains the
structured identities at the GEMB layer.

All model-wide structural validation remains the responsibility of the
existing `GEM.EquilibriumModel` constructor. A new GEM model is constructed
on every call; `GEMBModel` does not cache a low-level model.
"""
function build_model(
    model::GEMBModel,
)
    numeraire_index =
        model.commodity_index[
            model.numeraire
        ]

    return GEM.EquilibriumModel(
        model.agents,
        model.commodity_names;
        numeraire_index=numeraire_index,
        numeraire_value=model.numeraire_value,
        price_lower_bounds=
            model.commodity_space.price_lower_bounds,
        price_upper_bounds=
            model.commodity_space.price_upper_bounds,
    )
end


# ----------------------------------------------------------------
# High-level solve entry
# ----------------------------------------------------------------

"""
    solve(
        model::GEMBModel;
        solver=model.solver,
        kwargs...,
    )

Build a fresh low-level `GEM.EquilibriumModel` from `model` and solve it with
the selected solver.

By default, the solver stored in `model.solver` is used. A different solver
may be supplied for one call with the `solver` keyword without mutating
`model`.

All remaining keyword arguments are forwarded unchanged to the selected
solver. `solve` does not store the result in `GEMBModel`.
"""
function solve(
    model::GEMBModel;
    solver=model.solver,
    kwargs...,
)
    gem_model =
        build_model(
            model,
        )

    return solver(
        gem_model;
        kwargs...,
    )
end
