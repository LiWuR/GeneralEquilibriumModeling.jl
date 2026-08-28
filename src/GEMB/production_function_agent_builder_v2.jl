# ================================================================
# production_function_agent_builder_v1.jl
#
# Builder for ProductionFunctionSpec using stationary or cost-minimization
# KKT behavior.
#
# This file is included directly into module GEMB.
# ================================================================

using ..GEM:
    NetSupplyAgent,
    ProductionStationarityConditions,
    CostMinimizationKKTConditions

export build_agent

# GEM's production accounting layer was renamed during the recent cleanup.
# Keep GEMB compatible with either public binding without duplicating the
# accounting logic locally. The object returned here remains a GEM object.
const _ProductionNetSupply = if isdefined(GEM, :ProductionNetSupply)
    getproperty(GEM, :ProductionNetSupply)
elseif isdefined(GEM, :StationaryProductionNetSupply)
    getproperty(GEM, :StationaryProductionNetSupply)
else
    error(
        "GEM must expose ProductionNetSupply or StationaryProductionNetSupply " *
        "for production-function builders."
    )
end

function _check_production_function_signatures(
    production_function,
    marginal_product_function,
    input_start,
    observed_variables,
)
    inputs0 = copy(input_start)

    if applicable(production_function, inputs0)
        y0 = production_function(inputs0)
        y0 isa Real && isfinite(y0) || throw(ArgumentError(
            "production_function must return a finite real scalar at demand_start.",
        ))
    else
        isempty(observed_variables) && throw(ArgumentError(
            "production_function requires observed_values, but observed_variables is empty.",
        ))
        probe_observed = zeros(Float64, length(observed_variables))
        applicable(production_function, inputs0, probe_observed) || throw(ArgumentError(
            "production_function must accept (inputs) or " *
            "(inputs, observed_values).",
        ))
    end

    if applicable(marginal_product_function, inputs0)
        mp0 = marginal_product_function(inputs0)
        mp0 isa AbstractVector || throw(ArgumentError(
            "marginal_product_function must return a vector.",
        ))
        length(mp0) == length(inputs0) || throw(DimensionMismatch(
            "marginal_product_function output length must equal input count.",
        ))
        all(x -> x isa Real && isfinite(x), mp0) || throw(ArgumentError(
            "marginal_product_function must return a finite real vector at demand_start.",
        ))
    else
        isempty(observed_variables) && throw(ArgumentError(
            "marginal_product_function requires observed_values, but observed_variables is empty.",
        ))
        probe_observed = zeros(Float64, length(observed_variables))
        applicable(marginal_product_function, inputs0, probe_observed) ||
            throw(ArgumentError(
                "marginal_product_function must accept (inputs) or " *
                "(inputs, observed_values).",
            ))
    end

    return nothing
end

function _normalize_production_behavior(value)
    behavior = Symbol(value)

    behavior in (:stationary, :cost_min) || throw(ArgumentError(
        "production_behavior must be :stationary or :cost_min.",
    ))

    return behavior
end

function _resolve_production_multiplier_lower_bound(
    production_behavior,
    supplied_lower_bound,
)
    if supplied_lower_bound === nothing
        return production_behavior === :cost_min ? 0.0 : -Inf
    end

    lower = Float64(supplied_lower_bound)
    isnan(lower) && throw(ArgumentError(
        "production_multiplier_lower_bound cannot be NaN.",
    ))

    if production_behavior === :cost_min && !iszero(lower)
        throw(ArgumentError(
            "production_behavior=:cost_min requires " *
            "production_multiplier_lower_bound == 0.",
        ))
    end

    return lower
end

function _check_cost_min_input_bounds(lower)
    all(iszero, lower) || throw(ArgumentError(
        "production_behavior=:cost_min requires all demand_lower_bounds " *
        "for production inputs to equal 0.",
    ))
    return nothing
end

function _check_production_multiplier_arguments(
    start,
    lower,
    upper,
)
    isfinite(start) || throw(ArgumentError(
        "production_multiplier_start must be finite.",
    ))
    !isnan(lower) && !isnan(upper) || throw(ArgumentError(
        "Production multiplier bounds cannot contain NaN.",
    ))
    lower < upper || throw(ArgumentError(
        "production_multiplier_lower_bound must be below " *
        "production_multiplier_upper_bound.",
    ))
    lower <= start <= upper || throw(ArgumentError(
        "production_multiplier_start must lie within its bounds.",
    ))
    return nothing
end

# ProductionFunctionSpec describes production behavior only. Commodity
# mappings, activity/input starts and bounds, observed variables, and names
# remain arguments of build_agent so one technology specification can be
# reused by different producers and in different equilibrium models.

function build_agent(
    spec::ProductionFunctionSpec;
    output_indices=Int[],
    output_coefficients=nothing,
    demand_indices=Int[],
    endowment_indices=Int[],
    endowment_quantities=nothing,
    activity_start::Real=100.0,
    activity_lower_bound::Real=0.0,
    activity_upper_bound::Real=Inf,
    demand_start=100.0,
    demand_lower_bounds=0.0,
    demand_upper_bounds=Inf,
    production_multiplier_start::Real=1.0,
    production_multiplier_lower_bound=nothing,
    production_multiplier_upper_bound::Real=Inf,
    observed_variables=Any[],
    name::Symbol=:agent,
)
    outputs = _normalize_indices(
        output_indices,
        "output_indices";
        allow_empty=true,
    )
    inputs = _normalize_indices(
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
    coefficients = _normalize_output_coefficients(
        outputs,
        output_coefficients,
    )
    observed = _normalize_observed_variables(observed_variables)

    isempty(outputs) && throw(ArgumentError(
        "ProductionFunctionSpec requires output_indices.",
    ))
    isempty(inputs) && throw(ArgumentError(
        "ProductionFunctionSpec requires demand_indices for inputs.",
    ))
    isempty(endowments) || throw(ArgumentError(
        "ProductionFunctionSpec does not accept endowment_indices. " *
        "Production net supply must contain only production outputs and " *
        "endogenous input demands so total loss remains -p' * net_supply.",
    ))
    isempty(quantities) || throw(ArgumentError(
        "ProductionFunctionSpec does not accept endowment_quantities.",
    ))

    behavior = _normalize_production_behavior(spec.production_behavior)
    effective_production_multiplier_lower_bound =
        _resolve_production_multiplier_lower_bound(
            behavior,
            production_multiplier_lower_bound,
        )

    _check_activity_arguments(
        activity_start,
        activity_lower_bound,
        activity_upper_bound,
    )

    m = length(inputs)
    starts = _normalize_vector(demand_start, m, "demand_start")
    lower = _normalize_vector(demand_lower_bounds, m, "demand_lower_bounds")
    upper = _normalize_vector(demand_upper_bounds, m, "demand_upper_bounds")

    all(isfinite, starts) || throw(ArgumentError(
        "Production input starts must be finite.",
    ))
    all(x -> !isnan(x), lower) && all(x -> !isnan(x), upper) ||
        throw(ArgumentError("Production input bounds cannot contain NaN."))
    all(lower .>= 0) || throw(ArgumentError(
        "Production input lower bounds cannot be negative.",
    ))
    all(lower .< upper) || throw(ArgumentError(
        "Production input bounds are invalid.",
    ))
    all((lower .<= starts) .& (starts .<= upper)) || throw(ArgumentError(
        "Production input starts must lie within their bounds.",
    ))

    if behavior === :cost_min
        _check_cost_min_input_bounds(lower)
    end

    _check_production_multiplier_arguments(
        production_multiplier_start,
        effective_production_multiplier_lower_bound,
        production_multiplier_upper_bound,
    )

    _check_production_function_signatures(
        spec.production_function,
        spec.marginal_product_function,
        starts,
        observed,
    )

    mapping = _ProductionNetSupply(
        outputs,
        coefficients,
        inputs,
    )

    rule = if behavior === :stationary
        ProductionStationarityConditions(
            spec.production_function,
            spec.marginal_product_function,
            mapping.input_positions,
        )
    else
        CostMinimizationKKTConditions(
            spec.production_function,
            spec.marginal_product_function,
            mapping.input_positions,
        )
    end

    variable_names = vcat(
        [:activity],
        [Symbol(:input_, commodity) for commodity in inputs],
        [:production_multiplier],
    )

    return NetSupplyAgent(
        mapping.local_indices,
        mapping;
        variable_names=variable_names,
        variable_lower_bounds=vcat(
            [activity_lower_bound],
            lower,
            [effective_production_multiplier_lower_bound],
        ),
        variable_upper_bounds=vcat(
            [activity_upper_bound],
            upper,
            [production_multiplier_upper_bound],
        ),
        variable_start=vcat(
            [Float64(activity_start)],
            starts,
            [Float64(production_multiplier_start)],
        ),
        observed_variables=observed,
        condition_rule=rule,
        name=name,
    )
end
