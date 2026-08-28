# ================================================================
# activity_demand_agent_builder_v6.jl
#
# Activity-demand protocol and the unified builder for activity-demand
# agents. The same path constructs producers when outputs are present and
# utility/activity consumers when outputs are absent.
#
# This file is included directly into module GEMB.
# ================================================================

using ..GEM:
    ExplicitAgentConditions,
    UnitRevenueExpenditureBalanceConditions,
    TotalRevenueExpenditureBalanceConditions,
    NetSupplyAgent

export build_agent

function _check_activity_demand_dimension(
    spec::ActivityDemandSpec,
    demand_count,
    activity_start,
    observed_variables,
)
    probe_prices = ones(Float64, demand_count)
    probe_observed = zeros(Float64, length(observed_variables))
    demand = activity_demand(
        spec,
        Float64(activity_start),
        probe_prices,
        probe_observed,
    )
    demand isa AbstractVector || throw(ArgumentError(
        "ActivityDemandSpec demand_function must return a vector.",
    ))
    length(demand) == demand_count || throw(DimensionMismatch(
        "ActivityDemandSpec demand_function output length must equal " *
        "demand_indices length.",
    ))
    all(x -> x isa Real && isfinite(x), demand) || throw(ArgumentError(
        "ActivityDemandSpec demand_function must return a finite real vector " *
        "at activity_start and unit prices.",
    ))
    return nothing
end

function _check_activity_demand_dimension(
    spec::CESSpec,
    demand_count,
    activity_start,
    observed_variables,
)
    demand_count == length(spec.beta) || throw(DimensionMismatch(
        "demand_indices length must equal spec.beta length.",
    ))
    return nothing
end

function _check_activity_demand_dimension(
    spec::DCESSpec,
    demand_count,
    activity_start,
    observed_variables,
)
    demand_count == length(spec.beta) || throw(DimensionMismatch(
        "demand_indices length must equal spec.beta length.",
    ))
    return nothing
end

function _check_activity_demand_dimension(
    spec::PowerProductionSpec,
    demand_count,
    activity_start,
    observed_variables,
)
    demand_count == 1 || throw(DimensionMismatch(
        "PowerProductionSpec requires exactly one demand_index.",
    ))
    return nothing
end

function _producer_activity_demand(
    spec::AbstractActivityDemandSpec,
    activity,
    prices,
    observed_values,
)
    return activity_demand(spec, activity, prices, observed_values)
end

# A displaced CES technology contains fixed input requirements. Preserve the
# V9 shutdown convention: fixed requirements are not demanded when production
# activity is exactly zero.
function _producer_activity_demand(
    spec::DCESSpec,
    activity,
    prices,
    observed_values,
)
    if all(iszero, spec.xi) || !iszero(activity)
        return activity_demand(spec, activity, prices, observed_values)
    end
    return [zero(activity) for _ in spec.beta]
end

# ----------------------------------------------------------------
# Activity-supply helpers
# ----------------------------------------------------------------

function _check_activity_supply_dimension(
    spec::AbstractActivitySupplySpec,
    output_count,
    activity_start,
    observed_variables,
)
    probe_prices = ones(Float64, output_count)
    probe_observed = zeros(Float64, length(observed_variables))
    output = activity_supply(
        spec,
        Float64(activity_start),
        probe_prices,
        probe_observed,
    )
    output isa AbstractVector || throw(ArgumentError(
        "activity_supply must return a vector.",
    ))
    length(output) == output_count || throw(DimensionMismatch(
        "activity_supply output length must equal output_indices length.",
    ))
    all(x -> x isa Real && isfinite(x), output) || throw(ArgumentError(
        "activity_supply must return a finite real vector at activity_start " *
        "and unit output prices.",
    ))
    return nothing
end

function _activity_output_quantities(
    output_spec,
    activity,
    output_prices,
    output_coefficients,
    observed_values,
)
    if output_spec === nothing
        return [
            output_coefficients[k] * activity
            for k in eachindex(output_coefficients)
        ]
    end

    return activity_supply(
        output_spec,
        activity,
        output_prices,
        observed_values,
    )
end

# Activity-demand specifications describe ordinary demand conditional on one
# activity variable. Commodity mappings, endowments, starts/bounds, observed
# variables, and names remain build_agent arguments. If outputs are supplied,
# activity is interpreted as production. If outputs are absent, activity is
# interpreted as consumer utility/welfare and is paired with expenditure minus
# endowment income.

"""
    build_agent(spec::AbstractActivityDemandSpec; ...)

Build a GEM net-supply agent from an activity-demand specification.

The same builder is used for `ActivityDemandSpec`, `CESSpec`, `DCESSpec`,
and `PowerProductionSpec`. Supplying `output_indices` selects the producer
construction;
omitting `output_indices` selects the compensated-demand consumer
construction.

# Producer condition-rule selection

The keyword `condition_rule` controls the complementarity condition paired
with the producer activity variable.

If the user supplies `condition_rule`, that rule is used directly and
always overrides GEMB's default selection.

If `condition_rule=nothing`, GEMB selects the default producer rule in this
order:

1. `ActivityDemandSpec` with `producer_condition_function`
   -> `ExplicitAgentConditions`;
2. `PowerProductionSpec`
   -> `TotalRevenueExpenditureBalanceConditions`;
3. producer with fixed endowments
   -> `TotalRevenueExpenditureBalanceConditions`;
4. `DCESSpec` with any nonzero `xi`
   -> `TotalRevenueExpenditureBalanceConditions`;
5. otherwise
   -> `UnitRevenueExpenditureBalanceConditions`.

`UnitRevenueExpenditureBalanceConditions` constructs the condition for activity `k` from
the value of net supply at the unit vector `e_k`:

    F_k = -p' * s(e_k, p)

`TotalRevenueExpenditureBalanceConditions` keeps the current value `z_k`, sets the other
activity variables to zero, and constructs

    F_k = -p' * s(z^(k), p)

where `z^(k)` has `z_k` in component `k` and zero elsewhere.

The automatic multi-activity `TotalRevenueExpenditureBalanceConditions` construction is most
natural for a separable composite producer whose activities can be
evaluated independently. GEM and GEMB do not test separability.

If activities interact, or if common fixed endowments or other shared
net-supply components require a particular allocation across paired
conditions, the researcher may provide an appropriate explicit condition
rule instead.

GEMB deliberately does not reject economically unusual rule selections.
This allows researchers to compare alternative formulations, including
formulations that may have no equilibrium.

# Consumers

For compensated-demand consumers, GEMB uses
`TotalRevenueExpenditureBalanceConditions` by default. The consumer's
utility/activity variable and its existing bounds are otherwise unchanged.
A user-supplied `condition_rule` still overrides this default.

With the default consumer utility bound `u >= 0`, this condition is represented
as a complementarity relation. It therefore implies exact equality between
total expenditure and total income whenever the equilibrium utility level is
strictly positive. Users should choose or normalize the utility index used by
an activity-demand consumer so that the intended equilibrium utility level is
strictly positive. This is a requirement of the current activity-demand
consumer representation, not a general restriction of utility theory. If a
model may have an equilibrium at zero utility, the default formulation should
be reviewed explicitly.
"""
function build_agent(
    spec::AbstractActivityDemandSpec;
    output_indices=Int[],
    output_coefficients=nothing,
    output_spec=nothing,
    demand_indices=Int[],
    endowment_indices=Int[],
    endowment_quantities=nothing,
    activity_start::Real=100.0,
    activity_lower_bound::Real=0.0,
    activity_upper_bound::Real=Inf,
    claim_rate=nothing,
    claim_index=nothing,
    condition_rule=nothing,
    observed_variables=Any[],
    name::Symbol=:agent,
)
    outputs = _normalize_indices(output_indices, "output_indices"; allow_empty=true)
    demands = _normalize_indices(demand_indices, "demand_indices"; allow_empty=true)
    endowments = _normalize_indices(endowment_indices, "endowment_indices"; allow_empty=true)
    quantities = _normalize_endowment_quantities(endowments, endowment_quantities)
    observed = _normalize_observed_variables(observed_variables)

    coefficients = if output_spec === nothing
        _normalize_output_coefficients(outputs, output_coefficients)
    else
        output_spec isa AbstractActivitySupplySpec || throw(ArgumentError(
            "output_spec must be an AbstractActivitySupplySpec.",
        ))
        output_coefficients === nothing || throw(ArgumentError(
            "output_coefficients and output_spec are mutually exclusive.",
        ))
        Float64[]
    end

    isempty(demands) && throw(ArgumentError(
        "AbstractActivityDemandSpec requires demand_indices.",
    ))
    _check_activity_arguments(
        activity_start,
        activity_lower_bound,
        activity_upper_bound,
    )

    # Validate the demand modifier before checking the base-demand dimension.
    # This preserves the public API contract that demand_indices contain only
    # ordinary base-demand commodities. In particular, if claim_index is also
    # listed in demand_indices, report that mapping error directly instead of
    # first failing a CES/DCES demand-length check.
    modifier, normalized_claim_index = _normalize_demand_modifier(
        claim_rate,
        claim_index,
        demands,
        outputs,
    )

    _check_activity_demand_dimension(
        spec,
        length(demands),
        activity_start,
        observed,
    )

    is_producer = !isempty(outputs)

    if spec isa PowerProductionSpec
        is_producer || throw(ArgumentError(
            "PowerProductionSpec is producer-only and requires output_indices.",
        ))
        activity_lower_bound >= 0 || throw(ArgumentError(
            "PowerProductionSpec requires activity_lower_bound >= 0.",
        ))
    end

    if output_spec !== nothing
        is_producer || throw(ArgumentError(
            "output_spec requires nonempty output_indices.",
        ))
        _check_activity_supply_dimension(
            output_spec,
            length(outputs),
            activity_start,
            observed,
        )
    end

    modifier_indices = modifier === nothing ? Int[] : [normalized_claim_index]
    local_indices = unique(vcat(outputs, demands, modifier_indices, endowments))
    output_positions = _local_positions(local_indices, outputs)
    demand_positions = _local_positions(local_indices, demands)
    endowment_positions = _local_positions(local_indices, endowments)
    claim_position = modifier === nothing ? nothing :
        _local_positions(local_indices, [normalized_claim_index])[1]

    net_supply_function = function (
        local_variables,
        local_prices,
        observed_values=Any[],
    )
        activity = local_variables[1]
        T = promote_type(eltype(local_variables), eltype(local_prices))
        supply = [zero(T) for _ in local_indices]

        for k in eachindex(endowment_positions)
            supply[endowment_positions[k]] += quantities[k]
        end

        if is_producer
            output_quantities = _activity_output_quantities(
                output_spec,
                activity,
                local_prices[output_positions],
                coefficients,
                observed_values,
            )
            output_quantities isa AbstractVector || throw(ArgumentError(
                "activity_supply must return a vector.",
            ))
            length(output_quantities) == length(output_positions) ||
                throw(DimensionMismatch(
                    "activity_supply output length must equal output_indices length.",
                ))

            for k in eachindex(output_positions)
                supply[output_positions[k]] += output_quantities[k]
            end
        end

        demand_prices = local_prices[demand_positions]
        demand_quantities = if is_producer
            _producer_activity_demand(
                spec,
                activity,
                demand_prices,
                observed_values,
            )
        else
            activity_demand(
                spec,
                activity,
                demand_prices,
                observed_values,
            )
        end

        demand_quantities isa AbstractVector || throw(ArgumentError(
            "activity_demand must return a vector.",
        ))
        length(demand_quantities) == length(demand_positions) ||
            throw(DimensionMismatch(
                "activity_demand output length must equal demand_indices length.",
            ))

        for k in eachindex(demand_positions)
            supply[demand_positions[k]] -= demand_quantities[k]
        end

        if modifier !== nothing
            claim_quantity = _claim_quantity(
                modifier,
                demand_quantities,
                demand_prices,
                local_prices[claim_position],
            )
            supply[claim_position] -= claim_quantity
        end

        return supply
    end

    default_condition_rule = if is_producer
        if spec isa ActivityDemandSpec &&
           spec.producer_condition_function !== nothing
            ExplicitAgentConditions(
                spec.producer_condition_function,
            )
        elseif spec isa PowerProductionSpec
            TotalRevenueExpenditureBalanceConditions()
        elseif !isempty(endowments)
            TotalRevenueExpenditureBalanceConditions()
        elseif spec isa DCESSpec && !all(iszero, spec.xi)
            TotalRevenueExpenditureBalanceConditions()
        else
            UnitRevenueExpenditureBalanceConditions()
        end
    else
        TotalRevenueExpenditureBalanceConditions()
    end

    resolved_condition_rule = condition_rule === nothing ?
        default_condition_rule :
        condition_rule

    variable_name = is_producer ? :activity : :utility

    return NetSupplyAgent(
        local_indices,
        net_supply_function;
        variable_names=[variable_name],
        variable_lower_bounds=[activity_lower_bound],
        variable_upper_bounds=[activity_upper_bound],
        variable_start=[activity_start],
        observed_variables=observed,
        condition_rule=resolved_condition_rule,
        name=name,
    )
end
