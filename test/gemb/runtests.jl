using Test
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB

@testset "GEMB package" begin
    include("test_condition_agent_v1.jl")
    include("test_claimSemanticGenerality_v4.jl")
    include("test_claimInterfaceUserFacingCleanup_v2.jl")
    include("test_claimInterfaceCoreCleanup_v2.jl")
    include("test_agentBuilderRouter_userCleanup_v3.jl")
    include("test_relativeRefFileCleanup_v1.jl")
    include("test_intertemporalDocsPublicAPI_v3.jl")
    include("test_relativeAgentRefs_step7c2fix_v1.jl")
    include("test_agentTemplateEndowmentHelper_step7c2_v1.jl")
    include("test_addAgents_transaction_step7c1_v1.jl")
    include("test_agentTemplate_step7c1_v1.jl")
    include("test_agentTemplateUsesAddAgent_step7c2_v1.jl")
    include("test_directDatedAddAgent_step7b_v1.jl")
    include("test_byPeriodEndowmentValidation_step7a_v2.jl")
    include("test_periodVaryingClaimRate_step7a_v2.jl")
    include("test_byPeriod_step7a_v2.jl")







    include("test_agentVariableRef_agentRefStep4_v1.jl")

    include("test_agentRef_relativePeriodStep3_v2.jl")

    include("test_gembModel_agentRefStep2_v1.jl")

    include("test_agentRef_step1_v1.jl")

    # Intertemporal CommoditySpace cleanup STEP 6

    # ------------------------------------------------------------
    # Package-boundary tests
    # ------------------------------------------------------------

    @test isdefined(GEMB, :AbstractActivityDemandSpec)
    @test isdefined(GEMB, :ActivityDemandSpec)
    @test isdefined(GEMB, :activity_demand)

    @test !isdefined(GEMB, :AbstractDemandModifier)
    @test !isdefined(GEMB, :AdValoremClaim)
@test isdefined(GEMB, :_AbstractDemandModifier)
@test isdefined(GEMB, :_ClaimRateModifier)

    @test isdefined(GEMB, :CESSpec)
    @test isdefined(GEMB, :DCESSpec)
    @test isdefined(GEMB, :build_agent)

    # Legacy CES/DCES-specific claim specifications must be gone.
    @test !isdefined(GEMB, :CESClaimSpec)
    @test !isdefined(GEMB, :DCESClaimSpec)

    @test isdefined(GEM, :NetSupplyAgent)
    @test isdefined(GEM, :NetSupplyEquilibriumModel)
    @test isdefined(GEM, :EquilibriumResult)
    @test isdefined(GEM, :raw_result)

    # GEMB-specific behavioral specifications and builders
    # must not belong to GEM.
    @test !isdefined(GEM, :AbstractActivityDemandSpec)
    @test !isdefined(GEM, :ActivityDemandSpec)
    @test !isdefined(GEM, :AdValoremClaim)
    @test !isdefined(GEM, :CESSpec)
    @test !isdefined(GEM, :DCESSpec)
    @test !isdefined(GEM, :build_agent)

    # ------------------------------------------------------------
    # Core integration/regression tests
    # ------------------------------------------------------------

    include("test_equilibrium_result_v2.jl")

    # ------------------------------------------------------------
    # Activity-demand architecture
    # ------------------------------------------------------------

    include("test_activity_demand_spec_v3.jl")
    include("test_activityDemandBuilderDeadCodeCleanup_v3.jl")
    include("test_activityDemandProtocolOwnership_v4.jl")
    include("test_activity_demand_condition_rules_v3.jl")
    include("test_power_cet_regression_v3.jl")
    include("test_ces_v9_activity_demand_integration_v2.jl")

    # ------------------------------------------------------------
    # Generic ad valorem claim modifier
    # ------------------------------------------------------------

    include("test_activity_demand_claim_cleanup_v7.jl")

    # ------------------------------------------------------------
    # Consumer and production-function paths
    # ------------------------------------------------------------

    include("test_consumer_direct_dispatch_v3.jl")
    include("test_production_direct_dispatch_v3.jl")

    

    # ------------------------------------------------------------
    # Independent claim/policy mechanism regression
    # ------------------------------------------------------------

    include("test_specific_subsidy_claim_negative_price_v2.jl")

    include("test_claimRate_equilibrium_gemb_v1.jl")

    # ------------------------------------------------------------
    # Intertemporal equilibrium framework
    # ------------------------------------------------------------

    include("test_intertemporalPublicAPI_v8.jl")
    include("test_agentTemplateClaim_step7c2_v1.jl")
include("test_agentTemplateClaimEquilibrium_step7c2_v1.jl")

    # ------------------------------------------------------------
    # High-level asset-equilibrium interface
    # ------------------------------------------------------------

    include("test_assetEquilibriumAMSD_v1.jl")

    # ------------------------------------------------------------
    # Equilibrium statistics
    # ------------------------------------------------------------

    include("test_equilibriumStatistics_netSupplyMatrix_v2.jl")
    include("test_equilibriumStatistics_netSupplyValue_v3.jl")
    include("test_equilibriumStatistics_unified_v5.jl")
    include("test_equilibriumStatistics_print_v5.jl")
    include("test_equilibriumStatistics_agentLevels_v1.jl")

    # ------------------------------------------------------------
    # GEMBModel and CommoditySpace regression coverage
    # ------------------------------------------------------------

    include("test_commoditySpace_step2_v1.jl")
    include("test_gembModel_v1.jl")
    include("test_gembModel_commodityResolver_v1.jl")
    include("test_gembModel_commoditySpaceStep3_v1.jl")
    include("test_gembModel_commodityRefStep4_v1.jl")
    include("test_gembModel_addAgentCoverage_v2.jl")
    include("test_gembModel_claimName_v1.jl")
    include("test_gembModel_noPureEndowment_v1.jl")
    include("test_gembModel_buildModel_v1.jl")
    include("test_gembModel_solveEquivalence_v1.jl")

    # ------------------------------------------------------------
    # Custom net-supply-agent high-level interface
    # ------------------------------------------------------------

    include("test_gemb_add_existing_net_supply_agent_v1.jl")
    include("test_gemb_add_net_supply_agent_v1.jl")
    include("test_gemb_net_supply_agent_docs_v2.jl")

    # ------------------------------------------------------------
    # Virtual-agent closure regression
    # ------------------------------------------------------------

    include("test_exogenousLandPrice_virtualAgent_v1.jl")
end




# ------------------------------------------------------------
# Equilibrium statistics display
# ------------------------------------------------------------

# ------------------------------------------------------------
# Equilibrium statistics agent levels
# ------------------------------------------------------------
