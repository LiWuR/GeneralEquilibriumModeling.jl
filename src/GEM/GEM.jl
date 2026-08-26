"""
    GEM

General equilibrium modeling tools based on net-supply agents and mixed
complementarity problems solved through JuMP and PATH.
"""
module GEM

# ================================================================
# GEM.jl
#
# Stable package entry point.
#
# GEM contains the equilibrium representation, condition system,
# auxiliary-variable/equation infrastructure, JuMP model construction,
# PATH solver interface, and equilibrium result types.
#
# Economic specifications and builders that do not belong to the
# equilibrium core are maintained separately in GEMB.
# ================================================================


# ----------------------------------------------------------------
# 1. Core result and agent protocol
# ----------------------------------------------------------------

include(joinpath(@__DIR__, "equilibrium_result_v1.jl"))
include(joinpath(@__DIR__, "equilibrium_agent_core_profit_conditions_v5.jl"))


# ----------------------------------------------------------------
# 2. Unified equilibrium-variable references and auxiliary infrastructure
# ----------------------------------------------------------------

include(joinpath(@__DIR__, "equilibrium_variable_refs_v3.jl"))
include(joinpath(@__DIR__, "auxiliary_variables_v1.jl"))
include(joinpath(@__DIR__, "auxiliary_equations_v4.jl"))


# ----------------------------------------------------------------
# 3. Net-supply equilibrium model
# ----------------------------------------------------------------

include(joinpath(@__DIR__, "equilibrium_model_net_supply_profit_conditions_v4.jl"))


# ----------------------------------------------------------------
# 4. Economic equilibrium-condition layers
# ----------------------------------------------------------------

include(joinpath(@__DIR__, "equilibrium_model_marginal_utility_v5.jl"))
include(joinpath(@__DIR__, "producer_conditions_v1.jl"))
include(joinpath(@__DIR__, "production_net_supply_v1.jl"))


# ----------------------------------------------------------------
# 5. JuMP construction and MCP/PATH solver
# ----------------------------------------------------------------

include(joinpath(@__DIR__, "equilibrium_jump_model_v2.jl"))
include(joinpath(@__DIR__, "auxiliary_equation_jump_v1.jl"))
include(joinpath(@__DIR__, "solve_equilibrium_model_mcp_jump_v10_v19.jl"))


# ================================================================
# Public bindings
# ================================================================

using .EquilibriumNetSupplyModelV11:
    AbstractNetSupplyAgent,
    AbstractAgentConditionRule,
    UnitProfitConditions,
    TotalProfitConditions,
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

using .AuxiliaryVariablesV1:
    auxiliary_variable_name,
    auxiliary_variable_lower_bound,
    auxiliary_variable_upper_bound,
    auxiliary_variable_start

using .AuxiliaryEquationsV4:
    auxiliary_equation_name,
    auxiliary_equation_paired_variable,
    auxiliary_equation_paired_variable_name,
    auxiliary_equation_function,
    auxiliary_equation_observed_variables,
    auxiliary_equation_observed_variable_count,
    auxiliary_equation_value

using .EquilibriumMarginalUtilityModelV5:
    MarginalUtilityConsumerConditions,
    evaluate_marginal_utility

using .ProducerConditionsV1:
    StationaryProductionConditions,
    CostMinimizationKKTConditions,
    evaluate_production,
    evaluate_marginal_product,
    evaluate_total_loss

using .ProductionNetSupplyV1:
    ProductionNetSupply,
    production_net_supply

using .EquilibriumJumpModelV2:
    EquilibriumJumpLayout,
    EquilibriumVariableResolution,
    resolve_equilibrium_variable_ref,
    resolve_equilibrium_variable_refs,
    equilibrium_variable_position,
    equilibrium_reference_value

using .EquilibriumModelSolverV10V19:
    PATHSolverLicenseError,
    solve_net_supply_equilibrium_mcp_jump,
    solve_equilibrium_model_mcp_jump,
    solve_equilibrium_model_mcp_jump_v10_v19,
    print_equilibrium_model_result

using .EquilibriumResultV1:
    EquilibriumResult,
    raw_result


# ================================================================
# Public aliases
# ================================================================

"""
    EquilibriumModel

Alias for `NetSupplyEquilibriumModel`.
"""
const EquilibriumModel = NetSupplyEquilibriumModel

"""
    FunctionalAgent

Alias for `NetSupplyAgent`.
"""
const FunctionalAgent = NetSupplyAgent

"""
    ConsumerAgent

Alias for `NetSupplyConsumerAgent`.
"""
const ConsumerAgent = NetSupplyConsumerAgent


# ================================================================
# Public API
# ================================================================

export EquilibriumModel
export NetSupplyEquilibriumModel

export AbstractNetSupplyAgent
export AbstractAgentConditionRule
export UnitProfitConditions
export TotalProfitConditions
export ExplicitAgentConditions

export AgentVariableRef
export PriceVariableRef
export AuxiliaryVariableRef

export AuxiliaryVariable
export AuxiliaryEquation

export MarginalUtilityConsumerConditions
export evaluate_marginal_utility

export StationaryProductionConditions
export CostMinimizationKKTConditions
export evaluate_production
export evaluate_marginal_product
export evaluate_total_loss

export ProductionNetSupply
export production_net_supply

export FunctionalAgent
export NetSupplyAgent
export ConsumerAgent
export NetSupplyConsumerAgent
export ProducerAgent

export agent_name
export agent_commodity_indices
export agent_variable_count
export agent_condition_rule
export agent_uses_automatic_conditions
export agent_observed_variables
export agent_observed_variable_count
export agent_net_supply

export auxiliary_variables
export auxiliary_equations
export auxiliary_variable_count
export auxiliary_equation_count
export auxiliary_variable_index
export auxiliary_equation_index

export auxiliary_variable_name
export auxiliary_variable_lower_bound
export auxiliary_variable_upper_bound
export auxiliary_variable_start

export auxiliary_equation_name
export auxiliary_equation_paired_variable
export auxiliary_equation_paired_variable_name
export auxiliary_equation_function
export auxiliary_equation_observed_variables
export auxiliary_equation_observed_variable_count
export auxiliary_equation_value

export price_lower_bounds
export price_upper_bounds

export EquilibriumJumpLayout
export EquilibriumVariableResolution
export resolve_equilibrium_variable_ref
export resolve_equilibrium_variable_refs
export equilibrium_variable_position
export equilibrium_reference_value

export PATHSolverLicenseError
export solve_net_supply_equilibrium_mcp_jump
export solve_equilibrium_model_mcp_jump
export solve_equilibrium_model_mcp_jump_v10_v19
export print_equilibrium_model_result

export EquilibriumResult
export raw_result

end # module GEM
