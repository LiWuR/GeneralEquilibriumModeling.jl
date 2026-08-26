# ================================================================
# equilibrium_variable_refs_v3.jl
#
# Unified equilibrium-variable references for GEM V27.
#
# AgentVariableRef now comes from the independent agent core rather than a
# historical net-supply model version. All three reference types share the
# common AbstractEquilibriumVariableRef supertype.
# ================================================================

"""
    EquilibriumVariableRefsV3

Define symbolic references to agent variables, commodity prices, and
model-level auxiliary variables.
"""
module EquilibriumVariableRefsV3

using ..EquilibriumAgentCoreV1:
    AbstractEquilibriumVariableRef,
    AgentVariableRef

export AbstractEquilibriumVariableRef,
       AgentVariableRef,
       PriceVariableRef,
       AuxiliaryVariableRef,
       EquilibriumVariableRef,
       is_equilibrium_variable_ref

"""
    PriceVariableRef(commodity_name)

Reference the price of the commodity named `commodity_name`.
"""
struct PriceVariableRef <: AbstractEquilibriumVariableRef
    commodity_name::Symbol
end

"""
    AuxiliaryVariableRef(variable_name)

Reference the model-level auxiliary variable named `variable_name`.
"""
struct AuxiliaryVariableRef <: AbstractEquilibriumVariableRef
    variable_name::Symbol
end

Base.:(==)(a::PriceVariableRef, b::PriceVariableRef) =
    a.commodity_name == b.commodity_name
Base.hash(ref::PriceVariableRef, h::UInt) = hash(ref.commodity_name, h)

Base.:(==)(a::AuxiliaryVariableRef, b::AuxiliaryVariableRef) =
    a.variable_name == b.variable_name
Base.hash(ref::AuxiliaryVariableRef, h::UInt) = hash(ref.variable_name, h)

"""
    EquilibriumVariableRef

Alias for `AbstractEquilibriumVariableRef` used in reference collections.
"""
const EquilibriumVariableRef = AbstractEquilibriumVariableRef

"""
    is_equilibrium_variable_ref(ref)

Return `true` if `ref` is a supported equilibrium-variable reference.
"""
is_equilibrium_variable_ref(ref) = ref isa AbstractEquilibriumVariableRef

end # module EquilibriumVariableRefsV3
