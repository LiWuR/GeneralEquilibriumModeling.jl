# ================================================================
# marshall_demand_consumer_builder_v1.jl
#
# Direct builder for MarshallDemandConsumerSpec.
#
# This file is included directly into module GEMB.
# ================================================================

using ..GEM:
    NetSupplyAgent

export build_agent

function _call_demand_function(demand_function, income, prices, observed_values)
    if applicable(demand_function, income, prices, observed_values)
        return demand_function(income, prices, observed_values)
    elseif applicable(demand_function, income, prices)
        return demand_function(income, prices)
    end
    throw(ArgumentError(
        "demand_function must accept (income, prices) or " *
        "(income, prices, observed_values).",
    ))
end

function build_agent(
    spec::MarshallDemandConsumerSpec;
    output_indices=Int[],
    demand_indices=Int[],
    endowment_indices=Int[],
    endowment_quantities=nothing,
    observed_variables=Any[],
    name::Symbol=:agent,
)
    outputs = _normalize_indices(
        output_indices,
        "output_indices";
        allow_empty=true,
    )
    isempty(outputs) || throw(ArgumentError(
        "MarshallDemandConsumerSpec requires output_indices to be empty.",
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

    isempty(demands) && throw(ArgumentError(
        "MarshallDemandConsumerSpec requires demand_indices.",
    ))

    demand_function = spec.demand_function
    local_indices = unique(vcat(demands, endowments))
    demand_positions = _local_positions(local_indices, demands)
    endowment_positions = _local_positions(local_indices, endowments)

    net_supply_function = function (
        local_variables,
        local_prices,
        observed_values=Any[],
    )
        T = eltype(local_prices)
        supply = [zero(T) for _ in local_indices]

        for k in eachindex(endowment_positions)
            supply[endowment_positions[k]] += quantities[k]
        end

        income = sum(
            local_prices[endowment_positions[k]] * quantities[k]
            for k in eachindex(endowment_positions)
        )

        demand = _call_demand_function(
            demand_function,
            income,
            local_prices[demand_positions],
            observed_values,
        )
        demand isa AbstractVector || throw(ArgumentError(
            "demand_function must return a vector.",
        ))
        length(demand) == length(demand_positions) || throw(DimensionMismatch(
            "Demand length does not match demand_indices.",
        ))

        for k in eachindex(demand_positions)
            supply[demand_positions[k]] -= demand[k]
        end

        return supply
    end

    return NetSupplyAgent(
        local_indices,
        net_supply_function;
        variable_names=Symbol[],
        observed_variables=observed,
        name=name,
    )
end
