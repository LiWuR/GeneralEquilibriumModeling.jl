# ================================================================
# relative_agent_refs_v1.jl
#
# RelativePeriod extension for structured AgentRef.
#
# AgentRef remains a general GEMB identity type. This file adds only the
# context-dependent period semantics needed by relative agent references.
# ================================================================


# ----------------------------------------------------------------
# 1. Allow RelativePeriod only on AgentRef's :period selector.
# ----------------------------------------------------------------

function _validate_agent_ref_selector_value(
    axis_name::Symbol,
    value::RelativePeriod,
)
    axis_name === :period || throw(ArgumentError(
        "RelativePeriod can be used only for the :period axis of AgentRef.",
    ))

    return nothing
end


# ----------------------------------------------------------------
# 2. A relative AgentRef cannot be flattened before materialization.
# ----------------------------------------------------------------

function _agent_ref_value_token(
    value::RelativePeriod,
)
    throw(ArgumentError(
        "An AgentRef containing RelativePeriod cannot be converted directly " *
        "to a flat GEM agent name. Resolve it with a base_period first.",
    ))
end


# ----------------------------------------------------------------
# 3. Relative AgentRef -> absolute AgentRef.
# ----------------------------------------------------------------

"""
    _absolute_intertemporal_agent_ref(
        ref;
        base_period=nothing,
    )

Convert an AgentRef `:period` selector from `RelativePeriod(offset)` to
`base_period + offset`.

AgentRef objects with no `:period` selector, or with an already-absolute
`:period` selector, are returned unchanged.
"""
function _absolute_intertemporal_agent_ref(
    ref::AgentRef;
    base_period::Union{Nothing,Integer}=nothing,
)
    selector_names =
        keys(
            ref.selectors,
        )

    :period in selector_names ||
        return ref

    period_selector =
        getproperty(
            ref.selectors,
            :period,
        )

    period_selector isa RelativePeriod ||
        return ref

    base_period === nothing && throw(ArgumentError(
        "A base_period is required to resolve RelativePeriod in AgentRef.",
    ))

    base_period isa Bool && throw(ArgumentError(
        "base_period must be an absolute integer period, not Bool.",
    ))

    absolute_period =
        Int(base_period) +
        period_selector.offset

    values =
        Tuple(
            if selector_name === :period
                absolute_period
            else
                getproperty(
                    ref.selectors,
                    selector_name,
                )
            end
            for selector_name in selector_names
        )

    absolute_selectors =
        NamedTuple{selector_names}(
            values,
        )

    return AgentRef(
        ref.name;
        absolute_selectors...,
    )
end


# ----------------------------------------------------------------
# 4. Relative AgentRef -> registered GEMBModel agent position.
# ----------------------------------------------------------------

"""
    _resolve_intertemporal_agent_ref(
        model,
        ref;
        base_period=nothing,
    )

Resolve one possibly-relative AgentRef through the ordinary GEMBModel
AgentRef registry after materializing its relative period.
"""
function _resolve_intertemporal_agent_ref(
    model::GEMBModel,
    ref::AgentRef;
    base_period::Union{Nothing,Integer}=nothing,
)
    absolute_ref =
        _absolute_intertemporal_agent_ref(
            ref;
            base_period=base_period,
        )

    return _resolve_agent_ref(
        model,
        absolute_ref,
    )
end
