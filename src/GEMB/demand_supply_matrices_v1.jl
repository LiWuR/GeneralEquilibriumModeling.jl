# ================================================================
# demand_supply_matrices_v1.jl
#
# Model-wide gross-demand / gross-supply matrices for the GEMB
# high-level framework.
#
# Core design:
#
#   1. The arbitrary-state method is the primary implementation.
#   2. Each agent is evaluated through the existing `demand_supply` API.
#   3. Local vectors are scattered into the global commodity space.
#   4. The equilibrium-result method is only a convenience wrapper.
#
# Existing GEM net-supply functions and solver paths are not modified.
# ================================================================

export demand_supply_matrices


# ----------------------------------------------------------------
# State validation
# ----------------------------------------------------------------

function _demand_supply_matrix_observed_values(
    model::GEMBModel,
    observed_values,
)
    n_agents =
        length(model.agents)

    if observed_values === nothing
        counts =
            [
                GEM.agent_observed_variable_count(agent)
                for agent in model.agents
            ]

        all(iszero, counts) || throw(ArgumentError(
            "observed_values must be supplied because at least one agent " *
            "declares observed equilibrium variables.",
        ))

        return [
            Any[]
            for _ in 1:n_agents
        ]
    end

    length(observed_values) == n_agents || throw(DimensionMismatch(
        "observed_values contains $(length(observed_values)) agent vector(s), " *
        "but GEMBModel contains $(n_agents) agents.",
    ))

    for j in eachindex(model.agents)
        expected =
            GEM.agent_observed_variable_count(
                model.agents[j],
            )

        actual =
            length(observed_values[j])

        actual == expected || throw(DimensionMismatch(
            "Agent $(repr(model.agent_refs[j])) received $(actual) observed " *
            "value(s), but declares $(expected).",
        ))
    end

    return observed_values
end


function _check_demand_supply_matrix_state(
    model::GEMBModel,
    agent_variable_values,
    prices,
)
    n_agents =
        length(model.agents)

    length(model.agent_refs) == n_agents ||
        error("Internal GEMB agent_refs registry is misaligned.")

    length(model.agent_records) == n_agents ||
        error("Internal GEMB agent_records registry is misaligned.")

    length(agent_variable_values) == n_agents ||
        throw(DimensionMismatch(
            "agent_variable_values contains $(length(agent_variable_values)) " *
            "agent vector(s), but GEMBModel contains $(n_agents) agents.",
        ))

    n_commodities =
        length(model.commodity_names)

    length(prices) == n_commodities ||
        throw(DimensionMismatch(
            "prices contains $(length(prices)) value(s), but GEMBModel " *
            "contains $(n_commodities) commodities.",
        ))

    return nothing
end


# ----------------------------------------------------------------
# Global matrix assembly
# ----------------------------------------------------------------

function _assemble_demand_supply_matrices(
    model::GEMBModel,
    local_results,
)
    n_agents =
        length(model.agents)

    n_commodities =
        length(model.commodity_names)

    length(local_results) == n_agents ||
        error("Internal GEMB local demand/supply result count is misaligned.")

    if isempty(local_results)
        T = Float64
    else
        T =
            promote_type(
                (
                    promote_type(
                        eltype(local_result.demand),
                        eltype(local_result.supply),
                        eltype(local_result.net_supply),
                    )
                    for local_result in local_results
                )...,
            )
    end

    D =
        zeros(
            T,
            n_commodities,
            n_agents,
        )

    S =
        zeros(
            T,
            n_commodities,
            n_agents,
        )

    N =
        zeros(
            T,
            n_commodities,
            n_agents,
        )

    for j in eachindex(model.agents)
        agent =
            model.agents[j]

        commodity_indices =
            GEM.agent_commodity_indices(
                agent,
            )

        local_result =
            local_results[j]

        local_length =
            length(commodity_indices)

        for (name, values) in (
            (:demand, local_result.demand),
            (:supply, local_result.supply),
            (:net_supply, local_result.net_supply),
        )
            length(values) == local_length || throw(DimensionMismatch(
                "Agent $(repr(model.agent_refs[j])) has $(local_length) local " *
                "commodities, but its $(name) vector has length " *
                "$(length(values)).",
            ))
        end

        for k in eachindex(commodity_indices)
            commodity_index =
                commodity_indices[k]

            1 <= commodity_index <= n_commodities || throw(BoundsError(
                model.commodity_names,
                commodity_index,
            ))

            D[commodity_index, j] =
                local_result.demand[k]

            S[commodity_index, j] =
                local_result.supply[k]

            N[commodity_index, j] =
                local_result.net_supply[k]
        end
    end

    isapprox(
        S - D,
        N;
        atol=1.0e-10,
        rtol=1.0e-8,
    ) || error(
        "Internal GEMB demand/supply matrix identity failed: S - D != N.",
    )

    return (
        demand=D,
        supply=S,
        net_supply=N,
    )
end


# ----------------------------------------------------------------
# Public arbitrary-state interface
# ----------------------------------------------------------------

# demand_supply_matrices(
#     model::GEMBModel,
#     agent_variable_values,
#     prices;
#     observed_values=nothing,
# )
#
# Evaluate model-wide gross demand, gross supply, and net supply at an
# arbitrary state.
#
# `agent_variable_values[j]` must use the local endogenous-variable ordering
# of `model.agents[j]`.
#
# `prices` is the full global commodity-price vector in
# `model.commodity_names` order.
#
# `observed_values`, when supplied, is a vector of local observed-value
# vectors aligned with `model.agents`. It may be omitted only when every
# agent declares zero observed variables.
#
# Returned matrix rows follow `model.commodity_names`; columns follow
# `model.agents` and `model.agent_refs`.
function demand_supply_matrices(
    model::GEMBModel,
    agent_variable_values,
    prices;
    observed_values=nothing,
)
    _check_demand_supply_matrix_state(
        model,
        agent_variable_values,
        prices,
    )

    agent_observed_values =
        _demand_supply_matrix_observed_values(
            model,
            observed_values,
        )

    local_results =
        Vector{Any}(
            undef,
            length(model.agents),
        )

    for j in eachindex(model.agents)
        agent =
            model.agents[j]

        commodity_indices =
            GEM.agent_commodity_indices(
                agent,
            )

        local_prices =
            prices[commodity_indices]

        local_results[j] =
            demand_supply(
                model,
                model.agent_refs[j],
                agent_variable_values[j],
                local_prices;
                observed_values=agent_observed_values[j],
            )
    end

    return _assemble_demand_supply_matrices(
        model,
        local_results,
    )
end


# ----------------------------------------------------------------
# Equilibrium-result convenience interface
# ----------------------------------------------------------------

function _result_observed_values_for_demand_supply(
    model::GEMBModel,
    result::GEM.EquilibriumResult,
)
    if hasproperty(
        result,
        :observed_variable_values,
    )
        return result.observed_variable_values
    end

    counts =
        [
            GEM.agent_observed_variable_count(agent)
            for agent in model.agents
        ]

    all(iszero, counts) || throw(ArgumentError(
        "Equilibrium result does not contain observed_variable_values, but " *
        "at least one agent declares observed equilibrium variables.",
    ))

    return nothing
end


function _check_result_net_supply_consistency(
    model::GEMBModel,
    matrices,
    result::GEM.EquilibriumResult,
)
    hasproperty(
        result,
        :agent_net_supplies,
    ) || return nothing

    stored =
        net_supply_matrix(
            model,
            result,
        )

    isapprox(
        matrices.net_supply,
        stored;
        atol=1.0e-10,
        rtol=1.0e-8,
    ) || throw(ArgumentError(
        "Re-evaluated net-supply matrix is inconsistent with the equilibrium " *
        "result's stored agent net supplies.",
    ))

    return nothing
end


# demand_supply_matrices(
#     model::GEMBModel,
#     result::GEM.EquilibriumResult,
# )
#
# Convenience method that re-evaluates gross demand and gross supply at the
# equilibrium state stored in `result`.
#
# The method extracts:
#
#   result.prices
#   result.agent_variable_values
#   result.observed_variable_values
#
# and delegates to the arbitrary-state method.
#
# If the result also contains stored agent net supplies, the re-evaluated
# net-supply matrix is checked against `net_supply_matrix(model, result)`.
function demand_supply_matrices(
    model::GEMBModel,
    result::GEM.EquilibriumResult,
)
    hasproperty(
        result,
        :prices,
    ) || throw(ArgumentError(
        "Equilibrium result does not contain prices.",
    ))

    hasproperty(
        result,
        :agent_variable_values,
    ) || throw(ArgumentError(
        "Equilibrium result does not contain agent_variable_values.",
    ))

    observed_values =
        _result_observed_values_for_demand_supply(
            model,
            result,
        )

    matrices =
        demand_supply_matrices(
            model,
            result.agent_variable_values,
            result.prices;
            observed_values=observed_values,
        )

    _check_result_net_supply_consistency(
        model,
        matrices,
        result,
    )

    return matrices
end
