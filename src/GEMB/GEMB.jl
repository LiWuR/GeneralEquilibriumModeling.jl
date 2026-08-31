module GEMB

import ..GEM


# ================================================================
# 1. Numerical functions
# ================================================================

include("CES_v9.jl")


# ================================================================
# 2. Behavioral specifications
# ================================================================

include("consumer_specs_v1.jl")
include("producer_specs_v1.jl")
include("condition_agent_specs_v1.jl")
include("activity_demand_specs_v5.jl")
include("activity_supply_specs_v1.jl")


# ================================================================
# 3. Marginal-utility specifications
# ================================================================

include("marginal_utility_specs_v5.jl")


# ================================================================
# 4. Demand modifiers
# ================================================================

include("demand_modifiers_v4.jl")


# ================================================================
# 5. Agent-builder infrastructure
# ================================================================

include("agent_builder_utils_v1.jl")


# ================================================================
# 6. Agent-builder implementations
# ================================================================

include("activity_demand_agent_builder_v6.jl")
include("condition_agent_builder_v5.jl")
include("marginal_utility_consumer_builder_v2.jl")
include("marshall_demand_consumer_builder_v2.jl")
include("production_function_agent_builder_v2.jl")


# ================================================================
# 8. High-level equilibrium specifications
# ================================================================

include("commodity_space_v3.jl")
include("agent_ref_v2.jl")


# ================================================================
# 9. High-level equilibrium interfaces
# ================================================================

include("asset_equilibrium_amsd_v1.jl")


# ================================================================
# 10. Public API
# ================================================================

export CES,
       DCES,
       CESSpec,
       DCESSpec,
       PowerProductionSpec,
       AbstractActivityDemandSpec,
       ActivityDemandSpec,
       activity_demand,
       AbstractActivitySupplySpec,
       CETSpec,
       activity_supply,
       MarginalUtilityConsumerSpec,
       MarshallDemandConsumerSpec,
       ProductionFunctionSpec,
       build_agent,
       AbstractMarginalUtilitySpec,
       LinearMarginalUtilitySpec,
       CESMarginalUtilitySpec,
       QuadraticMarginalUtilitySpec,
       MeanStandardDeviationMarginalUtilitySpec,
       marginal_utility,
       marginal_utility_function,
       CommodityRef,
       RelativePeriod,
       solve_asset_equilibrium_amsd

# ================================================================
# High-level mutable equilibrium model
# ================================================================
# ================================================================
# High-level economic-agent records
# ================================================================
include("agent_records_v1.jl")

include("gemb_model_v19.jl")

# ================================================================
# Single-agent gross demand and gross supply evaluation
# ================================================================
include("agent_demand_supply_v1.jl")

# ================================================================
# Model-wide gross demand and gross supply matrices
# ================================================================
include("demand_supply_matrices_v1.jl")
include("by_period_v1.jl")
include("relative_period_v1.jl")
include("relative_agent_refs_v1.jl")
include("agent_template_v2.jl")
include("relative_agent_variable_refs_v1.jl")
include("relative_commodity_refs_v1.jl")
include("agent_template_expansion_v2.jl")
# ================================================================
# GEMBModel public API
# ================================================================
export GEMBModel,
       add_agent!,
       add_net_supply_agent!,
       build_model,
       solve
# ================================================================
# General structured-commodity API
# ================================================================
export CommoditySpec, CommoditySpace

# ================================================================
# General structured-agent identity API
# ================================================================
export AgentRef

# ================================================================
# Equilibrium statistics
# ================================================================
include("equilibrium_statistics_v5.jl")
export net_supply_matrix

export net_supply_value_matrix

export agent_net_supply_values

export equilibrium_statistics

export print_equilibrium_statistics

end # module GEMB
