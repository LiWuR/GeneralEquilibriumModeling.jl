# ================================================================
# solve_equilibrium_model_mcp_jump_v10_v19.jl
#
# GEM V27 JuMP + PATH solver with model-level auxiliary variables/equations.
#
# V10V19 is the self-contained GEM V27 JuMP + PATH solver. It merges the
# validated agent-expression machinery with the auxiliary-variable solver and
# extends the
# global MCP from
#
#   [agent conditions; nonnumeraire market conditions]
#       complements
#   [agent variables; nonnumeraire prices]
#
# to
#
#   [agent conditions; nonnumeraire market conditions; auxiliary equations]
#       complements
#   [agent variables; nonnumeraire prices; auxiliary variables].
#
# Current agent types and builder outputs are retained. Auxiliary
# equations are direct JuMP expressions and therefore participate in the
# sparse nonlinear expression graph and PATH Jacobian.
# ================================================================

"""
    EquilibriumModelSolverV10V19

Assemble canonical GEM models as JuMP mixed complementarity problems, solve
them with PATH, and return validated equilibrium results and diagnostics.
"""
module EquilibriumModelSolverV10V19

import JuMP
using JuMP
using LinearAlgebra: dot
using ForwardDiff
import PATHSolver
import MathOptInterface as MOI

# ----------------------------------------------------------------
# PATH license error handling
# ----------------------------------------------------------------

# PATHSolverLicenseError is raised when PATHSolver reports that a valid PATH
# license is not available for the current MCP. Without a PATH license, PATH
# supports problems with at most 300 variables and 2000 nonzeros in the
# Jacobian. A license error can therefore mean that either free-mode size
# limit was exceeded, or that a configured license is missing, invalid, or
# expired.
struct PATHSolverLicenseError <: Exception
    number_of_variables::Int
    raw_status::String
end

function Base.showerror(io::IO, err::PATHSolverLicenseError)
    println(io, "PATH solver license error.")
    println(io)
    println(io, "GEM MCP size:")
    println(io, "  complementarity variables: ", err.number_of_variables)
    println(io)
    println(
        io,
        "Without a PATH license, PATH supports at most 300 variables ",
        "and 2000 Jacobian nonzeros.",
    )
    println(
        io,
        "The current model may exceed either free-mode limit, or the ",
        "configured PATH license may be missing, invalid, or expired.",
    )
    println(io)
    println(io, "Configure a valid PATH license before solving again. For example:")
    println(io, "  ENV[", repr("PATH_LICENSE_STRING"), "] = ", repr("<license string>"))
    println(io, "before loading GEM/PATHSolver, or call:")
    println(io, "  PATHSolver.c_api_License_SetString(", repr("<license string>"), ")")
    println(io, "after importing PATHSolver.")
    println(io)
    print(io, "PATH raw status: ", err.raw_status)
end

function _is_path_license_error(status, raw_status::AbstractString)
    return status == MOI.OTHER_ERROR &&
           raw_status == "License could not be found"
end

function _check_path_license_status!(jump_model, number_of_variables::Integer)
    status = JuMP.termination_status(jump_model)
    raw_status = JuMP.raw_status(jump_model)

    if _is_path_license_error(status, raw_status)
        throw(PATHSolverLicenseError(
            Int(number_of_variables),
            String(raw_status),
        ))
    end

    return status
end



using ..EquilibriumNetSupplyModelV11:
    NetSupplyEquilibriumModel,
    UnitRevenueExpenditureBalanceConditions,
    TotalRevenueExpenditureBalanceConditions,
    ExplicitAgentConditions,
    agent_condition_rule,
    agent_net_supply,
    agent_observed_variables

using ..EquilibriumMarginalUtilityModelV5:
    MarginalUtilityConsumerConditions

using ..ProducerConditionsV1:
    ProductionStationarityConditions,
    CostMinimizationKKTConditions

using ..ProductionNetSupplyV1:
    ProductionNetSupply

using ..AuxiliaryEquationsV4:
    auxiliary_equation_name,
    auxiliary_equation_paired_variable_name,
    auxiliary_equation_observed_variables,
    auxiliary_equation_value

using ..EquilibriumJumpModelV2:
    EquilibriumJumpLayout,
    EquilibriumJumpVariables,
    build_equilibrium_jump_variables!,
    equilibrium_jump_reference,
    equilibrium_reference_value,
    effective_price_bounds

using ..AuxiliaryEquationJumpV1:
    AuxiliaryEquationJumpExpressions,
    build_auxiliary_equation_jump_expressions

using ..EquilibriumResultV1:
    EquilibriumResult

export PATHSolverLicenseError,
       solve_net_supply_equilibrium_mcp_jump,
       solve_equilibrium_model_mcp_jump,
       solve_equilibrium_model_mcp_jump_v10_v19,
       print_equilibrium_model_result


# ----------------------------------------------------------------
# 1. Self-contained agent-expression core
# ----------------------------------------------------------------

"""Cache values and Jacobians of an internal vector-valued operator."""
mutable struct VectorFunctionCache
    point::Vector{Float64}
    values::Vector{Float64}
    jacobian::Matrix{Float64}
    value_valid::Bool
    jacobian_valid::Bool
    value_evaluation_count::Int
    value_cache_hit_count::Int
    jacobian_evaluation_count::Int
    jacobian_cache_hit_count::Int
end

VectorFunctionCache(nout::Integer) = VectorFunctionCache(
    Float64[],
    zeros(Float64, Int(nout)),
    zeros(Float64, Int(nout), 0),
    false,
    false,
    0,
    0,
    0,
    0,
)

function _same_point(cache::VectorFunctionCache, point)
    cache.value_valid || return false
    length(cache.point) == length(point) || return false
    return all(isequal(cache.point[k], point[k]) for k in eachindex(point))
end

function _validate_vector_output(values, nout, description)
    values isa AbstractVector ||
        throw(ArgumentError("$(description) must return a vector."))
    length(values) == nout || throw(DimensionMismatch(
        "$(description) output length must be $(nout); got $(length(values)).",
    ))
    all(v -> v isa Real, values) ||
        throw(ArgumentError("$(description) must return a real-valued vector."))
    return collect(values)
end

function _cached_values!(cache, f, point::Vector{Float64})
    if _same_point(cache, point)
        cache.value_cache_hit_count += 1
        return cache.values
    end

    values = Float64.(f(point))
    resize!(cache.point, length(point))
    copyto!(cache.point, point)
    resize!(cache.values, length(values))
    copyto!(cache.values, values)
    cache.value_valid = true
    cache.jacobian_valid = false
    cache.value_evaluation_count += 1
    return cache.values
end

function _finite_difference_jacobian!(J, f, point)
    base = Float64.(f(point))
    relative_step = cbrt(eps(Float64))

    for k in eachindex(point)
        h = relative_step * max(1.0, abs(point[k]))
        xp = copy(point)
        xp[k] += h
        fp = Float64.(f(xp))

        derivative = try
            xm = copy(point)
            xm[k] -= h
            fm = Float64.(f(xm))
            (fp .- fm) ./ (2h)
        catch
            (fp .- base) ./ h
        end

        J[:, k] .= derivative
    end
    return nothing
end

function _cached_jacobian!(
    cache,
    f,
    point::Vector{Float64};
    force_finite_difference::Bool=false,
    forwarddiff_counter=()->nothing,
    finite_difference_counter=()->nothing,
)
    if _same_point(cache, point) && cache.jacobian_valid
        cache.jacobian_cache_hit_count += 1
        return cache.jacobian
    end

    _cached_values!(cache, f, point)
    nout = length(cache.values)

    if size(cache.jacobian) != (nout, length(point))
        cache.jacobian = zeros(Float64, nout, length(point))
    end

    if force_finite_difference
        _finite_difference_jacobian!(cache.jacobian, f, point)
        finite_difference_counter()
    else
        try
            J = ForwardDiff.jacobian(f, point)
            copyto!(cache.jacobian, J)
            forwarddiff_counter()
        catch
            _finite_difference_jacobian!(cache.jacobian, f, point)
            finite_difference_counter()
        end
    end

    cache.jacobian_valid = true
    cache.jacobian_evaluation_count += 1
    return cache.jacobian
end

"""Adapt a numerical vector function to scalar JuMP nonlinear operators."""
mutable struct NumericVectorOperatorAdapter{F}
    vector_function::F
    number_of_outputs::Int
    arity::Int
    prefix::Symbol
    force_finite_difference::Bool
    build_count::Int
    forwarddiff_jacobian_count::Int
    finite_difference_jacobian_count::Int
    cache::VectorFunctionCache
end

function NumericVectorOperatorAdapter(
    vector_function,
    nout::Integer,
    arity::Integer,
    prefix::Symbol;
    force_finite_difference::Bool=false,
)
    return NumericVectorOperatorAdapter{typeof(vector_function)}(
        vector_function,
        Int(nout),
        Int(arity),
        prefix,
        force_finite_difference,
        0,
        0,
        0,
        VectorFunctionCache(nout),
    )
end

function _component_value(adapter, component, args)
    point = Float64.(collect(args))
    return _cached_values!(
        adapter.cache,
        adapter.vector_function,
        point,
    )[component]
end

function _component_gradient!(g, adapter, component, args...)
    point = Float64.(collect(args))
    J = _cached_jacobian!(
        adapter.cache,
        adapter.vector_function,
        point;
        force_finite_difference=adapter.force_finite_difference,
        forwarddiff_counter=()->(adapter.forwarddiff_jacobian_count += 1),
        finite_difference_counter=()->(adapter.finite_difference_jacobian_count += 1),
    )
    g .= @view J[component, :]
    return nothing
end

function _component_derivative(adapter, component, x)
    point = [Float64(x)]
    J = _cached_jacobian!(
        adapter.cache,
        adapter.vector_function,
        point;
        force_finite_difference=adapter.force_finite_difference,
        forwarddiff_counter=()->(adapter.forwarddiff_jacobian_count += 1),
        finite_difference_counter=()->(adapter.finite_difference_jacobian_count += 1),
    )
    return J[component, 1]
end

"""Build scalar JuMP expressions for every component of a numeric adapter."""
function build_jump_vector_expression!(jump_model, adapter, arguments)
    length(arguments) == adapter.arity || throw(DimensionMismatch(
        "Numerical operator arity changed while building the JuMP expression.",
    ))

    adapter.build_count += 1
    build_id = adapter.build_count
    expressions = Vector{Any}(undef, adapter.number_of_outputs)

    for component in 1:adapter.number_of_outputs
        value_function = let a=adapter, c=component
            (x...) -> _component_value(a, c, x)
        end

        operator_name = Symbol(
            adapter.prefix,
            :__,
            build_id,
            :__,
            component,
        )

        operator = if adapter.arity == 1
            derivative_function = let a=adapter, c=component
                x -> _component_derivative(a, c, x)
            end

            JuMP.add_nonlinear_operator(
                jump_model,
                1,
                value_function,
                derivative_function;
                name=operator_name,
            )
        else
            gradient_function = let a=adapter, c=component
                function (g, x...)
                    _component_gradient!(g, a, c, x...)
                end
            end

            JuMP.add_nonlinear_operator(
                jump_model,
                adapter.arity,
                value_function,
                gradient_function;
                name=operator_name,
            )
        end

        expressions[component] = operator(arguments...)
    end

    return expressions
end

function _split_operator_point(point, nv, np, no)
    expected = nv + np + no

    length(point) == expected || throw(DimensionMismatch(
        "Internal numerical operator received $(length(point)) arguments; " *
        "expected $(expected).",
    ))

    local_variables = collect(point[1:nv])
    local_prices = collect(point[(nv + 1):(nv + np)])
    observed_values = no == 0 ?
        similar(local_variables, 0) :
        collect(point[(nv + np + 1):expected])

    return local_variables, local_prices, observed_values
end

function _numeric_net_supply_vector(agent, nv, np, no, point)
    local_variables, local_prices, observed_values =
        _split_operator_point(point, nv, np, no)

    values = agent_net_supply(
        agent,
        local_variables,
        local_prices,
        observed_values,
    )

    return _validate_vector_output(
        values,
        length(agent.commodity_indices),
        "Net-supply function for agent $(agent.name)",
    )
end

function _build_standard_marginal_utility_net_supply_expression(
    agent,
    rule::MarginalUtilityConsumerConditions,
    local_variables,
    local_prices,
)
    nv = length(local_variables)
    np = length(local_prices)
    no = length(agent_observed_variables(agent))

    zero_variables = zeros(Float64, nv)
    reference_prices = ones(Float64, np)
    reference_observed = zeros(Float64, no)

    endowment = Float64.(agent_net_supply(
        agent,
        zero_variables,
        reference_prices,
        reference_observed,
    ))

    length(endowment) == length(agent.commodity_indices) ||
        throw(DimensionMismatch(
            "Consumer $(agent.name) net-supply length does not match " *
            "commodity_indices.",
        ))

    all(isfinite, endowment) ||
        throw(ArgumentError(
            "Consumer $(agent.name) fixed endowment must be finite.",
        ))

    supply = Any[endowment...]

    for k in eachindex(rule.demand_variable_positions)
        variable_position = rule.demand_variable_positions[k]
        commodity_position = rule.demand_price_positions[k]

        1 <= variable_position <= length(local_variables) ||
            throw(BoundsError(
                "Consumer $(agent.name) demand variable position is out of range.",
            ))

        1 <= commodity_position <= length(supply) ||
            throw(BoundsError(
                "Consumer $(agent.name) demand commodity position is out of range.",
            ))

        supply[commodity_position] =
            supply[commodity_position] - local_variables[variable_position]
    end

    return supply
end

function _build_production_net_supply_expression(
    agent,
    rule::Union{
        ProductionStationarityConditions,
        CostMinimizationKKTConditions,
    },
    local_variables,
    local_prices,
    observed_values,
)
    mapping = agent.net_supply_function

    mapping isa ProductionNetSupply || throw(ArgumentError(
        "Production-function agent $(agent.name) must use " *
        "ProductionNetSupply as its net_supply_function.",
    ))

    length(mapping.local_indices) == length(agent.commodity_indices) ||
        throw(DimensionMismatch(
            "Production mapping for agent $(agent.name) has a " *
            "local index count inconsistent with commodity_indices.",
        ))

    mapping.local_indices == agent.commodity_indices || throw(ArgumentError(
        "Production mapping local_indices must match the agent's " *
        "commodity_indices in the same order.",
    ))

    length(local_variables) ==
        length(mapping.input_variable_positions) + 2 ||
        throw(DimensionMismatch(
            "Production local variables must be ordered as " *
            "[activity, inputs..., production_multiplier].",
        ))

    supply = agent_net_supply(
        agent,
        local_variables,
        local_prices,
        observed_values,
    )

    return Any[supply...]
end

function _build_net_supply_expression!(
    jump_model,
    agent,
    agent_index,
    local_variables,
    local_prices,
    observed_values,
)
    rule = agent_condition_rule(agent)

    if rule isa MarginalUtilityConsumerConditions
        expr = _build_standard_marginal_utility_net_supply_expression(
            agent,
            rule,
            local_variables,
            local_prices,
        )
        return expr, nothing, :marginal_utility_standard_consumer_expression

    elseif rule isa ProductionStationarityConditions
        try
            expr = _build_production_net_supply_expression(
                agent,
                rule,
                local_variables,
                local_prices,
                observed_values,
            )
            return expr, nothing, :stationary_production_jump_expression
        catch err
            throw(ArgumentError(
                "Stationary-production net supply for agent $(agent.name) " *
                "cannot construct a JuMP expression. The current solver does " *
                "not silently fall back to a numerical stationary-production " *
                "net-supply operator. Original error: " * sprint(showerror, err),
            ))
        end

    elseif rule isa CostMinimizationKKTConditions
        try
            expr = _build_production_net_supply_expression(
                agent,
                rule,
                local_variables,
                local_prices,
                observed_values,
            )
            return expr, nothing, :cost_minimization_kkt_jump_expression
        catch err
            throw(ArgumentError(
                "Cost-minimization KKT net supply for agent $(agent.name) " *
                "cannot construct a JuMP expression. The current solver does " *
                "not silently fall back to a numerical cost-minimization " *
                "net-supply operator. Original error: " * sprint(showerror, err),
            ))
        end
    end

    nv = length(local_variables)
    np = length(local_prices)
    no = length(observed_values)
    arguments = vcat(
        collect(local_variables),
        collect(local_prices),
        collect(observed_values),
    )

    f = point -> _numeric_net_supply_vector(agent, nv, np, no, point)
    adapter = NumericVectorOperatorAdapter(
        f,
        length(agent.commodity_indices),
        length(arguments),
        Symbol(:eq_net_supply__, agent_index),
    )
    expr = build_jump_vector_expression!(jump_model, adapter, arguments)

    return expr, adapter, :numeric_operator_cached_vector_jacobian
end

function _linear_profit_conditions(agent, nv, np, no)
    return function (point)
        _, p, observed_values = _split_operator_point(point, nv, np, no)
        conditions = Vector{eltype(point)}(undef, nv)

        for k in 1:nv
            basis = [zero(eltype(point)) for _ in 1:nv]
            basis[k] = one(eltype(point))
            s = agent_net_supply(agent, basis, p, observed_values)
            conditions[k] = -sum(p[j] * s[j] for j in eachindex(p))
        end

        return conditions
    end
end

function _general_profit_conditions(agent, nv, np, no)
    return function (point)
        v, p, observed_values = _split_operator_point(point, nv, np, no)
        profit = vv -> begin
            s = agent_net_supply(agent, vv, p, observed_values)
            sum(p[j] * s[j] for j in eachindex(p))
        end
        return -ForwardDiff.gradient(profit, v)
    end
end

function _total_profit_conditions(agent, nv, np, no)
    return function (point)
        variables, p, observed_values =
            _split_operator_point(point, nv, np, no)

        conditions = Vector{eltype(point)}(undef, nv)

        for k in 1:nv
            isolated_variables =
                [zero(eltype(point)) for _ in 1:nv]
            isolated_variables[k] = variables[k]

            supply = agent_net_supply(
                agent,
                isolated_variables,
                p,
                observed_values,
            )

            conditions[k] = -sum(
                p[j] * supply[j]
                for j in eachindex(p)
            )
        end

        return conditions
    end
end

function _explicit_condition_vector(rule, agent, nv, np, no, point)
    local_variables, local_prices, observed_values =
        _split_operator_point(point, nv, np, no)
    net_supply = agent_net_supply(
        agent,
        local_variables,
        local_prices,
        observed_values,
    )
    values = rule(
        local_variables,
        local_prices,
        net_supply,
        observed_values,
    )
    return _validate_vector_output(
        values,
        nv,
        "Agent conditions for $(agent.name)",
    )
end

function _direct_marginal_utility_condition_expression(
    rule::MarginalUtilityConsumerConditions,
    agent,
    nv,
    local_variables,
    local_prices,
    net_supply_expression,
    observed_values,
)
    values = rule(
        local_variables,
        local_prices,
        net_supply_expression,
        observed_values,
    )
    values isa AbstractVector || throw(ArgumentError(
        "Marginal-utility conditions for consumer $(agent.name) must return a vector.",
    ))
    length(values) == nv || throw(DimensionMismatch(
        "Marginal-utility condition output for consumer $(agent.name) must " *
        "have length $(nv); got $(length(values)).",
    ))
    return Any[values...]
end

function _direct_stationary_production_condition_expression(
    rule::ProductionStationarityConditions,
    agent,
    nv,
    local_variables,
    local_prices,
    net_supply_expression,
    observed_values,
)
    values = rule(
        local_variables,
        local_prices,
        net_supply_expression,
        observed_values,
    )
    values isa AbstractVector || throw(ArgumentError(
        "Stationary-production conditions for agent $(agent.name) must return a vector.",
    ))
    length(values) == nv || throw(DimensionMismatch(
        "Stationary-production condition output for agent $(agent.name) must " *
        "have length $(nv); got $(length(values)).",
    ))
    return Any[values...]
end

function _direct_cost_minimization_kkt_condition_expression(
    rule::CostMinimizationKKTConditions,
    agent,
    nv,
    local_variables,
    local_prices,
    net_supply_expression,
    observed_values,
)
    values = rule(
        local_variables,
        local_prices,
        net_supply_expression,
        observed_values,
    )
    values isa AbstractVector || throw(ArgumentError(
        "Cost-minimization KKT conditions for agent $(agent.name) must return a vector.",
    ))
    length(values) == nv || throw(DimensionMismatch(
        "Cost-minimization KKT condition output for agent $(agent.name) must " *
        "have length $(nv); got $(length(values)).",
    ))
    return Any[values...]
end

function _build_condition_expression!(
    jump_model,
    agent,
    agent_index,
    local_variables,
    local_prices,
    observed_values,
    net_supply_expression,
)
    nv = length(local_variables)
    nv == 0 && return Any[], nothing, :none

    np = length(local_prices)
    no = length(observed_values)
    arguments = vcat(
        collect(local_variables),
        collect(local_prices),
        collect(observed_values),
    )
    rule = agent_condition_rule(agent)

    if rule isa MarginalUtilityConsumerConditions
        try
            expr = _direct_marginal_utility_condition_expression(
                rule,
                agent,
                nv,
                local_variables,
                local_prices,
                net_supply_expression,
                observed_values,
            )
            return expr, nothing, :marginal_utility_jump_expression
        catch err
            throw(ArgumentError(
                "Marginal-utility function for consumer $(agent.name) cannot " *
                "construct a JuMP expression. Ensure that the marginal-utility " *
                "function accepts JuMP variables and declared observed values. " *
                "Original error: " * sprint(showerror, err),
            ))
        end

    elseif rule isa ProductionStationarityConditions
        try
            expr = _direct_stationary_production_condition_expression(
                rule,
                agent,
                nv,
                local_variables,
                local_prices,
                net_supply_expression,
                observed_values,
            )
            return expr, nothing, :stationary_production_jump_expression
        catch err
            throw(ArgumentError(
                "Stationary-production functions for agent $(agent.name) " *
                "cannot construct JuMP expressions. Original error: " *
                sprint(showerror, err),
            ))
        end

    elseif rule isa CostMinimizationKKTConditions
        try
            expr = _direct_cost_minimization_kkt_condition_expression(
                rule,
                agent,
                nv,
                local_variables,
                local_prices,
                net_supply_expression,
                observed_values,
            )
            return expr, nothing, :cost_minimization_kkt_jump_expression
        catch err
            throw(ArgumentError(
                "Cost-minimization KKT functions for agent $(agent.name) " *
                "cannot construct JuMP expressions. Original error: " *
                sprint(showerror, err),
            ))
        end

    elseif rule isa ExplicitAgentConditions
        f = point -> _explicit_condition_vector(
            rule,
            agent,
            nv,
            np,
            no,
            point,
        )
        method = :explicit_numeric_operator
        force_fd = false

    elseif rule isa UnitRevenueExpenditureBalanceConditions

        # and is interpreted as UnitRevenueExpenditureBalanceConditions.
        f = _linear_profit_conditions(agent, nv, np, no)
        method = :unit_profit_conditions
        force_fd = false

    elseif rule isa TotalRevenueExpenditureBalanceConditions
        f = _total_profit_conditions(agent, nv, np, no)
        method = :total_profit_conditions
        force_fd = false

    else
        throw(ArgumentError(
            "Agent $(agent.name) uses unsupported condition rule $(typeof(rule)).",
        ))
    end

    adapter = NumericVectorOperatorAdapter(
        f,
        nv,
        length(arguments),
        Symbol(:eq_condition__, agent_index);
        force_finite_difference=force_fd,
    )
    expr = build_jump_vector_expression!(jump_model, adapter, arguments)
    return expr, adapter, method
end

function _natural_residual(x, F, lb, ub)
    r = similar(x, Float64)
    for i in eachindex(x)
        r[i] = x[i] - clamp(x[i] - F[i], lb[i], ub[i])
    end
    return r
end

function _adapter_statistics(adapters)
    out = NamedTuple[]
    for item in adapters
        item === nothing && continue
        cache = item.cache
        push!(
            out,
            (
                prefix=item.prefix,
                expression_builds=item.build_count,
                forwarddiff_jacobians=item.forwarddiff_jacobian_count,
                finite_difference_jacobians=item.finite_difference_jacobian_count,
                vector_value_evaluations=cache.value_evaluation_count,
                value_cache_hits=cache.value_cache_hit_count,
                vector_jacobian_evaluations=cache.jacobian_evaluation_count,
                jacobian_cache_hits=cache.jacobian_cache_hit_count,
            ),
        )
    end
    return out
end

function _resolve_path_convergence_tolerance(
    residual_tol::Real,
    path_options::NamedTuple,
)
    if haskey(path_options, :convergence_tolerance)
        value = Float64(path_options.convergence_tolerance)
        isfinite(value) && value > 0 || throw(ArgumentError(
            "path_options.convergence_tolerance must be finite and positive.",
        ))
        return value, :user
    end

    value = Float64(residual_tol) / 10.0
    isfinite(value) && value > 0 || throw(ArgumentError(
        "The automatically derived PATH convergence tolerance is invalid.",
    ))
    return value, :automatic
end


# ----------------------------------------------------------------
# 2. Unified agent-observation resolution
# ----------------------------------------------------------------

function _resolve_agent_observed_jump_values(
    agent,
    layout::EquilibriumJumpLayout,
    jump_variables::EquilibriumJumpVariables,
)
    return Any[
        equilibrium_jump_reference(jump_variables, layout, ref)
        for ref in agent_observed_variables(agent)
    ]
end

function _agent_observed_numeric_values(
    model,
    layout::EquilibriumJumpLayout,
    x_solution::AbstractVector,
)
    return [
        Float64[
            equilibrium_reference_value(layout, ref, x_solution)
            for ref in agent_observed_variables(agent)
        ]
        for agent in model.agents
    ]
end


# ----------------------------------------------------------------
# 3. Agent and market JuMP expressions
# ----------------------------------------------------------------

function _build_agent_and_market_expressions!(
    jump_model,
    model::NetSupplyEquilibriumModel,
    layout::EquilibriumJumpLayout,
    jump_variables::EquilibriumJumpVariables,
)
    n = length(model.commodity_names)
    total_supply_expression = Any[0.0 for _ in 1:n]

    agent_condition_expressions = Any[]
    net_supply_expressions = Vector{Vector{Any}}(undef, length(model.agents))
    net_supply_adapters = Vector{Any}(undef, length(model.agents))
    condition_adapters = Vector{Any}(undef, length(model.agents))
    net_supply_methods = Vector{Symbol}(undef, length(model.agents))
    condition_methods = Vector{Symbol}(undef, length(model.agents))

    for (i, agent) in pairs(model.agents)
        local_variables = Any[
            jump_variables.agent_variables[k]
            for k in layout.agent_variable_ranges[i]
        ]
        local_prices = Any[
            jump_variables.prices[commodity]
            for commodity in agent.commodity_indices
        ]
        observed_values = _resolve_agent_observed_jump_values(
            agent,
            layout,
            jump_variables,
        )

        net_supply_expression,
        net_supply_adapter,
        net_supply_method = _build_net_supply_expression!(
            jump_model,
            agent,
            i,
            local_variables,
            local_prices,
            observed_values,
        )

        net_supply_expressions[i] = Any[net_supply_expression...]
        net_supply_adapters[i] = net_supply_adapter
        net_supply_methods[i] = net_supply_method

        for (k, commodity) in pairs(agent.commodity_indices)
            total_supply_expression[commodity] =
                total_supply_expression[commodity] + net_supply_expression[k]
        end

        condition_expression,
        condition_adapter,
        condition_method = _build_condition_expression!(
            jump_model,
            agent,
            i,
            local_variables,
            local_prices,
            observed_values,
            net_supply_expression,
        )

        append!(agent_condition_expressions, condition_expression)
        condition_adapters[i] = condition_adapter
        condition_methods[i] = condition_method
    end

    length(agent_condition_expressions) == layout.number_of_agent_variables ||
        error(
            "Internal error: agent-condition count does not match the " *
            "agent-variable block.",
        )

    market_expressions = Any[
        total_supply_expression[commodity]
        for commodity in layout.nonnumeraire_indices
    ]

    return (
        agent_conditions=agent_condition_expressions,
        market_conditions=market_expressions,
        total_supply=total_supply_expression,
        net_supply_expressions=net_supply_expressions,
        net_supply_adapters=net_supply_adapters,
        condition_adapters=condition_adapters,
        net_supply_methods=net_supply_methods,
        condition_methods=condition_methods,
    )
end


# ----------------------------------------------------------------
# 4. Auxiliary mapping order
# ----------------------------------------------------------------

function _auxiliary_mapping_in_variable_order(
    built::AuxiliaryEquationJumpExpressions,
    layout::EquilibriumJumpLayout,
)
    naux = layout.number_of_auxiliary_variables
    naux == length(built.expressions) || error(
        "Internal error: auxiliary expression count does not match layout.",
    )

    mapping = Vector{Any}(undef, naux)
    equation_name_by_variable = Vector{Symbol}(undef, naux)
    first_position = first(layout.auxiliary_variable_range)

    for k in eachindex(built.expressions)
        local_position =
            built.paired_variable_positions[k] - first_position + 1
        1 <= local_position <= naux || error(
            "Internal error: auxiliary equation paired position lies outside " *
            "the auxiliary-variable block.",
        )
        isassigned(mapping, local_position) && error(
            "Internal error: duplicate auxiliary equation pairing.",
        )
        mapping[local_position] = built.expressions[k]
        equation_name_by_variable[local_position] = built.equation_names[k]
    end

    all(i -> isassigned(mapping, i), eachindex(mapping)) || error(
        "Internal error: at least one auxiliary variable has no MCP equation.",
    )

    return mapping, equation_name_by_variable
end


# ----------------------------------------------------------------
# 5. Unified numerical verification
# ----------------------------------------------------------------

function _evaluate_numeric_v26(
    model::NetSupplyEquilibriumModel,
    layout::EquilibriumJumpLayout,
    x_solution::AbstractVector,
    agent_values,
    prices,
)
    agent_supplies = Vector{Vector{Float64}}(undef, length(model.agents))
    agent_conditions = Vector{Vector{Float64}}(undef, length(model.agents))
    total_supply = zeros(Float64, length(model.commodity_names))
    profits = zeros(Float64, length(model.agents))

    observed_values_by_agent = _agent_observed_numeric_values(
        model,
        layout,
        x_solution,
    )

    for (i, agent) in pairs(model.agents)
        v = agent_values[i]
        p = prices[agent.commodity_indices]
        observed_values = observed_values_by_agent[i]

        s = Float64.(agent_net_supply(
            agent,
            v,
            p,
            observed_values,
        ))
        agent_supplies[i] = s

        for (k, commodity) in pairs(agent.commodity_indices)
            total_supply[commodity] += s[k]
        end

        profits[i] = sum(p .* s)
        nv = length(v)

        if nv == 0
            agent_conditions[i] = Float64[]
            continue
        end

        rule = agent_condition_rule(agent)

        if rule isa MarginalUtilityConsumerConditions ||
           rule isa ProductionStationarityConditions ||
           rule isa CostMinimizationKKTConditions ||
           rule isa ExplicitAgentConditions

            values = Float64.(rule(
                v,
                p,
                s,
                observed_values,
            ))
            length(values) == nv || throw(DimensionMismatch(
                "Agent $(agent.name) numerical condition count does not " *
                "match its variable count.",
            ))
            agent_conditions[i] = values

        elseif rule isa UnitRevenueExpenditureBalanceConditions

            c = Float64[]
            for k in 1:nv
                basis = zeros(Float64, nv)
                basis[k] = 1.0
                sk = Float64.(agent_net_supply(
                    agent,
                    basis,
                    p,
                    observed_values,
                ))
                push!(c, -sum(p .* sk))
            end
            agent_conditions[i] = c

        elseif rule isa TotalRevenueExpenditureBalanceConditions
            c = Float64[]

            for k in 1:nv
                isolated_variables = zeros(Float64, nv)
                isolated_variables[k] = v[k]

                sk = Float64.(agent_net_supply(
                    agent,
                    isolated_variables,
                    p,
                    observed_values,
                ))

                push!(c, -sum(p .* sk))
            end

            agent_conditions[i] = c

        else
            error(
                "Internal error: unsupported agent condition rule " *
                "$(typeof(rule)) during V26 numerical verification.",
            )
        end
    end

    return (
        agent_net_supplies=agent_supplies,
        agent_conditions=agent_conditions,
        total_net_supply=total_supply,
        agent_profits=profits,
        observed_variable_values=observed_values_by_agent,
    )
end


# ----------------------------------------------------------------
# 6. Scalar-expression evaluation
# ----------------------------------------------------------------

function _jump_scalar_value(expression)
    if expression isa Real
        isfinite(expression) || throw(ArgumentError(
            "A complementarity mapping expression is nonfinite.",
        ))
        return Float64(expression)
    end

    value = JuMP.value(expression)
    value isa Real && isfinite(value) || throw(ArgumentError(
        "A complementarity mapping expression evaluated to a nonfinite value.",
    ))
    return Float64(value)
end

function _numeric_auxiliary_equation_values(
    model::NetSupplyEquilibriumModel,
    layout::EquilibriumJumpLayout,
    x_solution::AbstractVector,
)
    names = Symbol[]
    values = Float64[]
    paired_names = Symbol[]
    observed_numeric_values = Vector{Vector{Float64}}()

    for equation in model.auxiliary_equations
        refs = auxiliary_equation_observed_variables(equation)
        observed = Float64[
            equilibrium_reference_value(layout, ref, x_solution)
            for ref in refs
        ]
        value = auxiliary_equation_value(equation, observed)
        value isa Real && isfinite(value) || throw(ArgumentError(
            "Auxiliary equation $(auxiliary_equation_name(equation)) " *
            "evaluated to a nonfinite or nonreal value.",
        ))

        push!(names, auxiliary_equation_name(equation))
        push!(values, Float64(value))
        push!(paired_names, auxiliary_equation_paired_variable_name(equation))
        push!(observed_numeric_values, observed)
    end

    return (
        names=names,
        values=values,
        paired_names=paired_names,
        observed_values=observed_numeric_values,
    )
end

function _auxiliary_values_by_variable_order(
    model::NetSupplyEquilibriumModel,
    layout::EquilibriumJumpLayout,
    x_solution::AbstractVector,
)
    names = Symbol[variable.name for variable in model.auxiliary_variables]
    values = Float64[
        x_solution[layout.auxiliary_variable_position[name]]
        for name in names
    ]
    return names, values
end


# ----------------------------------------------------------------
# 7. Public solver
# ----------------------------------------------------------------

"""
    solve_net_supply_equilibrium_mcp_jump(model; kwargs...)

Solve a `NetSupplyEquilibriumModel` as a JuMP mixed complementarity problem
using PATH.

`v0`, `p0`, and `auxiliary0` optionally override starting values. Price bounds
may be overridden with `price_floor` and `price_upper_bound`.
`path_options` passes optimizer attributes to PATH. The returned
`EquilibriumResult` includes prices, agent variables, auxiliary variables,
market balances, natural residuals, and solver diagnostics. Its `solved` flag
also checks the omitted numeraire market against `residual_tol`.
"""
function solve_net_supply_equilibrium_mcp_jump(
    model::NetSupplyEquilibriumModel;
    v0::Union{Nothing,AbstractVector}=nothing,
    p0::Union{Nothing,AbstractVector}=nothing,
    auxiliary0::Union{Nothing,AbstractVector}=nothing,
    price_floor::Union{Nothing,Real,AbstractVector}=nothing,
    price_upper_bound::Union{Nothing,Real,AbstractVector}=nothing,
    residual_tol::Real=1.0e-8,
    silent::Bool=false,
    path_options::NamedTuple=NamedTuple(),
)
    isfinite(residual_tol) && residual_tol > 0 ||
        throw(ArgumentError("residual_tol must be finite and positive."))

    layout = EquilibriumJumpLayout(model)

    path_convergence_tolerance,
    path_convergence_tolerance_source =
        _resolve_path_convergence_tolerance(
            residual_tol,
            path_options,
        )

    jump_model = JuMP.Model(PATHSolver.Optimizer)
    silent && JuMP.set_silent(jump_model)

    if path_convergence_tolerance_source === :automatic
        JuMP.set_optimizer_attribute(
            jump_model,
            "convergence_tolerance",
            path_convergence_tolerance,
        )
    end
    for (key, value) in pairs(path_options)
        JuMP.set_optimizer_attribute(jump_model, String(key), value)
    end

    jump_variables = build_equilibrium_jump_variables!(
        jump_model,
        model,
        layout;
        v0=v0,
        p0=p0,
        auxiliary0=auxiliary0,
        price_floor=price_floor,
        price_upper_bound=price_upper_bound,
    )

    agent_market = _build_agent_and_market_expressions!(
        jump_model,
        model,
        layout,
        jump_variables,
    )

    auxiliary_built = build_auxiliary_equation_jump_expressions(
        model,
        jump_variables,
        layout,
    )
    auxiliary_mapping,
    auxiliary_equation_name_by_variable =
        _auxiliary_mapping_in_variable_order(auxiliary_built, layout)

    mapping = vcat(
        agent_market.agent_conditions,
        agent_market.market_conditions,
        auxiliary_mapping,
    )

    length(mapping) == layout.number_of_variables ||
        throw(DimensionMismatch(
            "The complete MCP mapping length must equal the number of " *
            "endogenous variables.",
        ))

    complementarity_mapping = convert.(JuMP.NonlinearExpr, mapping)
    complementarity_constraint = @constraint(
        jump_model,
        complementarity_mapping ⟂ jump_variables.variables,
    )

    JuMP.optimize!(jump_model)
    status = _check_path_license_status!(
        jump_model,
        length(jump_variables.variables),
    )

    JuMP.has_values(jump_model) || throw(ErrorException(
        "PATH returned no candidate solution: termination_status=$(status), " *
        "raw_status=$(JuMP.raw_status(jump_model)).",
    ))

    x_solution = Float64.(JuMP.value.(jump_variables.variables))
    all(isfinite, x_solution) || throw(ErrorException(
        "PATH candidate solution contains nonfinite endogenous values.",
    ))

    jump_mapping_values = Float64[_jump_scalar_value(expr) for expr in mapping]
    all(isfinite, jump_mapping_values) || error(
        "Internal error: JuMP mapping contains nonfinite values after solve.",
    )

    prices = Float64[
        price isa JuMP.VariableRef ? JuMP.value(price) : price
        for price in jump_variables.prices
    ]
    all(isfinite, prices) || throw(ErrorException(
        "PATH candidate solution contains nonfinite commodity prices.",
    ))

    agent_values = [
        Float64.(x_solution[layout.agent_variable_ranges[i]])
        for i in eachindex(model.agents)
    ]

    evaluation = _evaluate_numeric_v26(
        model,
        layout,
        x_solution,
        agent_values,
        prices,
    )

    auxiliary_numeric = _numeric_auxiliary_equation_values(
        model,
        layout,
        x_solution,
    )

    auxiliary_numeric_by_variable = Vector{Float64}(
        undef,
        layout.number_of_auxiliary_variables,
    )
    first_auxiliary_position = first(layout.auxiliary_variable_range)
    for (k, equation) in pairs(model.auxiliary_equations)
        global_position = layout.auxiliary_variable_position[
            auxiliary_equation_paired_variable_name(equation)
        ]
        local_position = global_position - first_auxiliary_position + 1
        auxiliary_numeric_by_variable[local_position] =
            auxiliary_numeric.values[k]
    end

    mapping_values = Float64[]
    for conditions in evaluation.agent_conditions
        append!(mapping_values, conditions)
    end
    append!(
        mapping_values,
        evaluation.total_net_supply[layout.nonnumeraire_indices],
    )
    append!(mapping_values, auxiliary_numeric_by_variable)

    length(mapping_values) == length(x_solution) || error(
        "Internal error: numeric MCP mapping length is inconsistent.",
    )
    all(isfinite, mapping_values) || throw(ErrorException(
        "PATH candidate solution produces nonfinite MCP mapping values.",
    ))

    mapping_consistency_error = maximum(
        abs,
        mapping_values .- jump_mapping_values;
        init=0.0,
    )

    natural_residual = _natural_residual(
        x_solution,
        mapping_values,
        jump_variables.lower_bounds,
        jump_variables.upper_bounds,
    )
    max_natural_residual = maximum(abs, natural_residual; init=0.0)

    omitted_market_residual =
        evaluation.total_net_supply[model.numeraire_index]
    max_market_residual =
        maximum(abs, evaluation.total_net_supply; init=0.0)
    all_markets_clear = max_market_residual <= residual_tol
    walras_value = dot(prices, evaluation.total_net_supply)

    mcp_solved = status in (MOI.LOCALLY_SOLVED, MOI.OPTIMAL)
    solved =
        mcp_solved &&
        max_natural_residual <= residual_tol &&
        abs(omitted_market_residual) <= residual_tol

    auxiliary_names, auxiliary_value_vector =
        _auxiliary_values_by_variable_order(model, layout, x_solution)
    auxiliary_values = Dict(
        auxiliary_names[i] => auxiliary_value_vector[i]
        for i in eachindex(auxiliary_names)
    )
    auxiliary_equation_values = Dict(
        auxiliary_numeric.names[i] => auxiliary_numeric.values[i]
        for i in eachindex(auxiliary_numeric.names)
    )

    auxiliary_residual_range = layout.number_of_auxiliary_variables == 0 ?
        (1:0) : layout.auxiliary_variable_range
    auxiliary_natural_residual = layout.number_of_auxiliary_variables == 0 ?
        Float64[] : Float64.(natural_residual[auxiliary_residual_range])

    observed_numeric_values = evaluation.observed_variable_values

    price_lb, price_ub = effective_price_bounds(
        model;
        price_floor=price_floor,
        price_upper_bound=price_upper_bound,
    )

    return EquilibriumResult((
        solved=solved,
        mcp_solved=mcp_solved,
        status=status,
        termination_status=status,
        primal_status=JuMP.primal_status(jump_model),
        raw_status=JuMP.raw_status(jump_model),
        result_count=JuMP.result_count(jump_model),
        solver_name=JuMP.solver_name(jump_model),
        x=x_solution,
        mapping=mapping_values,
        jump_mapping=jump_mapping_values,
        mapping_consistency_error=Float64(mapping_consistency_error),
        natural_residual=natural_residual,
        max_natural_residual=Float64(max_natural_residual),
        lower_bounds=copy(jump_variables.lower_bounds),
        upper_bounds=copy(jump_variables.upper_bounds),
        jump_model=jump_model,
        complementarity_constraint=complementarity_constraint,
        model=model,
        canonical_model=model,
        layout=layout,
        solver_interface_version=:v10_v15,
        path_convergence_tolerance=path_convergence_tolerance,
        path_convergence_tolerance_source=path_convergence_tolerance_source,
        prices=prices,
        price_lower_bounds=price_lb,
        price_upper_bounds=price_ub,
        agent_names=Symbol[agent.name for agent in model.agents],
        agent_variable_names=[copy(agent.variable_names) for agent in model.agents],
        agent_variable_values=agent_values,
        observed_variable_refs=[copy(agent.observed_variables) for agent in model.agents],
        observed_variable_values=observed_numeric_values,
        agent_conditions=evaluation.agent_conditions,
        condition_methods=agent_market.condition_methods,
        agent_net_supplies=evaluation.agent_net_supplies,
        agent_profits=evaluation.agent_profits,
        total_net_supply=evaluation.total_net_supply,
        excess_supply=evaluation.total_net_supply,
        omitted_market_index=model.numeraire_index,
        omitted_market_residual=Float64(omitted_market_residual),
        max_market_residual=Float64(max_market_residual),
        all_markets_clear=all_markets_clear,
        walras_value=Float64(walras_value),
        numeraire_index=model.numeraire_index,
        numeraire_value=Float64(model.numeraire_value),
        net_supply_methods=agent_market.net_supply_methods,
        net_supply_derivative_statistics=_adapter_statistics(
            agent_market.net_supply_adapters,
        ),
        condition_derivative_statistics=_adapter_statistics(
            agent_market.condition_adapters,
        ),
        auxiliary_variable_names=auxiliary_names,
        auxiliary_value_vector=auxiliary_value_vector,
        auxiliary_values=auxiliary_values,
        auxiliary_equation_names=auxiliary_numeric.names,
        auxiliary_equation_value_vector=auxiliary_numeric.values,
        auxiliary_equation_values=auxiliary_equation_values,
        auxiliary_equation_paired_variables=auxiliary_numeric.paired_names,
        auxiliary_equation_name_by_variable=auxiliary_equation_name_by_variable,
        auxiliary_equation_observed_variable_refs=[
            auxiliary_equation_observed_variables(eq)
            for eq in model.auxiliary_equations
        ],
        auxiliary_equation_observed_values=auxiliary_numeric.observed_values,
        auxiliary_natural_residual=auxiliary_natural_residual,
        max_auxiliary_natural_residual=maximum(
            abs,
            auxiliary_natural_residual;
            init=0.0,
        ),
    ))
end

"""
    solve_equilibrium_model_mcp_jump(model; kwargs...)

Public alias for `solve_net_supply_equilibrium_mcp_jump`.
"""
function solve_equilibrium_model_mcp_jump(
    model::NetSupplyEquilibriumModel;
    kwargs...,
)
    return solve_net_supply_equilibrium_mcp_jump(model; kwargs...)
end

"""
    solve_equilibrium_model_mcp_jump_v10_v19(model; kwargs...)

Versioned alias for `solve_net_supply_equilibrium_mcp_jump`.
"""
solve_equilibrium_model_mcp_jump_v10_v19(
    model::NetSupplyEquilibriumModel;
    kwargs...,
) = solve_net_supply_equilibrium_mcp_jump(model; kwargs...)

"""
    print_equilibrium_model_result(result)

Print a concise summary of solver status, prices, quantities, and residuals.
"""
function print_equilibrium_model_result(result)
    println("\n========== Equilibrium solution ==========")
    println("PATH status: ", result.status)
    println("Solved: ", result.solved)
    println("All commodity markets approximately clear: ", result.all_markets_clear)
    println("Equilibrium prices: ", result.prices)
    println("Agent variable values: ", result.agent_variable_values)
    println("Auxiliary values: ", result.auxiliary_values)
    println("Auxiliary equation values: ", result.auxiliary_equation_values)
    println("Total net supply: ", result.total_net_supply)
    println("Maximum market residual: ", result.max_market_residual)
    println("Maximum MCP natural residual: ", result.max_natural_residual)
    println(
        "Maximum auxiliary natural residual: ",
        result.max_auxiliary_natural_residual,
    )
    println("==========================================")
    return nothing
end

end # module EquilibriumModelSolverV10V19
