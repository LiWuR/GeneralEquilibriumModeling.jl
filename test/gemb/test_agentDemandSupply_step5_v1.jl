# ================================================================
# test_agentDemandSupply_step5_v1.jl
#
# STEP 5: single-agent gross demand / gross supply evaluation.
# ================================================================

using Test
using GeneralEquilibriumModeling

const _GEMB_DS5 = GeneralEquilibriumModeling.GEMB
const _GEM_DS5 = GeneralEquilibriumModeling.GEM


function _check_identity(
    model,
    name,
    local_variables,
    local_prices;
    observed_values=Any[],
)
    result =
        _GEMB_DS5.demand_supply(
            model,
            name,
            local_variables,
            local_prices;
            observed_values=observed_values,
        )

    position =
        model.agent_index[name]

    direct_net_supply =
        _GEM_DS5.agent_net_supply(
            model.agents[position],
            local_variables,
            local_prices,
            observed_values,
        )

    @test result.net_supply ≈
          direct_net_supply

    @test result.supply - result.demand ≈
          result.net_supply

    return result
end


@testset "GEMB single-agent demand/supply STEP 5" begin

    # ------------------------------------------------------------
    # 1. Ordinary producer
    # ------------------------------------------------------------

    model1 =
        _GEMB_DS5.GEMBModel(
            [:product, :labor];
            numeraire=:product,
        )

    spec1 =
        _GEMB_DS5.CESSpec([1.0])

    _GEMB_DS5.add_agent!(
        model1,
        spec1;
        outputs=:product,
        demands=:labor,
        activity_start=100.0,
        name=:firm,
    )

    ds1 =
        _check_identity(
            model1,
            :firm,
            [10.0],
            [1.0, 1.0],
        )

    @test ds1.demand ≈
          [0.0, 10.0]

    @test ds1.net_supply ≈
          [10.0, -10.0]

    @test ds1.supply ≈
          [10.0, 0.0]


    # ------------------------------------------------------------
    # 2. The same commodity may appear in both gross demand and gross supply
    # ------------------------------------------------------------

    model2 =
        _GEMB_DS5.GEMBModel(
            [:product];
            numeraire=:product,
        )

    spec2 =
        _GEMB_DS5.CESSpec([1.0])

    _GEMB_DS5.add_agent!(
        model2,
        spec2;
        outputs=:product,
        demands=:product,
        activity_start=100.0,
        name=:circular,
    )

    ds2 =
        _check_identity(
            model2,
            :circular,
            [10.0],
            [1.0],
        )

    @test ds2.demand ≈
          [10.0]

    @test ds2.net_supply ≈
          [0.0]

    @test ds2.supply ≈
          [10.0]


    # ------------------------------------------------------------
    # 3. Consumer activity demand plus fixed endowment
    # ------------------------------------------------------------

    model3 =
        _GEMB_DS5.GEMBModel(
            [:product, :labor];
            numeraire=:product,
        )

    spec3 =
        _GEMB_DS5.CESSpec([1.0])

    _GEMB_DS5.add_agent!(
        model3,
        spec3;
        demands=:product,
        endowments=:labor,
        endowment_quantities=100.0,
        activity_start=100.0,
        name=:consumer,
    )

    ds3 =
        _check_identity(
            model3,
            :consumer,
            [10.0],
            [1.0, 1.0],
        )

    @test ds3.demand ≈
          [10.0, 0.0]

    @test ds3.net_supply ≈
          [-10.0, 100.0]

    @test ds3.supply ≈
          [0.0, 100.0]


    # ------------------------------------------------------------
    # 4. Ad valorem claim belongs to gross demand
    # ------------------------------------------------------------

    model4 =
        _GEMB_DS5.GEMBModel(
            [:product, :labor, :claim];
            numeraire=:product,
        )

    spec4 =
        _GEMB_DS5.CESSpec([1.0])

    _GEMB_DS5.add_agent!(
        model4,
        spec4;
        outputs=:product,
        demands=:labor,
        claim=:claim,
        claim_rate=0.25,
        activity_start=100.0,
        name=:claimed,
    )

    ds4 =
        _check_identity(
            model4,
            :claimed,
            [10.0],
            [1.25, 1.0, 2.0],
        )

    @test ds4.demand ≈
          [0.0, 10.0, 1.25]

    @test ds4.net_supply ≈
          [10.0, -10.0, -1.25]

    @test ds4.supply ≈
          [10.0, 0.0, 0.0]


    # ------------------------------------------------------------
    # 5. Displaced DCES producer shutdown convention
    # ------------------------------------------------------------

    model5 =
        _GEMB_DS5.GEMBModel(
            [:product, :labor];
            numeraire=:product,
        )

    spec5 =
        _GEMB_DS5.DCESSpec(
            [1.0];
            es=0.0,
            xi=[2.0],
        )

    _GEMB_DS5.add_agent!(
        model5,
        spec5;
        outputs=:product,
        demands=:labor,
        activity_start=100.0,
        name=:dces_firm,
    )

    ds5 =
        _check_identity(
            model5,
            :dces_firm,
            [0.0],
            [1.0, 1.0],
        )

    @test ds5.demand ≈
          [0.0, 0.0]

    @test ds5.net_supply ≈
          [0.0, 0.0]

    @test ds5.supply ≈
          [0.0, 0.0]


    # ------------------------------------------------------------
    # 6. AgentRef lookup
    # ------------------------------------------------------------

    ds_ref =
        _GEMB_DS5.demand_supply(
            model1,
            _GEMB_DS5.AgentRef(:firm),
            [10.0],
            [1.0, 1.0],
        )

    @test ds_ref.demand ≈
          ds1.demand

    @test ds_ref.supply ≈
          ds1.supply


    # ------------------------------------------------------------
    # 7. Net-supply-only agents must not invent a gross decomposition
    # ------------------------------------------------------------

    model7 =
        _GEMB_DS5.GEMBModel(
            [:product];
            numeraire=:product,
        )

    _GEMB_DS5.add_net_supply_agent!(
        model7,
        (variables, prices) -> [0.0];
        commodities=:product,
        name=:custom,
    )

    @test model7.agent_records[1] isa
          _GEMB_DS5.NetSupplyOnlyAgentRecord

    @test_throws ArgumentError _GEMB_DS5.demand_supply(
        model7,
        :custom,
        Float64[],
        [1.0],
    )
end

println("GEMB single-agent demand/supply STEP 5 tests passed.")
