# ================================================================
# agent_template_expansion_v2.jl
#
# Final AgentTemplate -> add_agents! expansion after STEP 7C2.
#
# Responsibilities:
#
#   - one concrete AgentRef per template period;
#   - ByPeriod option/endowment materialization;
#   - RelativePeriod CommodityRef materialization through ordinary add_agent!;
#   - endowment scalar/vector expansion;
#   - transactional rollback;
#   - period-domain validation derived from CommoditySpace.
# ================================================================


function _expand_agent_template_endowment_quantity(
    raw_quantity,
    count::Integer,
)
    count >= 1 ||
        throw(ArgumentError(
            "An endowment CommodityRef must resolve to at least one commodity.",
        ))

    quantities =
        if raw_quantity isa Real
            fill(
                Float64(
                    raw_quantity,
                ),
                count,
            )
        elseif raw_quantity isa AbstractVector
            length(
                raw_quantity,
            ) == count || throw(DimensionMismatch(
                "Endowment quantity vector length must equal the number of " *
                "commodities selected by its CommodityRef.",
            ))

            Float64.(
                raw_quantity,
            )
        else
            throw(ArgumentError(
                "Endowment quantity must materialize to a real scalar or a real vector.",
            ))
        end

    all(
        isfinite,
        quantities,
    ) || throw(ArgumentError(
        "Endowment quantities must be finite.",
    ))

    return quantities
end


function _materialize_agent_template_endowment_ref(
    ref::CommodityRef,
    agent_ref::Union{Nothing,AgentRef},
)
    if agent_ref === nothing
        for selector_name in keys(
            ref.selectors,
        )
            selector_value =
                getproperty(
                    ref.selectors,
                    selector_name,
                )

            selector_value isa RelativePeriod &&
                throw(ArgumentError(
                    "An endowment CommodityRef containing RelativePeriod " *
                    "requires a concrete agent_ref context.",
                ))
        end

        return ref
    end

    return _materialize_commodity_ref(
        agent_ref,
        ref,
    )
end


function _materialize_agent_template_endowments(
    model::GEMBModel,
    endowments::AbstractVector{<:Pair};
    agent_ref::Union{Nothing,AgentRef}=nothing,
    period=nothing,
    template_position=nothing,
    template_periods=nothing,
)
    refs =
        CommodityRef[]

    quantities =
        Float64[]

    for entry in endowments
        ref =
            first(
                entry,
            )

        raw_quantity =
            _materialize_template_value(
                last(
                    entry,
                );
                period=period,
                position=template_position,
                periods=template_periods,
            )

        ref isa CommodityRef ||
            throw(ArgumentError(
                "Endowment references must be CommodityRef objects.",
            ))

        absolute_ref =
            _materialize_agent_template_endowment_ref(
                ref,
                agent_ref,
            )

        concrete_indices =
            _resolve_commodity_ref(
                model.commodity_space,
                absolute_ref,
            )

        expanded_quantities =
            _expand_agent_template_endowment_quantity(
                raw_quantity,
                length(
                    concrete_indices,
                ),
            )

        push!(
            refs,
            absolute_ref,
        )

        append!(
            quantities,
            expanded_quantities,
        )
    end

    _resolve_commodities(
        model,
        refs,
    )

    return refs, quantities
end


function _materialize_agent_template_options(
    options::NamedTuple;
    period,
    template_position,
    template_periods,
)
    pairs =
        Pair{Symbol,Any}[]

    for option_name in keys(
        options,
    )
        raw_value =
            getproperty(
                options,
                option_name,
            )

        concrete_value =
            _materialize_template_value(
                raw_value;
                period=period,
                position=template_position,
                periods=template_periods,
            )

        push!(
            pairs,
            option_name =>
                concrete_value,
        )
    end

    return (; pairs...)
end


function _agent_template_identity(
    template::AgentTemplate,
    period::Integer,
)
    return AgentRef(
        template.agent.name;
        template.agent.selectors...,
        period=Int(
            period,
        ),
    )
end


function _restore_gemb_agent_state!(
    model::GEMBModel,
    original_count::Integer,
)
    0 <= original_count <= length(
        model.agents,
    ) || throw(ArgumentError(
        "Invalid GEMBModel agent rollback count.",
    ))

    resize!(
        model.agents,
        original_count,
    )

    resize!(
        model.agent_refs,
        original_count,
    )

    empty!(
        model.agent_index,
    )

    empty!(
        model.agent_ref_index,
    )

    for position in eachindex(
        model.agents,
    )
        flat_name =
            GEM.agent_name(
                model.agents[
                    position
                ],
            )

        ref =
            model.agent_refs[
                position
            ]

        model.agent_index[
            flat_name
        ] =
            position

        model.agent_ref_index[
            ref
        ] =
            position
    end

    return model
end


function _agent_template_period_domain(
    model::GEMBModel,
)
    periods =
        Int[]

    for commodity_spec in model.commodity_space.specs
        :period in keys(
            commodity_spec.axes,
        ) ||
            continue

        raw_periods =
            getproperty(
                commodity_spec.axes,
                :period,
            )

        for raw_period in raw_periods
            raw_period isa Integer &&
            !(raw_period isa Bool) ||
                throw(ArgumentError(
                    "CommoditySpec :period axis values must be integers.",
                ))

            period =
                Int(
                    raw_period,
                )

            period >= 1 ||
                throw(ArgumentError(
                    "CommoditySpec :period axis values must be positive.",
                ))

            push!(
                periods,
                period,
            )
        end
    end

    sort!(
        unique!(
            periods,
        ),
    )

    return periods
end


function _validate_agent_template_period_domain(
    template::AgentTemplate,
    period_domain::AbstractVector{<:Integer},
)
    isempty(
        period_domain,
    ) &&
        throw(ArgumentError(
            "AgentTemplate cannot be added to a GEMBModel whose CommoditySpace " *
            "has no :period axis.",
        ))

    all(
        period ->
            period in period_domain,
        template.periods,
    ) || throw(ArgumentError(
        "AgentTemplate $(repr(template.agent)) has periods outside the " *
        "GEMBModel period domain $(collect(period_domain)).",
    ))

    return nothing
end


function _validate_agent_template_period_domain(
    templates::AbstractVector{<:AgentTemplate},
    period_domain::AbstractVector{<:Integer},
)
    for template in templates
        _validate_agent_template_period_domain(
            template,
            period_domain,
        )
    end

    return nothing
end


function _add_agent_template_instance!(
    model::GEMBModel,
    template::AgentTemplate,
    period::Integer,
    template_position::Integer,
)
    agent_ref =
        _agent_template_identity(
            template,
            period,
        )

    endowment_refs,
    endowment_quantities =
        _materialize_agent_template_endowments(
            model,
            template.endowments;
            agent_ref=agent_ref,
            period=period,
            template_position=template_position,
            template_periods=template.periods,
        )

    materialized_options =
        _materialize_agent_template_options(
            template.options;
            period=period,
            template_position=template_position,
            template_periods=template.periods,
        )

    structural_keywords =
        Pair{Symbol,Any}[]

    !isempty(
        template.demands,
    ) &&
        push!(
            structural_keywords,
            :demands =>
                template.demands,
        )

    !isempty(
        template.outputs,
    ) &&
        push!(
            structural_keywords,
            :outputs =>
                template.outputs,
        )

    if !isempty(
        endowment_refs,
    )
        push!(
            structural_keywords,
            :endowments =>
                endowment_refs,
        )

        push!(
            structural_keywords,
            :endowment_quantities =>
                endowment_quantities,
        )
    end

    template.claim !== nothing &&
        push!(
            structural_keywords,
            :claim =>
                template.claim,
        )

    high_level_keywords =
        merge(
            (; structural_keywords...),
            materialized_options,
            (
                name=agent_ref,
            ),
        )

    return add_agent!(
        model,
        template.spec;
        high_level_keywords...,
    )
end


function _add_agent_template!(
    model::GEMBModel,
    template::AgentTemplate,
)
    original_count =
        length(
            model.agents,
        )

    added =
        GEM.AbstractNetSupplyAgent[]

    try
        for (
            template_position,
            period,
        ) in enumerate(
            template.periods,
        )
            push!(
                added,
                _add_agent_template_instance!(
                    model,
                    template,
                    period,
                    template_position,
                ),
            )
        end
    catch
        _restore_gemb_agent_state!(
            model,
            original_count,
        )

        rethrow()
    end

    return added
end


"""
    add_agents!(
        model::GEMBModel,
        template::AgentTemplate,
    )

Expand one `AgentTemplate` into concrete agents and add them to `model`.

Every template period is validated before mutation. `RelativePeriod`
CommodityRef values are resolved inside ordinary `add_agent!`; `ByPeriod`
values are materialized for the current template instance.
"""
function add_agents!(
    model::GEMBModel,
    template::AgentTemplate,
)
    period_domain =
        _agent_template_period_domain(
            model,
        )

    _validate_agent_template_period_domain(
        template,
        period_domain,
    )

    return _add_agent_template!(
        model,
        template,
    )
end


"""
    add_agents!(
        model::GEMBModel,
        templates::AbstractVector{<:AgentTemplate},
    )

Expand several `AgentTemplate` objects transactionally.

All period-domain checks are completed before mutation. If any construction
fails, the full batch is rolled back.
"""
function add_agents!(
    model::GEMBModel,
    templates::AbstractVector{<:AgentTemplate},
)
    period_domain =
        _agent_template_period_domain(
            model,
        )

    _validate_agent_template_period_domain(
        templates,
        period_domain,
    )

    original_count =
        length(
            model.agents,
        )

    added =
        GEM.AbstractNetSupplyAgent[]

    try
        for template in templates
            append!(
                added,
                _add_agent_template!(
                    model,
                    template,
                ),
            )
        end
    catch
        _restore_gemb_agent_state!(
            model,
            original_count,
        )

        rethrow()
    end

    return added
end


export add_agents!
