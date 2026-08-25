# ================================================================
# relative_commodity_refs_v1.jl
#
# RelativePeriod extension for CommodityRef materialization inside ordinary
# GEMBModel.add_agent!.
#
# RelativePeriod is interpreted relative to the concrete AgentRef being
# added. This is a reference-materialization extension only and does not
# define a separate intertemporal model layer.
# ================================================================


function _materialize_commodity_selector_value(
    axis_name::Symbol,
    value::RelativePeriod,
    observer_ref::AgentRef,
)
    axis_name === :period || throw(ArgumentError(
        "RelativePeriod can be used only for the :period axis of CommodityRef.",
    ))

    :period in keys(observer_ref.selectors) || throw(ArgumentError(
        "A relative CommodityRef requires the concrete AgentRef supplied to " *
        "add_agent! to have an absolute :period selector.",
    ))

    observer_period =
        getproperty(
            observer_ref.selectors,
            :period,
        )

    observer_period isa Integer &&
    !(observer_period isa Bool) ||
        throw(ArgumentError(
            "The concrete AgentRef period must be an absolute integer before " *
            "RelativePeriod commodity references are materialized.",
        ))

    return Int(observer_period) +
           value.offset
end
