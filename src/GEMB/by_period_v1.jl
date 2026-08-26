# ================================================================
# by_period_v1.jl
#
# Explicit period-varying values for agent-template expansion.
#
# ByPeriod does not modify ordinary GEMB behavior specifications or
# add_agent!. It is materialized only while a repeated agent template is
# expanded into one concrete agent per period.
# ================================================================


"""
    ByPeriod(values)
    ByPeriod(period => value, ...)
    ByPeriod(f)

Mark a template value as varying across repeated agent periods.

Supported providers:

- `AbstractVector`: values are matched by template position. For
  `periods=[1, 3, 5]`, `ByPeriod([a, b, c])` means
  `1 => a`, `3 => b`, `5 => c`.
- `AbstractDict`: values are looked up by the actual period label.
- `Pair...`: shorthand for an actual-period mapping.
- `Function`: called as `f(period)` with the actual period label.

A plain vector without `ByPeriod(...)` keeps its ordinary meaning and is
never interpreted as a period-varying template value.
"""
struct ByPeriod{P}
    provider::P

    function ByPeriod(provider::P) where {P}
        provider isa AbstractVector ||
        provider isa AbstractDict ||
        provider isa Function ||
            throw(ArgumentError(
                "ByPeriod requires a vector, dictionary, period=>value pairs, " *
                "or a function of the actual period.",
            ))

        if provider isa AbstractDict
            for key in keys(provider)
                key isa Integer &&
                !(key isa Bool) &&
                Int(key) >= 1 ||
                    throw(ArgumentError(
                        "ByPeriod dictionary keys must be positive integer periods.",
                    ))
            end
        end

        return new{P}(provider)
    end
end


function ByPeriod(
    pairs::Pair...,
)
    isempty(pairs) && throw(ArgumentError(
        "ByPeriod period=>value mapping cannot be empty.",
    ))

    mapping =
        Dict{Int,Any}()

    for pair in pairs
        raw_period =
            first(pair)

        raw_period isa Integer &&
        !(raw_period isa Bool) ||
            throw(ArgumentError(
                "ByPeriod pair keys must be integer periods.",
            ))

        period =
            Int(raw_period)

        period >= 1 || throw(ArgumentError(
            "ByPeriod pair keys must be positive periods.",
        ))

        haskey(
            mapping,
            period,
        ) && throw(ArgumentError(
            "ByPeriod contains duplicate period $(period).",
        ))

        mapping[period] =
            last(pair)
    end

    return ByPeriod(
        mapping,
    )
end


"""
    _materialize_template_value(
        value;
        period=nothing,
        position=nothing,
        periods=nothing,
    )

Return the concrete value for one template instance.

Ordinary values pass through unchanged. `ByPeriod` values require a repeated
template context and are resolved during the same expansion step that resolves
`RelativePeriod` references.
"""
function _materialize_template_value(
    value;
    period=nothing,
    position=nothing,
    periods=nothing,
)
    return value
end


function _materialize_template_value(
    value::ByPeriod;
    period=nothing,
    position=nothing,
    periods=nothing,
)
    period === nothing && throw(ArgumentError(
        "ByPeriod requires a concrete template period.",
    ))

    periods === nothing && throw(ArgumentError(
        "ByPeriod may only be used while expanding a repeated agent template.",
    ))

    actual_period =
        Int(period)

    provider =
        value.provider

    if provider isa AbstractVector
        position === nothing && throw(ArgumentError(
            "ByPeriod vector resolution requires the template instance position.",
        ))

        instance_position =
            Int(position)

        length(provider) == length(periods) || throw(DimensionMismatch(
            "ByPeriod vector length must equal the number of template periods.",
        ))

        1 <= instance_position <= length(provider) || throw(BoundsError(
            provider,
            instance_position,
        ))

        return provider[instance_position]
    elseif provider isa AbstractDict
        haskey(
            provider,
            actual_period,
        ) || throw(ArgumentError(
            "ByPeriod mapping has no value for period $(actual_period).",
        ))

        return provider[actual_period]
    elseif provider isa Function
        return provider(
            actual_period,
        )
    end

    error(
        "Unsupported ByPeriod provider type $(typeof(provider))."
    )
end


export ByPeriod
