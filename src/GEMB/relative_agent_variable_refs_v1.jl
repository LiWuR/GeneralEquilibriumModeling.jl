# ================================================================
# relative_agent_variable_refs_v1.jl
#
# RelativePeriod extension for high-level structured agent-variable
# references.
#
# RelativePeriod inside a target AgentRef is interpreted relative to the
# observing agent's own absolute :period selector.
#
# This is a reference-materialization extension only. It does not define a
# separate intertemporal model layer and does not change GEM core types.
# ================================================================


function _materialize_agent_selector_value(
    axis_name::Symbol,
    value::RelativePeriod,
    observer_ref::AgentRef,
)
    axis_name === :period || throw(ArgumentError(
        "RelativePeriod can be used only for the :period axis of AgentRef.",
    ))

    :period in keys(observer_ref.selectors) || throw(ArgumentError(
        "A relative agent-variable reference requires the observing AgentRef " *
        "to have an absolute :period selector.",
    ))

    observer_period =
        getproperty(
            observer_ref.selectors,
            :period,
        )

    observer_period isa Integer &&
    !(observer_period isa Bool) ||
        throw(ArgumentError(
            "The observing AgentRef period must be an absolute integer before " *
            "relative agent-variable references are materialized.",
        ))

    return Int(observer_period) +
           value.offset
end
