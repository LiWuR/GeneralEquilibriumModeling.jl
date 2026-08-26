# ================================================================
# agent_template_v2.jl
#
# Final repeated-agent template after STEP 7C2.
#
# AgentTemplate represents only repeated concrete agents. One concrete
# dated agent belongs in ordinary add_agent!.
# ================================================================


function _normalize_agent_template_identity(
    raw_agent,
)
    if raw_agent isa AgentRef
        return raw_agent
    elseif raw_agent isa Symbol
        return AgentRef(
            raw_agent,
        )
    end

    throw(ArgumentError(
        "The first AgentTemplate argument must be a Symbol or AgentRef.",
    ))
end


function _normalize_agent_template_periods(
    raw_periods,
)
    raw_periods === nothing &&
        throw(ArgumentError(
            "AgentTemplate requires `periods`.",
        ))

    raw_values =
        if raw_periods isa Integer &&
           !(raw_periods isa Bool)
            [
                raw_periods,
            ]
        else
            try
                collect(
                    raw_periods,
                )
            catch
                throw(ArgumentError(
                    "AgentTemplate periods must be an integer or an iterable " *
                    "collection of integers.",
                ))
            end
        end

    isempty(raw_values) &&
        throw(ArgumentError(
            "AgentTemplate periods cannot be empty.",
        ))

    all(
        period ->
            period isa Integer &&
            !(period isa Bool),
        raw_values,
    ) || throw(ArgumentError(
        "AgentTemplate periods must contain only non-Bool integer values.",
    ))

    periods =
        Int.(
            raw_values,
        )

    all(
        period ->
            period >= 1,
        periods,
    ) || throw(ArgumentError(
        "AgentTemplate periods must contain only positive integers.",
    ))

    length(
        unique(
            periods,
        ),
    ) == length(periods) || throw(ArgumentError(
        "AgentTemplate periods cannot contain duplicates.",
    ))

    sort!(
        periods,
    )

    return periods
end


function _normalize_agent_template_refs(
    refs,
    description::AbstractString,
)
    refs isa AbstractVector ||
        throw(ArgumentError(
            "$(description) must be a vector of CommodityRef objects.",
        ))

    all(
        ref ->
            ref isa CommodityRef,
        refs,
    ) || throw(ArgumentError(
        "$(description) must contain only CommodityRef objects.",
    ))

    return CommodityRef[
        refs...
    ]
end


function _normalize_agent_template_endowments(
    endowments,
)
    endowments isa AbstractVector ||
        throw(ArgumentError(
            "endowments must be a vector of CommodityRef => quantity pairs.",
        ))

    normalized =
        Pair{CommodityRef,Any}[]

    for entry in endowments
        entry isa Pair ||
            throw(ArgumentError(
                "Each endowment entry must be CommodityRef => quantity.",
            ))

        ref =
            first(
                entry,
            )

        quantity =
            last(
                entry,
            )

        ref isa CommodityRef ||
            throw(ArgumentError(
                "The left side of each endowment pair must be a CommodityRef.",
            ))

        quantity isa Real ||
        quantity isa AbstractVector ||
        quantity isa ByPeriod ||
            throw(ArgumentError(
                "Endowment quantity must be a real scalar, a real vector, or ByPeriod.",
            ))

        push!(
            normalized,
            Pair{CommodityRef,Any}(
                ref,
                quantity,
            ),
        )
    end

    return normalized
end


const _AGENT_TEMPLATE_RESERVED_OPTION_NAMES = (
    :name,
    :demand_indices,
    :output_indices,
    :endowment_indices,
    :endowment_quantities,
    :claim_index,
    :active_periods,
)


function _validate_agent_template_options(
    options::NamedTuple,
)
    option_names =
        keys(
            options,
        )

    conflicts =
        Symbol[
            option_name
            for option_name in _AGENT_TEMPLATE_RESERVED_OPTION_NAMES
            if option_name in option_names
        ]

    isempty(
        conflicts,
    ) || throw(ArgumentError(
        "AgentTemplate options cannot contain reserved builder keyword(s): " *
        join(
            string.(
                conflicts,
            ),
            ", ",
        ) *
        ".",
    ))

    return options
end


"""
    AgentTemplate(
        agent,
        spec;
        periods,
        demands=CommodityRef[],
        outputs=CommodityRef[],
        endowments=Pair[],
        claim=nothing,
        kwargs...,
    )

Describe a repeated family of structurally identical GEMB agents.

`agent` is a base `Symbol` or `AgentRef` without a `:period` selector.
`periods` is required and identifies the concrete periods for which one agent
instance is generated.

`RelativePeriod` may be used inside CommodityRef selectors. `ByPeriod` may be
used in behavior options and endowment quantities. Both are materialized while
the template is expanded into concrete agents.

Use ordinary `add_agent!` for exactly one concrete dated agent.
"""
struct AgentTemplate{
    S,
    O<:NamedTuple,
}
    agent::AgentRef
    spec::S
    periods::Vector{Int}
    demands::Vector{CommodityRef}
    outputs::Vector{CommodityRef}
    endowments::Vector{Pair{CommodityRef,Any}}
    claim::Union{Nothing,CommodityRef}
    options::O
end


function AgentTemplate(
    agent,
    spec;
    periods,
    demands=CommodityRef[],
    outputs=CommodityRef[],
    endowments=Pair[],
    claim=nothing,
    kwargs...,
)
    agent_ref =
        _normalize_agent_template_identity(
            agent,
        )

    :period in keys(
        agent_ref.selectors,
    ) &&
        throw(ArgumentError(
            "AgentTemplate base AgentRef cannot contain a :period selector. " *
            "Use ordinary add_agent! for one concrete dated agent.",
        ))

    normalized_periods =
        _normalize_agent_template_periods(
            periods,
        )

    demand_refs =
        _normalize_agent_template_refs(
            demands,
            "demands",
        )

    output_refs =
        _normalize_agent_template_refs(
            outputs,
            "outputs",
        )

    normalized_endowments =
        _normalize_agent_template_endowments(
            endowments,
        )

    if claim !== nothing &&
       !(claim isa CommodityRef)
        throw(ArgumentError(
            "claim must be nothing or a CommodityRef.",
        ))
    end

    options =
        _validate_agent_template_options(
            (; kwargs...),
        )

    return AgentTemplate(
        agent_ref,
        spec,
        normalized_periods,
        demand_refs,
        output_refs,
        normalized_endowments,
        claim,
        options,
    )
end


export AgentTemplate
