import Pkg

Pkg.activate(@__DIR__)
Pkg.instantiate()

using Documenter
using GeneralEquilibriumModeling
using GeneralEquilibriumModeling.GEM
using GeneralEquilibriumModeling.GEMB

# BEGIN GENERATED NAVIGATION
DOC_PAGES = [
    "Home" => "index.md",
    "GEM" => [
        "Overview" => "gem/index.md",
        "API Reference" => [
            "API index" => "gem/api.md",
            "Core API" => [
                "Public API" => "gem/api/GEM.md",
                "Agents and condition rules" => "gem/api/GEM_EquilibriumAgentCoreV1.md",
                "Equilibrium models" => "gem/api/GEM_EquilibriumNetSupplyModelV11.md",
                "Variable references" => "gem/api/GEM_EquilibriumVariableRefsV3.md",
                "Production conditions" => "gem/api/GEM_ProducerConditionsV1.md",
                "Marginal-utility conditions" => "gem/api/GEM_EquilibriumMarginalUtilityModelV5.md",
                "Production net supply" => "gem/api/GEM_ProductionNetSupplyV1.md",
                "Equilibrium results" => "gem/api/GEM_EquilibriumResultV1.md",
            ],
            "Auxiliary system" => [
                "Auxiliary variables" => "gem/api/GEM_AuxiliaryVariablesV1.md",
                "Auxiliary equations" => "gem/api/GEM_AuxiliaryEquationsV4.md",
                "Auxiliary-equation JuMP support" => "gem/api/GEM_AuxiliaryEquationJumpV1.md",
            ],
            "JuMP and solver" => [
                "Equilibrium JuMP model" => "gem/api/GEM_EquilibriumJumpModelV2.md",
                "MCP solver" => "gem/api/GEM_EquilibriumModelSolverV10V19.md",
            ],
        ],
        "Examples" => [
            "Cobb–Douglas exchange" => "gem/examples/gem_CD_consumerNoVariables_nc2_na2.md",
            "Cost-minimization KKT" => "gem/examples/gem_CD_costMinKKT_nc2_na2.md",
            "Explicit conditions" => "gem/examples/gem_CD_explicitConditions_nc2_na2.md",
            "Marginal utility" => "gem/examples/gem_CD_marginalUtility_nc2_na2.md",
            "Ad valorem claim" => "gem/examples/gem_CD_adValoremClaim_consumerNoVariables_nc3_na2.md",
            "Specific subsidy via claim" => "gem/examples/gem_CD_specificSubsidyClaim_consumerNoVariables_nc3_na2.md",
            "Externality and observed variables" => "gem/examples/gem_CD_externality_observedVariable_consumerNoVariables_nc2_na2.md",
            "Pollution with negative price" => "gem/examples/gem_pollution_negativePrice_nc3_na2.md",
            "von Neumann multi-activity" => "gem/examples/gem_vonNeumann_multiActivity_nc2_na1.md",
        ],
    ],
    "GEMB" => [
        "Overview" => "gemb/index.md",
        "Guides" => [
            "Ad valorem claims" => "gemb/ad_valorem_claims.md",
            "Condition agents" => "gemb/condition_agents.md",
            "Custom net-supply agents" => "gemb/custom_net_supply_agents.md",
            "Intertemporal equilibrium" => "gemb/intertemporal_equilibrium.md",
            "Equilibrium statistics" => "gemb/equilibrium_statistics.md",
        ],
        "API Reference" => [
            "API index" => "gemb/api.md",
            "Public API" => "gemb/api/GEMB.md",
            "Specifications and economic functions" => "gemb/api/GEMB_Specifications.md",
            "Agent builders and condition agents" => "gemb/api/GEMB_AgentBuilders.md",
            "High-level model and intertemporal API" => "gemb/api/GEMB_ModelingFramework.md",
            "Equilibrium statistics" => "gemb/api/GEMB_EquilibriumStatistics.md",
            "Asset equilibrium" => "gemb/api/GEMB_AssetEquilibrium.md",
        ],
        "Examples" => [
            "Core and static models" => [
                "CES" => "gemb/examples/gemb_CES_nc2_na2_v4.md",
                "CES with tax" => "gemb/examples/gemb_CES_tax_nc4_na3_v3.md",
                "CES–CET" => "gemb/examples/gemb_CES_CET_nc4_na2_v2.md",
                "Activity-demand Cobb–Douglas" => "gemb/examples/gemb_activityDemand_CD_nc2_na2_v2.md",
                "Explicit condition rule" => "gemb/examples/gemb_conditionRule_explicit_nc2_na2_v1.md",
                "Unit-profit condition rule" => "gemb/examples/gemb_conditionRule_UREBC_nc2_na2_v2.md",
                "Custom net-supply agent" => "gemb/examples/custom_net_supply_agent.md",
            ],
            "Claims and taxes" => [
                "Specific subsidy via claim" => "gemb/examples/gemb_CD_specificSubsidyClaim_nc3_na2_v1.md",
                "Endogenous claim rate" => "gemb/examples/gemb_CD_endogenousClaimRate_nc3_na3_v2.md",
                "Budget-balanced claim rate" => "gemb/examples/gemb_CD_endogenousClaimRateBudget_nc3_na4_v2.md",
            ],
            "Virtual-agent constructions" => [
                "Exogenous land price" => "gemb/examples/gemb_exogenousLandPrice_nc3_na3_v6.md",
                "Virtual-agent land-price model" => "gemb/examples/gemb_exogenousLandPrice_virtualAgent_nc3_na3_v3.md",
            ],
            "Asset equilibrium" => [
                "Asset equilibrium (AMSD)" => "gemb/examples/gemb_assetEquilibriumAMSD_nc5_na3_v1.md",
            ],
            "Intertemporal models" => [
                "Intertemporal CES" => "gemb/examples/gemb_intertemporalEquilibriumCES_nct2_nat2_v5.md",
                "Intertemporal CES marginal utility" => "gemb/examples/gemb_intertemporalEquilibriumCESMarginal_nct2_nat2_v2.md",
                "Intertemporal CES with claim" => "gemb/examples/gemb_intertemporalEquilibriumCESClaim_nct3_nat3_v3.md",
                "Endogenous interest rate" => "gemb/examples/gemb_intertemporalEquilibrium_endogenousInterestRate_nct2_nat3_v1.md",
                "Variable claim" => "gemb/examples/gemb_intertemporalEquilibrium_variableClaim_nct3_nat3_v1.md",
            ],
        ],
    ],
]
# END GENERATED NAVIGATION


makedocs(
    pages = DOC_PAGES,
    sitename = "GeneralEquilibriumModeling.jl",
    checkdocs = :none,
    modules = [
        GeneralEquilibriumModeling,
        GeneralEquilibriumModeling.GEM,
        GeneralEquilibriumModeling.GEMB,
    ],
    remotes = nothing,
    format = Documenter.HTML(
        repolink = "https://github.com/LiWuR/GeneralEquilibriumModeling.jl",
        edit_link = "main",
        prettyurls = get(ENV, "CI", "false") == "true",
    ),
)

if get(ENV, "CI", "false") == "true" &&
   get(ENV, "GITHUB_REPOSITORY", "") ==
   "LiWuR/GeneralEquilibriumModeling.jl"

    deploydocs(
        repo = "github.com/LiWuR/GeneralEquilibriumModeling.jl.git",
        devbranch = "main",
        push_preview = true,
    )
end
