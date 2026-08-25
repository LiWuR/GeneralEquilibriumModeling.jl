# ================================================================
# marginal_utility_consumer_builder_v1.jl
#
# Builder for MarginalUtilityConsumerSpec and adapters for GEM concrete
# AbstractMarginalUtilitySpec types.
#
# This file is included directly into module GEMB.
# ================================================================

using GEM:
    NetSupplyAgent,
    MarginalUtilityConsumerConditions

export build_agent

function build_agent(
    spec::MarginalUtilityConsumerSpec;
    output_indices=Int[],
    demand_indices=Int[],
    endowment_indices=Int[],
    endowment_quantities=nothing,
    demand_start=100.0,
    demand_lower_bounds=0.0,
    demand_upper_bounds=Inf,
    multiplier_start::Real=1.0,
    multiplier_lower_bound::Real=0.0,
    multiplier_upper_bound::Real=Inf,
    observed_variables=Any[],
    name::Symbol=:agent,
)
    outputs = _normalize_indices(
        output_indices,
        "output_indices";
        allow_empty=true,
    )
    isempty(outputs) || throw(ArgumentError(
        "MarginalUtilityConsumerSpec requires output_indices to be empty.",
    ))

    demands = _normalize_indices(
        demand_indices,
        "demand_indices";
        allow_empty=true,
    )
    endowments = _normalize_indices(
        endowment_indices,
        "endowment_indices";
        allow_empty=true,
    )
    quantities = _normalize_endowment_quantities(
        endowments,
        endowment_quantities,
    )
    observed = _normalize_observed_variables(observed_variables)

    marginal_function = spec.marginal_function

    isempty(demands) && throw(ArgumentError(
        "MarginalUtilityConsumerSpec requires demand_indices.",
    ))

    checked = _check_marginal_arguments(
        marginal_function,
        demands,
        demand_start,
        demand_lower_bounds,
        demand_upper_bounds,
        multiplier_start,
        multiplier_lower_bound,
        multiplier_upper_bound,
        observed,
    )
    starts = checked.starts
    lower = checked.lower
    upper = checked.upper

    local_indices = unique(vcat(demands, endowments))
    demand_price_positions = _local_positions(local_indices, demands)
    endowment_positions = _local_positions(local_indices, endowments)
    demand_variable_positions = collect(1:length(demands))
    multiplier_position = length(demands) + 1

    net_supply_function = function (
        local_variables,
        local_prices,
        observed_values=Any[],
    )
        T = promote_type(eltype(local_variables), eltype(local_prices))
        supply = [zero(T) for _ in local_indices]

        for k in eachindex(endowment_positions)
            supply[endowment_positions[k]] += quantities[k]
        end

        for k in eachindex(demand_price_positions)
            supply[demand_price_positions[k]] -= local_variables[k]
        end

        return supply
    end

    rule = MarginalUtilityConsumerConditions(
        marginal_function,
        demand_variable_positions,
        demand_price_positions,
        multiplier_position,
    )

    return NetSupplyAgent(
        local_indices,
        net_supply_function;
        variable_names=vcat(
            [Symbol(:demand_, commodity) for commodity in demands],
            [:budget_multiplier],
        ),
        variable_lower_bounds=vcat(lower, [multiplier_lower_bound]),
        variable_upper_bounds=vcat(upper, [multiplier_upper_bound]),
        variable_start=vcat(starts, [Float64(multiplier_start)]),
        observed_variables=observed,
        condition_rule=rule,
        name=name,
    )
end

# GEM already supplies a family of concrete marginal-utility specifications.
# Adapt them to the direct GEMB consumer method without duplicating the
# construction implementation.
function build_agent(spec::AbstractMarginalUtilitySpec; kwargs...)
    return build_agent(
        MarginalUtilityConsumerSpec(marginal_utility_function(spec));
        kwargs...,
    )
end
