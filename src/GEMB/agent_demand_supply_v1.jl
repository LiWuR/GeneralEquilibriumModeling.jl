# ================================================================
# agent_demand_supply_v1.jl
#
# Gross-demand / gross-supply evaluation for GEMB high-level agents.
#
# This analytical layer is deliberately separate from GEM's computational
# net-supply layer. Existing NetSupplyAgent closures and solver paths are not
# modified.
# ================================================================

export demand_supply


# ----------------------------------------------------------------
# Agent lookup
# ----------------------------------------------------------------

function _demand_supply_agent_position(
    model::GEMBModel,
    agent_ref::AgentRef,
)
    position = get(
        model.agent_ref_index,
        agent_ref,
        0,
    )

    position != 0 || throw(ArgumentError(
        "Unknown AgentRef $(repr(agent_ref)) in GEMBModel.",
    ))

    return position
end


function _demand_supply_agent_position(
    model::GEMBModel,
    name::Symbol,
)
    position = get(
        model.agent_index,
        name,
        0,
    )

    position != 0 || throw(ArgumentError(
        "Unknown agent name $(repr(name)) in GEMBModel.",
    ))

    return position
end


# ----------------------------------------------------------------
# Small helpers
# ----------------------------------------------------------------

function _record_keyword(
    record::ActivityDemandAgentRecord,
    key::Symbol,
    default=nothing,
)
    return key in keys(record.build_kwargs) ?
        getproperty(record.build_kwargs, key) :
        default
end


function _checked_activity_state(
    agent::GEM.AbstractNetSupplyAgent,
    local_variables,
    local_prices,
)
    variable_count =
        GEM.agent_variable_count(agent)

    length(local_variables) == variable_count || throw(DimensionMismatch(
        "Agent $(GEM.agent_name(agent)) received $(length(local_variables)) " *
        "local variable value(s), but declares $(variable_count).",
    ))

    variable_count >= 1 || throw(ArgumentError(
        "Activity-demand agent $(GEM.agent_name(agent)) must declare an " *
        "activity variable.",
    ))

    local_indices =
        GEM.agent_commodity_indices(agent)

    length(local_prices) == length(local_indices) || throw(DimensionMismatch(
        "Agent $(GEM.agent_name(agent)) received $(length(local_prices)) " *
        "local price value(s), but uses $(length(local_indices)) commodities.",
    ))

    return local_indices
end


# ----------------------------------------------------------------
# Gross demand for Activity-demand records
# ----------------------------------------------------------------

function _activity_agent_gross_demand(
    record::ActivityDemandAgentRecord,
    agent::GEM.AbstractNetSupplyAgent,
    local_variables,
    local_prices,
    observed_values,
)
    local_indices =
        _checked_activity_state(
            agent,
            local_variables,
            local_prices,
        )

    activity =
        local_variables[1]

    demand_positions =
        _local_positions(
            local_indices,
            record.demand_indices,
        )

    demand_prices =
        local_prices[demand_positions]

    is_producer =
        !isempty(record.output_indices)

    base_demand =
        if is_producer
            # Match the existing builder exactly, including the displaced-DCES
            # shutdown convention at activity == 0.
            _producer_activity_demand(
                record.spec,
                activity,
                demand_prices,
                observed_values,
            )
        else
            activity_demand(
                record.spec,
                activity,
                demand_prices,
                observed_values,
            )
        end

    base_demand isa AbstractVector || throw(ArgumentError(
        "Activity-demand specification for agent $(GEM.agent_name(agent)) " *
        "must return a vector.",
    ))

    length(base_demand) == length(demand_positions) ||
        throw(DimensionMismatch(
            "Activity-demand specification for agent $(GEM.agent_name(agent)) " *
            "returned $(length(base_demand)) demand value(s), but the agent " *
            "has $(length(demand_positions)) ordinary demand commodities.",
        ))

    # Use a promoted numeric type so ordinary and claim demands can coexist
    # without forcing Float64.
    T =
        promote_type(
            eltype(local_variables),
            eltype(local_prices),
            eltype(base_demand),
        )

    demand =
        [zero(T) for _ in local_indices]

    for k in eachindex(demand_positions)
        demand[demand_positions[k]] +=
            base_demand[k]
    end

    # Reconstruct the current private claim-rate modifier through the same
    # normalization helper used by the builder. If no claim_rate was supplied,
    # this is an exact no-op.
    claim_rate =
        _record_keyword(
            record,
            :claim_rate,
            nothing,
        )

    modifier, normalized_claim_index =
        _normalize_demand_modifier(
            claim_rate,
            record.claim_index,
            record.demand_indices,
            record.output_indices,
        )

    if modifier !== nothing
        claim_position =
            _local_positions(
                local_indices,
                [normalized_claim_index],
            )[1]

        claim_quantity =
            _claim_quantity(
                modifier,
                base_demand,
                demand_prices,
                local_prices[claim_position],
            )

        demand[claim_position] +=
            claim_quantity
    end

    return demand
end


# ----------------------------------------------------------------
# Record dispatch
# ----------------------------------------------------------------

function _agent_gross_demand(
    record::ActivityDemandAgentRecord,
    agent::GEM.AbstractNetSupplyAgent,
    local_variables,
    local_prices,
    observed_values,
)
    return _activity_agent_gross_demand(
        record,
        agent,
        local_variables,
        local_prices,
        observed_values,
    )
end


function _agent_gross_demand(
    ::NetSupplyOnlyAgentRecord,
    agent::GEM.AbstractNetSupplyAgent,
    local_variables,
    local_prices,
    observed_values,
)
    throw(ArgumentError(
        "Gross demand and gross supply are unavailable for agent " *
        "$(GEM.agent_name(agent)) because GEMB retains only its net-supply " *
        "representation.",
    ))
end


# ----------------------------------------------------------------
# Public API
# ----------------------------------------------------------------

#     demand_supply(
#         model::GEMBModel,
#         agent_ref::Union{AgentRef,Symbol},
#         local_variables,
#         local_prices;
#         observed_values=Any[],
#     )
#
# Evaluate one high-level agent's gross demand, gross supply, and net supply at
# an arbitrary local state.
#
# `local_variables` and `local_prices` must use the same local ordering as the
# underlying GEM agent. `observed_values`, when required, must follow the
# agent's declared observed-variable ordering.
#
# For an Activity-demand agent, gross demand is evaluated from its retained
# economic record. Net supply is evaluated by the existing
# `GEM.agent_net_supply` implementation. Gross supply is then recovered from
#
#     supply = net_supply + demand.
#
# The result is a named tuple with fields `demand`, `supply`, and `net_supply`.
#
# Agents represented only by `NetSupplyOnlyAgentRecord` do not have a uniquely
# retained gross-demand/gross-supply decomposition and therefore raise an
# `ArgumentError`.
function demand_supply(
    model::GEMBModel,
    agent_ref::Union{AgentRef,Symbol},
    local_variables,
    local_prices;
    observed_values=Any[],
)
    position =
        _demand_supply_agent_position(
            model,
            agent_ref,
        )

    1 <= position <= length(model.agents) ||
        error("Internal GEMB agent registry position is out of range.")

    position <= length(model.agent_records) ||
        error("Internal GEMB agent registry is misaligned with agent_records.")

    agent =
        model.agents[position]

    record =
        model.agent_records[position]

    demand =
        _agent_gross_demand(
            record,
            agent,
            local_variables,
            local_prices,
            observed_values,
        )

    # Preserve the existing computational representation exactly.
    net_supply =
        GEM.agent_net_supply(
            agent,
            local_variables,
            local_prices,
            observed_values,
        )

    length(demand) == length(net_supply) ||
        error(
            "Internal GEMB demand/net-supply dimension mismatch for agent " *
            "$(GEM.agent_name(agent)).",
        )

    supply =
        net_supply .+ demand

    return (
        demand=demand,
        supply=supply,
        net_supply=net_supply,
    )
end
