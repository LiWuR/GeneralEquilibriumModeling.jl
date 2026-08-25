# ================================================================
# condition_agent_specs_v1.jl
#
# User-facing condition-agent specifications for GEMB.
#
# A condition agent represents endogenous equilibrium variables together
# with the conditions paired with those variables, but has no economic
# commodity demand or supply of its own.
#
# This file contains behavior specifications only. Variable names, starts,
# bounds, observed-variable references, the agent name, and the low-level
# zero-net-supply GEM adaptation belong to the builder layer.
# ================================================================

export AbstractConditionAgentSpec,
       ConditionAgentSpec


"""
    AbstractConditionAgentSpec

Abstract supertype for GEMB specifications whose endogenous agent variables
are determined directly by explicit equilibrium conditions rather than by
commodity-demand or commodity-supply behavior.

Condition-agent specifications describe conditions only. Variable names,
starting values, bounds, observed-variable references, agent names, and the
low-level zero-net-supply construction are supplied later by `build_agent`.
"""
abstract type AbstractConditionAgentSpec end


"""
    ConditionAgentSpec(condition_function)

Create a condition-agent specification.

`condition_function` must describe the conditions paired with the agent's
endogenous variables. The public function interface is

    condition_function(variables, observed_values)

and it must return one condition value for each endogenous agent variable.

The specification itself contains no commodity mapping and no commodity
demand or supply. The corresponding builder is responsible for adapting the
specification to GEM's `NetSupplyAgent` representation while keeping the
agent's net supply identically zero.

Typical uses include endogenous tax rates, subsidy rates, policy parameters,
closure variables, and other equilibrium variables determined by explicit
conditions.
"""
struct ConditionAgentSpec{F} <: AbstractConditionAgentSpec
    condition_function::F
end
