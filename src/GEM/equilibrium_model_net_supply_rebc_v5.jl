# ================================================================
# equilibrium_model_net_supply_v11.jl
#
# GEM V27 net-supply model layer with unified agent observations.
#
# V11 uses the independent GEM agent-core type system,
# but introduces a V27 NetSupplyAgent whose observed_variables may contain
# any supported equilibrium-variable reference:
#
#   AgentVariableRef
#   PriceVariableRef
#   AuxiliaryVariableRef
#
# This preserves compatibility with the current marginal-utility, stationary-
# production, and cost-minimization KKT condition types while allowing an
# agent's behavior to depend directly on model-level auxiliary variables.
# ================================================================

"""
    EquilibriumNetSupplyModelV11

Define net-supply agents and the canonical GEM equilibrium-model container,
including cross-agent observations and model-level auxiliary variables.
"""
module EquilibriumNetSupplyModelV11

using ..EquilibriumAgentCoreV1:
    AbstractNetSupplyAgent,
    AbstractAgentConditionRule,
    UnitRevenueExpenditureBalanceConditions,
    TotalRevenueExpenditureBalanceConditions,
    ExplicitAgentConditions,
    AgentVariableRef,
    agent_name,
    agent_commodity_indices,
    agent_variable_count,
    agent_condition_rule,
    agent_uses_automatic_conditions,
    agent_observed_variables,
    agent_observed_variable_count,
    agent_net_supply

using ..EquilibriumVariableRefsV3:
    PriceVariableRef,
    AuxiliaryVariableRef,
    EquilibriumVariableRef,
    is_equilibrium_variable_ref

using ..AuxiliaryVariablesV1:
    AuxiliaryVariable,
    auxiliary_variable_name

using ..AuxiliaryEquationsV4:
    AuxiliaryEquation,
    auxiliary_equation_name,
    auxiliary_equation_paired_variable_name,
    auxiliary_equation_observed_variables

export AbstractNetSupplyAgent,
       AbstractAgentConditionRule,
       UnitRevenueExpenditureBalanceConditions,
       TotalRevenueExpenditureBalanceConditions,
       ExplicitAgentConditions,
       AgentVariableRef,
       PriceVariableRef,
       AuxiliaryVariableRef,
       AuxiliaryVariable,
       AuxiliaryEquation,
       NetSupplyAgent,
       NetSupplyConsumerAgent,
       ProducerAgent,
       NetSupplyEquilibriumModel,
       agent_name,
       agent_commodity_indices,
       agent_variable_count,
       agent_condition_rule,
       agent_uses_automatic_conditions,
       agent_observed_variables,
       agent_observed_variable_count,
       agent_net_supply,
       auxiliary_variables,
       auxiliary_equations,
       auxiliary_variable_count,
       auxiliary_equation_count,
       auxiliary_variable_index,
       auxiliary_equation_index,
       price_lower_bounds,
       price_upper_bounds


"""
    NetSupplyAgent

Economic agent represented by a local net-supply function, optional
endogenous variables, and an equilibrium-condition rule.
"""
struct NetSupplyAgent{F,R<:AbstractAgentConditionRule,T<:Real} <:
       AbstractNetSupplyAgent
    name::Symbol
    commodity_indices::Vector{Int}
    variable_names::Vector{Symbol}
    variable_lower_bounds::Vector{T}
    variable_upper_bounds::Vector{T}
    variable_start::Vector{T}
    observed_variables::Vector{EquilibriumVariableRef}
    net_supply_function::F
    condition_rule::R
end

function _check_indices(indices, description; allow_empty::Bool=false)
    !allow_empty && isempty(indices) &&
        throw(ArgumentError("$(description) cannot be empty."))
    all(i -> i >= 1, indices) ||
        throw(ArgumentError("$(description) must contain positive integers."))
    length(unique(indices)) == length(indices) ||
        throw(ArgumentError("$(description) cannot contain duplicates."))
    return nothing
end

function _check_observed_variables(observed_variables)
    all(is_equilibrium_variable_ref, observed_variables) ||
        throw(ArgumentError(
            "observed_variables may contain only AgentVariableRef, " *
            "PriceVariableRef, or AuxiliaryVariableRef objects.",
        ))
    length(unique(observed_variables)) == length(observed_variables) ||
        throw(ArgumentError("observed_variables cannot contain duplicates."))
    return nothing
end

function _default_start(lower, upper)
    if isfinite(lower) && isfinite(upper)
        return lower + (upper - lower) / 2
    elseif isfinite(lower)
        return lower + one(lower)
    elseif isfinite(upper)
        return upper - one(upper)
    end
    return zero(promote_type(typeof(lower), typeof(upper)))
end

function _resolve_condition_rule(condition_rule)
    condition_rule === nothing && return UnitRevenueExpenditureBalanceConditions()
    condition_rule isa AbstractAgentConditionRule ||
        throw(ArgumentError(
            "condition_rule must be an AbstractAgentConditionRule.",
        ))
    return condition_rule
end

"""
    NetSupplyAgent(commodity_indices, net_supply_function; kwargs...)

Create a net-supply agent operating on `commodity_indices`.

The net-supply function receives local variables and prices, with an optional
third argument for declared `observed_variables`. Positive returned quantities
are supplies and negative quantities are demands. Agent variables are paired
with conditions generated by `condition_rule`.
"""
function NetSupplyAgent(
    commodity_indices::AbstractVector{<:Integer},
    net_supply_function;
    variable_names::AbstractVector{Symbol}=Symbol[],
    variable_lower_bounds::AbstractVector{<:Real}=zeros(length(variable_names)),
    variable_upper_bounds::AbstractVector{<:Real}=fill(Inf, length(variable_names)),
    variable_start::Union{Nothing,AbstractVector{<:Real}}=nothing,
    observed_variables::AbstractVector=EquilibriumVariableRef[],
    condition_rule=nothing,
    name::Symbol=:agent,
)
    _check_indices(commodity_indices, "commodity_indices")
    length(unique(variable_names)) == length(variable_names) ||
        throw(ArgumentError("Agent variable names cannot contain duplicates."))
    _check_observed_variables(observed_variables)

    nv = length(variable_names)
    length(variable_lower_bounds) == nv ||
        throw(DimensionMismatch(
            "variable_lower_bounds length must equal the number of agent variables.",
        ))
    length(variable_upper_bounds) == nv ||
        throw(DimensionMismatch(
            "variable_upper_bounds length must equal the number of agent variables.",
        ))
    all(x -> !isnan(x), variable_lower_bounds) ||
        throw(ArgumentError("variable_lower_bounds cannot contain NaN."))
    all(x -> !isnan(x), variable_upper_bounds) ||
        throw(ArgumentError("variable_upper_bounds cannot contain NaN."))
    all(variable_lower_bounds .< variable_upper_bounds) ||
        throw(ArgumentError(
            "Each agent variable lower bound must be strictly below its upper bound.",
        ))

    starts = variable_start === nothing ? Float64[
        _default_start(variable_lower_bounds[k], variable_upper_bounds[k])
        for k in 1:nv
    ] : collect(variable_start)
    length(starts) == nv ||
        throw(DimensionMismatch(
            "variable_start length must equal the number of agent variables.",
        ))
    all(isfinite, starts) ||
        throw(ArgumentError("Agent variable starts must all be finite."))
    all((variable_lower_bounds .<= starts) .& (starts .<= variable_upper_bounds)) ||
        throw(ArgumentError(
            "Agent variable starts must lie within their corresponding bounds.",
        ))

    rule = _resolve_condition_rule(condition_rule)
    T = promote_type(
        Float64,
        eltype(variable_lower_bounds),
        eltype(variable_upper_bounds),
        eltype(starts),
    )

    return NetSupplyAgent{typeof(net_supply_function),typeof(rule),T}(
        name,
        Int.(commodity_indices),
        collect(variable_names),
        T.(variable_lower_bounds),
        T.(variable_upper_bounds),
        T.(starts),
        EquilibriumVariableRef[observed_variables...],
        net_supply_function,
        rule,
    )
end

"""
    NetSupplyConsumerAgent(commodity_indices, net_supply_function;
                           observed_variables=[], name=:consumer)

Create a net-supply agent without endogenous agent variables.
"""
NetSupplyConsumerAgent(
    commodity_indices::AbstractVector{<:Integer},
    net_supply_function;
    observed_variables::AbstractVector=EquilibriumVariableRef[],
    name::Symbol=:consumer,
) = NetSupplyAgent(
    commodity_indices,
    net_supply_function;
    variable_names=Symbol[],
    observed_variables=observed_variables,
    name=name,
)

"""
    ProducerAgent(commodity_indices, net_supply_function; kwargs...)

Create a producer with one or more bounded endogenous activity variables.
By default, automatic zero-profit conditions are paired with the variables.
"""
function ProducerAgent(
    commodity_indices::AbstractVector{<:Integer},
    net_supply_function;
    variable_names::AbstractVector{Symbol}=[:activity],
    variable_lower_bounds::AbstractVector{<:Real}=zeros(length(variable_names)),
    variable_upper_bounds::AbstractVector{<:Real}=fill(Inf, length(variable_names)),
    variable_start::Union{Nothing,AbstractVector{<:Real}}=nothing,
    observed_variables::AbstractVector=EquilibriumVariableRef[],
    condition_rule=nothing,
    name::Symbol=:producer,
)
    return NetSupplyAgent(
        commodity_indices,
        net_supply_function;
        variable_names=variable_names,
        variable_lower_bounds=variable_lower_bounds,
        variable_upper_bounds=variable_upper_bounds,
        variable_start=variable_start,
        observed_variables=observed_variables,
        condition_rule=condition_rule,
        name=name,
    )
end

"""
    NetSupplyEquilibriumModel

Canonical GEM equilibrium model containing agents, commodities, a fixed
numeraire, price bounds, and optional auxiliary variable-equation pairs.
"""
struct NetSupplyEquilibriumModel{T<:Real}
    agents::Vector{AbstractNetSupplyAgent}
    commodity_names::Vector{Symbol}
    commodity_index::Dict{Symbol,Int}
    auxiliary_variables::Vector{AuxiliaryVariable}
    auxiliary_variable_index::Dict{Symbol,Int}
    auxiliary_equations::Vector{AuxiliaryEquation}
    auxiliary_equation_index::Dict{Symbol,Int}
    numeraire_index::Int
    numeraire_value::T
    price_lower_bounds::Vector{T}
    price_upper_bounds::Vector{T}
end

function _check_price_bounds(lower_bounds, upper_bounds, n)
    length(lower_bounds) == n ||
        throw(DimensionMismatch(
            "price_lower_bounds length must equal the number of commodities.",
        ))
    length(upper_bounds) == n ||
        throw(DimensionMismatch(
            "price_upper_bounds length must equal the number of commodities.",
        ))
    all(x -> !isnan(x), lower_bounds) ||
        throw(ArgumentError("price_lower_bounds cannot contain NaN."))
    all(x -> !isnan(x), upper_bounds) ||
        throw(ArgumentError("price_upper_bounds cannot contain NaN."))
    all(lower_bounds .< upper_bounds) ||
        throw(ArgumentError(
            "Each price lower bound must be strictly below its upper bound.",
        ))
    return nothing
end

function _validate_auxiliary_variable(variable::AuxiliaryVariable)
    isempty(String(variable.name)) &&
        throw(ArgumentError("Auxiliary variable name cannot be empty."))
    isnan(variable.lower_bound) &&
        throw(ArgumentError("Auxiliary variable lower_bound cannot be NaN."))
    isnan(variable.upper_bound) &&
        throw(ArgumentError("Auxiliary variable upper_bound cannot be NaN."))
    variable.lower_bound < variable.upper_bound ||
        throw(ArgumentError(
            "Auxiliary variable lower_bound must be strictly below upper_bound.",
        ))
    isfinite(variable.start) ||
        throw(ArgumentError("Auxiliary variable start must be finite."))
    variable.lower_bound <= variable.start <= variable.upper_bound ||
        throw(ArgumentError(
            "Auxiliary variable start must lie within its bounds.",
        ))
    return nothing
end

function _validate_agent_observed_variable_references(
    agents,
    commodity_names,
    auxiliary_variables,
)
    agent_by_name = Dict(agent.name => agent for agent in agents)
    commodity_set = Set(commodity_names)
    auxiliary_set = Set(variable.name for variable in auxiliary_variables)

    for agent in agents
        for ref in agent.observed_variables
            if ref isa AgentVariableRef
                haskey(agent_by_name, ref.agent_name) ||
                    throw(ArgumentError(
                        "Economic agent $(agent.name) observes unknown agent " *
                        "$(ref.agent_name).",
                    ))
                ref.agent_name == agent.name &&
                    throw(ArgumentError(
                        "Economic agent $(agent.name) cannot observe its own variable " *
                        "$(ref.variable_name) through observed_variables; use " *
                        "local_variables instead.",
                    ))
                target = agent_by_name[ref.agent_name]
                ref.variable_name in target.variable_names ||
                    throw(ArgumentError(
                        "Economic agent $(agent.name) observes unknown variable " *
                        "$(ref.agent_name).$(ref.variable_name).",
                    ))
            elseif ref isa PriceVariableRef
                ref.commodity_name in commodity_set ||
                    throw(ArgumentError(
                        "Economic agent $(agent.name) observes unknown commodity " *
                        "price $(ref.commodity_name).",
                    ))
            elseif ref isa AuxiliaryVariableRef
                ref.variable_name in auxiliary_set ||
                    throw(ArgumentError(
                        "Economic agent $(agent.name) observes unknown auxiliary " *
                        "variable $(ref.variable_name).",
                    ))
            else
                throw(ArgumentError(
                    "Economic agent $(agent.name) contains an unsupported " *
                    "observed-variable reference type $(typeof(ref)).",
                ))
            end
        end
    end
    return nothing
end

function _validate_auxiliary_structure(
    agents,
    commodity_names,
    auxiliary_variables,
    auxiliary_equations,
)
    length(auxiliary_variables) == length(auxiliary_equations) ||
        throw(DimensionMismatch(
            "The number of auxiliary_variables must equal the number of " *
            "auxiliary_equations.",
        ))

    variable_names = Symbol[]
    for variable in auxiliary_variables
        variable isa AuxiliaryVariable ||
            throw(ArgumentError(
                "auxiliary_variables can contain only AuxiliaryVariable objects.",
            ))
        _validate_auxiliary_variable(variable)
        push!(variable_names, auxiliary_variable_name(variable))
    end
    length(unique(variable_names)) == length(variable_names) ||
        throw(ArgumentError("Auxiliary variable names must be unique."))

    equation_names = Symbol[]
    for equation in auxiliary_equations
        equation isa AuxiliaryEquation ||
            throw(ArgumentError(
                "auxiliary_equations can contain only AuxiliaryEquation objects.",
            ))
        push!(equation_names, auxiliary_equation_name(equation))
    end
    length(unique(equation_names)) == length(equation_names) ||
        throw(ArgumentError("Auxiliary equation names must be unique."))

    paired_names = Symbol[
        auxiliary_equation_paired_variable_name(equation)
        for equation in auxiliary_equations
    ]
    length(unique(paired_names)) == length(paired_names) ||
        throw(ArgumentError(
            "Each auxiliary variable must be paired with exactly one " *
            "auxiliary equation.",
        ))
    Set(paired_names) == Set(variable_names) ||
        throw(ArgumentError(
            "Auxiliary-equation paired variables must match auxiliary_variables " *
            "exactly.",
        ))

    agent_by_name = Dict(agent.name => agent for agent in agents)
    commodity_set = Set(commodity_names)
    auxiliary_set = Set(variable_names)

    for equation in auxiliary_equations
        for ref in auxiliary_equation_observed_variables(equation)
            if ref isa AgentVariableRef
                haskey(agent_by_name, ref.agent_name) ||
                    throw(ArgumentError(
                        "Auxiliary equation $(equation.name) observes unknown " *
                        "agent $(ref.agent_name).",
                    ))
                target = agent_by_name[ref.agent_name]
                ref.variable_name in target.variable_names ||
                    throw(ArgumentError(
                        "Auxiliary equation $(equation.name) observes unknown " *
                        "agent variable $(ref.agent_name).$(ref.variable_name).",
                    ))
            elseif ref isa PriceVariableRef
                ref.commodity_name in commodity_set ||
                    throw(ArgumentError(
                        "Auxiliary equation $(equation.name) observes unknown " *
                        "commodity price $(ref.commodity_name).",
                    ))
            elseif ref isa AuxiliaryVariableRef
                ref.variable_name in auxiliary_set ||
                    throw(ArgumentError(
                        "Auxiliary equation $(equation.name) observes unknown " *
                        "auxiliary variable $(ref.variable_name).",
                    ))
            else
                throw(ArgumentError(
                    "Auxiliary equation $(equation.name) contains an unsupported " *
                    "equilibrium-variable reference type $(typeof(ref)).",
                ))
            end
        end
    end
    return nothing
end

"""
    NetSupplyEquilibriumModel(agents, commodity_names; kwargs...)

Create and validate a net-supply equilibrium model.

Agent and commodity names must be unique. Every auxiliary variable must be
paired with exactly one auxiliary equation, and every declared observed
variable reference must resolve within the completed model.
"""
function NetSupplyEquilibriumModel(
    agents::AbstractVector,
    commodity_names::AbstractVector{Symbol};
    auxiliary_variables::AbstractVector=AuxiliaryVariable[],
    auxiliary_equations::AbstractVector=AuxiliaryEquation[],
    numeraire_index::Integer=1,
    numeraire_value::Real=1.0,
    price_lower_bounds::AbstractVector{<:Real}=zeros(length(commodity_names)),
    price_upper_bounds::AbstractVector{<:Real}=fill(Inf, length(commodity_names)),
)
    isempty(agents) &&
        throw(ArgumentError("The model must contain at least one economic agent."))
    all(agent -> agent isa AbstractNetSupplyAgent, agents) ||
        throw(ArgumentError(
            "agents can contain only V24-compatible AbstractNetSupplyAgent objects.",
        ))
    isempty(commodity_names) &&
        throw(ArgumentError("commodity_names cannot be empty."))
    length(unique(commodity_names)) == length(commodity_names) ||
        throw(ArgumentError("commodity_names cannot contain duplicates."))

    agent_names = Symbol[agent.name for agent in agents]
    length(unique(agent_names)) == length(agent_names) ||
        throw(ArgumentError(
            "Agent names must be unique when endogenous-variable references are enabled.",
        ))

    n = length(commodity_names)
    1 <= numeraire_index <= n ||
        throw(ArgumentError("numeraire_index is outside the commodity range."))
    isfinite(numeraire_value) && numeraire_value > 0 ||
        throw(ArgumentError("numeraire_value must be finite and positive."))

    _check_price_bounds(price_lower_bounds, price_upper_bounds, n)
    (price_lower_bounds[numeraire_index] <= numeraire_value <=
     price_upper_bounds[numeraire_index]) ||
        throw(ArgumentError(
            "numeraire_value must lie within the price bounds of the " *
            "numeraire commodity.",
        ))

    for agent in agents
        all(i -> 1 <= i <= n, agent.commodity_indices) ||
            throw(ArgumentError(
                "Economic agent $(agent.name) contains a commodity index " *
                "outside the model commodity range.",
            ))
    end

    aux_variables = AuxiliaryVariable[auxiliary_variables...]
    aux_equations = AuxiliaryEquation[auxiliary_equations...]

    _validate_agent_observed_variable_references(
        agents,
        commodity_names,
        aux_variables,
    )
    _validate_auxiliary_structure(
        agents,
        commodity_names,
        aux_variables,
        aux_equations,
    )

    names = collect(commodity_names)
    T = promote_type(
        Float64,
        typeof(numeraire_value),
        eltype(price_lower_bounds),
        eltype(price_upper_bounds),
    )

    return NetSupplyEquilibriumModel{T}(
        AbstractNetSupplyAgent[agents...],
        names,
        Dict(name => i for (i, name) in pairs(names)),
        aux_variables,
        Dict(variable.name => i for (i, variable) in pairs(aux_variables)),
        aux_equations,
        Dict(equation.name => i for (i, equation) in pairs(aux_equations)),
        Int(numeraire_index),
        T(numeraire_value),
        T.(price_lower_bounds),
        T.(price_upper_bounds),
    )
end

"""
    auxiliary_variables(model)

Return a copy of the model's auxiliary variables.
"""
auxiliary_variables(model::NetSupplyEquilibriumModel) =
    copy(model.auxiliary_variables)

"""
    auxiliary_equations(model)

Return a copy of the model's auxiliary equations.
"""
auxiliary_equations(model::NetSupplyEquilibriumModel) =
    copy(model.auxiliary_equations)

"""
    auxiliary_variable_count(model)

Return the number of auxiliary variables in the model.
"""
auxiliary_variable_count(model::NetSupplyEquilibriumModel) =
    length(model.auxiliary_variables)

"""
    auxiliary_equation_count(model)

Return the number of auxiliary equations in the model.
"""
auxiliary_equation_count(model::NetSupplyEquilibriumModel) =
    length(model.auxiliary_equations)

"""
    auxiliary_variable_index(model, name)

Return the model index of the named auxiliary variable.
"""
function auxiliary_variable_index(model::NetSupplyEquilibriumModel, name::Symbol)
    index = get(model.auxiliary_variable_index, name, 0)
    index > 0 || throw(ArgumentError("Unknown auxiliary variable $(name)."))
    return index
end

"""
    auxiliary_equation_index(model, name)

Return the model index of the named auxiliary equation.
"""
function auxiliary_equation_index(model::NetSupplyEquilibriumModel, name::Symbol)
    index = get(model.auxiliary_equation_index, name, 0)
    index > 0 || throw(ArgumentError("Unknown auxiliary equation $(name)."))
    return index
end

"""
    price_lower_bounds(model)

Return the model commodity-price lower bounds.
"""
price_lower_bounds(model::NetSupplyEquilibriumModel) = model.price_lower_bounds

"""
    price_upper_bounds(model)

Return the model commodity-price upper bounds.
"""
price_upper_bounds(model::NetSupplyEquilibriumModel) = model.price_upper_bounds

end # module EquilibriumNetSupplyModelV11
