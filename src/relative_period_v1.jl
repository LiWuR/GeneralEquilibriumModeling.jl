# ================================================================
# relative_period_v1.jl
#
# Relative period selector shared by dated CommodityRef and AgentRef
# materialization.
# ================================================================


"""
    RelativePeriod(offset)

Represent a period relative to the concrete agent period used as context.

Examples:

    RelativePeriod(0)   # current period
    RelativePeriod(1)   # next period
    RelativePeriod(-1)  # previous period

An integer selector remains absolute. `RelativePeriod` is materialized only
when a concrete dated AgentRef provides the period context.
"""
struct RelativePeriod
    offset::Int
end


RelativePeriod(
    offset::Integer,
) = RelativePeriod(
    Int(offset),
)


export RelativePeriod
