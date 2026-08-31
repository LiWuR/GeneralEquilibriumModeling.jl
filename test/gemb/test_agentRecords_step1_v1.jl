using Test
using GeneralEquilibriumModeling

const _GEMB_AR1 = GeneralEquilibriumModeling.GEMB

@testset "GEMB agent records STEP 1" begin
    @test isdefined(_GEMB_AR1, :AbstractAgentRecord)
    @test isdefined(_GEMB_AR1, :ActivityDemandAgentRecord)
    @test isdefined(_GEMB_AR1, :NetSupplyOnlyAgentRecord)

    spec = _GEMB_AR1.ActivityDemandSpec(
        (activity, prices) -> [0.4 * activity, 0.6 * activity],
    )

    kwargs = (
        output_coefficients=[1.0],
        claim_rate=0.20,
        observed_variables=Any[],
    )

    record = _GEMB_AR1.ActivityDemandAgentRecord(
        spec,
        [1],
        [2, 3],
        [4];
        claim_index=5,
        build_kwargs=kwargs,
    )

    @test record isa _GEMB_AR1.AbstractAgentRecord
    @test record.spec === spec
    @test record.output_indices == [1]
    @test record.demand_indices == [2, 3]
    @test record.endowment_indices == [4]
    @test record.claim_index == 5
    @test record.build_kwargs === kwargs

    outputs = [1]
    demands = [2, 3]
    endowments = [4]

    copied = _GEMB_AR1.ActivityDemandAgentRecord(
        spec,
        outputs,
        demands,
        endowments,
    )

    outputs[1] = 99
    demands[1] = 99
    endowments[1] = 99

    @test copied.output_indices == [1]
    @test copied.demand_indices == [2, 3]
    @test copied.endowment_indices == [4]
    @test copied.claim_index === nothing
    @test copied.build_kwargs == NamedTuple()

    net_only = _GEMB_AR1.NetSupplyOnlyAgentRecord()
    @test net_only isa _GEMB_AR1.AbstractAgentRecord

    # The STEP 1 record types remain valid after later GEMBModel integration.
    model = _GEMB_AR1.GEMBModel([:product, :labor])
    @test hasfield(typeof(model), :agent_records)
    @test isempty(model.agents)
    @test isempty(model.agent_refs)
    @test isempty(model.agent_records)
end

println("GEMB agent records STEP 1 tests passed.")
