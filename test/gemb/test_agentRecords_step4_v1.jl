# ================================================================
# test_agentRecords_step4_v1.jl
#
# GEMB agent-record STEP 4:
# high-level Activity-demand agents retain their economic representation.
# ================================================================

using Test
using GeneralEquilibriumModeling

const _GEMB_AR4 = GeneralEquilibriumModeling.GEMB
const _GEM_AR4 = GeneralEquilibriumModeling.GEM


@testset "GEMB Activity-demand economic records STEP 4" begin
    model = _GEMB_AR4.GEMBModel(
        [
            :product,
            :product2,
            :labor,
            :capital,
            :claim,
        ];
        numeraire=:product,
    )

    # ------------------------------------------------------------
    # 1. Generic ActivityDemandSpec
    # ------------------------------------------------------------

    generic_spec = _GEMB_AR4.ActivityDemandSpec(
        (activity, prices) -> [
            0.4 * activity,
            0.6 * activity,
        ],
    )

    generic_agent = _GEMB_AR4.add_agent!(
        model,
        generic_spec;
        outputs=:product,
        demands=[:labor, :capital],
        activity_start=100.0,
        name=:generic,
    )

    record1 = model.agent_records[1]

    @test generic_agent === model.agents[1]
    @test record1 isa _GEMB_AR4.ActivityDemandAgentRecord
    @test record1.spec === generic_spec
    @test record1.output_indices == [1]
    @test record1.demand_indices == [3, 4]
    @test isempty(record1.endowment_indices)
    @test record1.claim_index === nothing
    @test record1.build_kwargs.activity_start == 100.0

    # ------------------------------------------------------------
    # 2. CES + CET output specification
    # ------------------------------------------------------------

    cet_spec = _GEMB_AR4.CETSpec(
        [0.5, 0.5];
        et=1.0,
    )

    ces_spec = _GEMB_AR4.CESSpec([1.0])

    _GEMB_AR4.add_agent!(
        model,
        ces_spec;
        outputs=[:product, :product2],
        output_spec=cet_spec,
        demands=:labor,
        activity_start=100.0,
        name=:cet,
    )

    record2 = model.agent_records[2]

    @test record2 isa _GEMB_AR4.ActivityDemandAgentRecord
    @test record2.spec === ces_spec
    @test record2.output_indices == [1, 2]
    @test record2.demand_indices == [3]
    @test record2.build_kwargs.output_spec === cet_spec

    # ------------------------------------------------------------
    # 3. Named ad-valorem claim
    # ------------------------------------------------------------

    claim_spec = _GEMB_AR4.CESSpec([1.0])

    _GEMB_AR4.add_agent!(
        model,
        claim_spec;
        outputs=:product,
        demands=:labor,
        claim=:claim,
        claim_rate=0.20,
        activity_start=100.0,
        name=:claimed,
    )

    record3 = model.agent_records[3]

    @test record3 isa _GEMB_AR4.ActivityDemandAgentRecord
    @test record3.spec === claim_spec
    @test record3.output_indices == [1]
    @test record3.demand_indices == [3]
    @test record3.claim_index == 5
    @test record3.build_kwargs.claim_rate == 0.20

    # ------------------------------------------------------------
    # 4. Activity-demand consumer with endowment
    # ------------------------------------------------------------

    consumer_spec = _GEMB_AR4.CESSpec([1.0])

    _GEMB_AR4.add_agent!(
        model,
        consumer_spec;
        demands=:product,
        endowments=:labor,
        endowment_quantities=100.0,
        activity_start=100.0,
        name=:consumer,
    )

    record4 = model.agent_records[4]

    @test record4 isa _GEMB_AR4.ActivityDemandAgentRecord
    @test record4.spec === consumer_spec
    @test isempty(record4.output_indices)
    @test record4.demand_indices == [1]
    @test record4.endowment_indices == [3]
    @test record4.build_kwargs.endowment_quantities == 100.0

    # ------------------------------------------------------------
    # 5. A non-Activity-demand specification remains net-supply-only
    # ------------------------------------------------------------

    marginal_spec = _GEMB_AR4.MarginalUtilityConsumerSpec(
        demand -> [1.0 / demand[1]],
    )

    _GEMB_AR4.add_agent!(
        model,
        marginal_spec;
        demands=:product,
        endowments=:labor,
        endowment_quantities=100.0,
        demand_start=100.0,
        multiplier_start=1.0,
        name=:marginal_consumer,
    )

    @test model.agent_records[5] isa
          _GEMB_AR4.NetSupplyOnlyAgentRecord

    # ------------------------------------------------------------
    # 6. Registry alignment and existing computational objects
    # ------------------------------------------------------------

    @test length(model.agents) ==
          length(model.agent_refs) ==
          length(model.agent_records) == 5

    @test all(
        agent -> agent isa _GEM_AR4.AbstractNetSupplyAgent,
        model.agents,
    )
end

println("GEMB Activity-demand economic-record STEP 4 tests passed.")
