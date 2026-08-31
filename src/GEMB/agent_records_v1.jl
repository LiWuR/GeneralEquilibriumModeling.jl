# ================================================================
# agent_records_v1.jl
#
# Economic-structure records for the GEMB high-level framework.
# STEP 1 only defines record types. No GEMBModel field or computational
# pathway depends on these types yet.
# ================================================================

abstract type AbstractAgentRecord end

struct ActivityDemandAgentRecord{S,K} <: AbstractAgentRecord
    spec::S
    output_indices::Vector{Int}
    demand_indices::Vector{Int}
    endowment_indices::Vector{Int}
    claim_index::Union{Nothing,Int}
    build_kwargs::K
end

function ActivityDemandAgentRecord(
    spec::AbstractActivityDemandSpec,
    output_indices,
    demand_indices,
    endowment_indices;
    claim_index=nothing,
    build_kwargs=NamedTuple(),
)
    outputs = Int.(collect(output_indices))
    demands = Int.(collect(demand_indices))
    endowments = Int.(collect(endowment_indices))
    normalized_claim_index = claim_index === nothing ? nothing : Int(claim_index)

    return ActivityDemandAgentRecord{typeof(spec),typeof(build_kwargs)}(
        spec,
        outputs,
        demands,
        endowments,
        normalized_claim_index,
        build_kwargs,
    )
end

struct NetSupplyOnlyAgentRecord <: AbstractAgentRecord end
