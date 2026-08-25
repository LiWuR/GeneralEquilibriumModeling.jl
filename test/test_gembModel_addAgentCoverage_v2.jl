# ================================================================
# test_gembModel_addAgentCoverage_v2.jl
#
# STEP 4 regression tests for the current GEMBModel add_agent! layer.
#
# This test targets the CURRENT GEMB builder architecture:
#
#   - AbstractActivityDemandSpec family:
#       ActivityDemandSpec, CESSpec, DCESSpec, PowerProductionSpec
#   - CETSpec through output_spec
#   - claim_rate with a NAME-BASED claim commodity
#   - MarginalUtilityConsumerSpec
#   - concrete AbstractMarginalUtilitySpec
#   - MarshallDemandConsumerSpec
#   - ProductionFunctionSpec
#
# Current GEMB has no pure-endowment builder path; this test does not add one.
#
# No equilibrium is solved here. build_model and solve belong to STEP 5/6.
# ================================================================

using Test
using GEM
using GEMB


@testset "GEMBModel STEP 4 current builder coverage" begin

    model = GEMBModel(
        [
            :output,
            :output2,
            :labor,
            :capital,
            :consumption,
            :claim,
        ];
        numeraire=:output,
    )


    # ------------------------------------------------------------
    # 1. CESSpec producer
    # ------------------------------------------------------------

    ces = add_agent!(
        model,
        CESSpec([0.5, 0.5]);
        outputs=:output,
        demands=[:labor, :capital],
        activity_start=10.0,
        name=:ces,
    )

    @test ces isa GEM.AbstractNetSupplyAgent


    # ------------------------------------------------------------
    # 2. DCESSpec producer
    # ------------------------------------------------------------

    dces = add_agent!(
        model,
        DCESSpec(
            [0.5, 0.5];
            xi=[0.1, 0.2],
        );
        outputs=:output,
        demands=[:labor, :capital],
        activity_start=10.0,
        name=:dces,
    )

    @test dces isa GEM.AbstractNetSupplyAgent


    # ------------------------------------------------------------
    # 3. Generic ActivityDemandSpec producer
    # ------------------------------------------------------------

    activity_spec = ActivityDemandSpec(
        (activity, prices) -> [
            0.4 * activity,
            0.6 * activity,
        ],
    )

    generic_activity = add_agent!(
        model,
        activity_spec;
        outputs=:output,
        demands=[:labor, :capital],
        activity_start=10.0,
        name=:generic_activity,
    )

    @test generic_activity isa GEM.AbstractNetSupplyAgent


    # ------------------------------------------------------------
    # 4. PowerProductionSpec
    # ------------------------------------------------------------

    power = add_agent!(
        model,
        PowerProductionSpec(
            alpha=1.0,
            theta=0.8,
        );
        outputs=:output,
        demands=:labor,
        activity_start=10.0,
        name=:power,
    )

    @test power isa GEM.AbstractNetSupplyAgent


    # ------------------------------------------------------------
    # 5. CET output_spec
    #
    # output_spec uses the already name-resolved outputs, so no
    # extra commodity mapping layer is required.
    # ------------------------------------------------------------

    cet = add_agent!(
        model,
        CESSpec([1.0]);
        outputs=[:output, :output2],
        output_spec=CETSpec(
            [0.5, 0.5];
            et=1.0,
        ),
        demands=:labor,
        activity_start=10.0,
        name=:cet,
    )

    @test cet isa GEM.AbstractNetSupplyAgent


    # ------------------------------------------------------------
    # 6. Ad-valorem claim through name-based claim mapping
    #
    # High level:
    #     claim=:claim
    #
    # Low level:
    #     claim_index=6
    # ------------------------------------------------------------

    claim_agent = add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:output,
        demands=:labor,
        claim=:claim,
        claim_rate=0.2,
        activity_start=10.0,
        name=:claim_agent,
    )

    @test claim_agent isa GEM.AbstractNetSupplyAgent


    # ------------------------------------------------------------
    # 7. Explicit MarginalUtilityConsumerSpec
    # ------------------------------------------------------------

    marginal = add_agent!(
        model,
        MarginalUtilityConsumerSpec(
            demand -> [1.0 / demand[1]],
        );
        demands=:consumption,
        endowments=:labor,
        endowment_quantities=10.0,
        demand_start=1.0,
        multiplier_start=1.0,
        name=:marginal_consumer,
    )

    @test marginal isa GEM.AbstractNetSupplyAgent


    # ------------------------------------------------------------
    # 8. Concrete AbstractMarginalUtilitySpec
    # ------------------------------------------------------------

    analytic_mu = add_agent!(
        model,
        CESMarginalUtilitySpec(
            [1.0];
            es=1.0,
        );
        demands=:consumption,
        endowments=:labor,
        endowment_quantities=10.0,
        demand_start=1.0,
        multiplier_start=1.0,
        name=:analytic_mu_consumer,
    )

    @test analytic_mu isa GEM.AbstractNetSupplyAgent


    # ------------------------------------------------------------
    # 9. MarshallDemandConsumerSpec
    # ------------------------------------------------------------

    marshall = add_agent!(
        model,
        MarshallDemandConsumerSpec(
            (income, prices) -> [
                income / prices[1],
            ],
        );
        demands=:consumption,
        endowments=:labor,
        endowment_quantities=10.0,
        name=:marshall_consumer,
    )

    @test marshall isa GEM.AbstractNetSupplyAgent


    # ------------------------------------------------------------
    # 10. ProductionFunctionSpec
    # ------------------------------------------------------------

    production = add_agent!(
        model,
        ProductionFunctionSpec(
            inputs -> sqrt(inputs[1]),
            inputs -> [0.5 / sqrt(inputs[1])];
            behavior=:stationary,
        );
        outputs=:output,
        demands=:labor,
        activity_start=2.0,
        demand_start=4.0,
        production_multiplier_start=1.0,
        name=:production_function,
    )

    @test production isa GEM.AbstractNetSupplyAgent


    # ------------------------------------------------------------
    # 11. All names are registered in insertion order
    # ------------------------------------------------------------

    expected_names = [
        :ces,
        :dces,
        :generic_activity,
        :power,
        :cet,
        :claim_agent,
        :marginal_consumer,
        :analytic_mu_consumer,
        :marshall_consumer,
        :production_function,
    ]

    @test length(model.agents) == length(expected_names)

    for (i, name) in pairs(expected_names)
        @test model.agent_index[name] == i
    end


    # ------------------------------------------------------------
    # 12. claim requires claim_rate and remains transactional
    # ------------------------------------------------------------

    before_agents = copy(model.agents)
    before_index = copy(model.agent_index)

    @test_throws ArgumentError add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:output,
        demands=:labor,
        claim=:claim,
        name=:claim_without_rate,
    )

    @test model.agents == before_agents
    @test model.agent_index == before_index


    # ------------------------------------------------------------
    # 13. Unknown claim commodity fails before build_agent
    # ------------------------------------------------------------

    @test_throws ArgumentError add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:output,
        demands=:labor,
        claim=:missing_claim,
        claim_rate=0.2,
        name=:unknown_claim,
    )

    @test model.agents == before_agents
    @test model.agent_index == before_index


    # ------------------------------------------------------------
    # 14. Low-level claim_index is rejected by high-level API
    # ------------------------------------------------------------

    @test_throws ArgumentError add_agent!(
        model,
        CESSpec([1.0]);
        outputs=:output,
        demands=:labor,
        claim_index=6,
        claim_rate=0.2,
        name=:low_level_claim,
    )

    @test model.agents == before_agents
    @test model.agent_index == before_index
end

println("GEMBModel STEP 4 current builder coverage tests passed.")
