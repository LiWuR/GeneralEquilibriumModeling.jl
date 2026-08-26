# ================================================================
# equilibrium_result_v1.jl
#
# Stable public wrapper for GEM equilibrium-solver results.
#
# V1 preserves the complete NamedTuple returned by the existing
# solver. Property access is forwarded so existing code such as
#
#     result.prices
#     result.solved
#     result.agent_variable_values
#
# continues to work unchanged.
# ================================================================

"""
    EquilibriumResultV1

Provide the stable public wrapper used for GEM equilibrium-solver results.
"""
module EquilibriumResultV1

export EquilibriumResult,
       raw_result


"""
    EquilibriumResult(data)

Wrap the solver result `data` while forwarding property access, indexing,
iteration, and collection-style queries to the underlying named tuple.
"""
struct EquilibriumResult{T<:NamedTuple}
    data::T
end


"""
    raw_result(result::EquilibriumResult)

Return the underlying solver NamedTuple.
"""
raw_result(result::EquilibriumResult) =
    getfield(result, :data)


function Base.getproperty(
    result::EquilibriumResult,
    name::Symbol,
)
    name === :data && return getfield(result, :data)

    return getproperty(
        getfield(result, :data),
        name,
    )
end


function Base.propertynames(
    result::EquilibriumResult,
    private::Bool=false,
)
    names = propertynames(
        getfield(result, :data),
        private,
    )

    return private ? (:data, names...) : names
end


Base.getindex(
    result::EquilibriumResult,
    name::Symbol,
) = getproperty(result, name)


Base.keys(result::EquilibriumResult) =
    keys(getfield(result, :data))


Base.values(result::EquilibriumResult) =
    values(getfield(result, :data))


Base.pairs(result::EquilibriumResult) =
    pairs(getfield(result, :data))


Base.length(result::EquilibriumResult) =
    length(getfield(result, :data))


Base.iterate(
    result::EquilibriumResult,
    state...,
) = iterate(getfield(result, :data), state...)


end # module EquilibriumResultV1
