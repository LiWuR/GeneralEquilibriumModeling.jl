# ================================================================
# test_gemb_add_net_supply_agent_v1.jl
#
# STEP 3 regression tests for the high-level custom net-supply-agent API.
# ================================================================

using Test
using GeneralEquilibriumModeling

const GEM = GeneralEquilibriumModeling.GEM
const GEMB = GeneralEquilibriumModeling.GEMB


@testset "GEMB add_net_supply_agent! STEP 3" begin

    # ------------------------------------------------------------
    # 1. Ordinary Symbol selectors are resolved to GEM indices.
    # ------------------------------------------------------------

    model =
        GEMB.GEMBModel(
            [:product, :labor];
            numeraire=:product,
        )

    consumer_supply =
        (local_variables, local_prices, observed_values=Any[]) -> [
            -local_variables[1],
            100.0 - local_variables[2],
        ]

    consumer_conditions =
        (local_variables, local_prices, net_supply) -> [
            local_variables[3] * local_prices[1] - 0.5 / local_variables[1],
            local_variables[3] * local_prices[2] - 0.5 / local_variables[2],
            100.0 * local_prices[2] -
                local_prices[1] * local_variables[1] -
                local_prices[2] * local_variables[2],
        ]

    consumer =
        GEMB.add_net_supply_agent!(
            model,
            consumer_supply;
            commodities=[:product, :labor],
            variable_names=[
                :demand_product,
                :demand_labor,
                :budget_multiplier,
            ],
            variable_lower_bounds=[
                1.0e-10,
                1.0e-10,
                0.0,
            ],
            variable_upper_bounds=[
                Inf,
                Inf,
                Inf,
            ],
            variable_start=[
                50.0,
                50.0,
                0.01,
            ],
            condition_rule=
                GEM.ExplicitAgentConditions(
                    consumer_conditions,
                ),
            name=:consumer,
        )

    @test GEM.agent_commodity_indices(consumer) == [1, 2]
    @test GEM.agent_name(consumer) == :consumer
    @test model.agents[1] === consumer
    @test model.agent_refs[1] == GEMB.AgentRef(:consumer)
    @test model.agent_index[:consumer] == 1


    # ------------------------------------------------------------
    # 2. Structured commodity selectors preserve canonical order.
    # ------------------------------------------------------------

    structured_model =
        GEMB.GEMBModel(
            [
                GEMB.CommoditySpec(
                    :good;
                    axes=(period=1:2,),
                ),
                :labor,
            ];
            numeraire=GEMB.CommodityRef(
                :good;
                period=1,
            ),
        )

    structured_agent =
        GEMB.add_net_supply_agent!(
            structured_model,
            (local_variables, local_prices, observed_values=Any[]) ->
                zeros(length(local_prices));
            commodities=[
                GEMB.CommodityRef(
                    :good;
                    period=2,
                ),
                :labor,
            ],
            variable_names=Symbol[],
            name=:observer,
        )

    @test GEM.agent_commodity_indices(structured_agent) == [2, 3]


    # ------------------------------------------------------------
    # 3. Unknown/overlapping commodity selectors fail before insertion.
    # ------------------------------------------------------------

    before_agents = length(model.agents)

    @test_throws ArgumentError GEMB.add_net_supply_agent!(
        model,
        consumer_supply;
        commodities=[:missing],
        variable_names=Symbol[],
        name=:bad_missing,
    )

    @test_throws ArgumentError GEMB.add_net_supply_agent!(
        model,
        consumer_supply;
        commodities=[:product, :product],
        variable_names=Symbol[],
        name=:bad_overlap,
    )

    @test length(model.agents) == before_agents
    @test !haskey(model.agent_index, :bad_missing)
    @test !haskey(model.agent_index, :bad_overlap)


    # ------------------------------------------------------------
    # 4. Empty commodity selection is rejected explicitly.
    # ------------------------------------------------------------

    @test_throws ArgumentError GEMB.add_net_supply_agent!(
        model,
        consumer_supply;
        commodities=nothing,
        variable_names=Symbol[],
        name=:bad_empty,
    )


    # ------------------------------------------------------------
    # 5. GEM constructor validation is reused rather than duplicated.
    # ------------------------------------------------------------

    @test_throws DimensionMismatch GEMB.add_net_supply_agent!(
        model,
        consumer_supply;
        commodities=[:product, :labor],
        variable_names=[:x, :y],
        variable_lower_bounds=[0.0],
        variable_upper_bounds=[Inf, Inf],
        variable_start=[1.0, 1.0],
        name=:bad_variables,
    )

    @test !haskey(model.agent_index, :bad_variables)


    # ------------------------------------------------------------
    # 6. Existing specification-based add_agent! remains unchanged.
    # ------------------------------------------------------------

    firm =
        GEMB.add_agent!(
            model,
            GEMB.CESSpec([1.0]);
            outputs=:product,
            demands=:labor,
            name=:firm,
        )

    @test firm isa GEM.AbstractNetSupplyAgent
    @test model.agent_index[:firm] == 2
end

println("GEMB add_net_supply_agent! STEP 3 tests passed.")
