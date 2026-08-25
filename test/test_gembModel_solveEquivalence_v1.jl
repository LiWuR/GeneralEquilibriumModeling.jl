# ================================================================
# test_gembModel_solveEquivalence_v1.jl
#
# STEP 6 / first-round completion test for GEMBModel.
#
# It verifies:
#   1. solve(::GEMBModel) delegates through build_model;
#   2. solver kwargs are forwarded;
#   3. a per-call solver override works without mutating GEMBModel;
#   4. the name-based high-level API reproduces the existing
#      integer-based gemb_CES_nc2_na2_v4 equilibrium.
# ================================================================

using Test
using GEM
using GEMB


@testset "GEMBModel STEP 6 solve" begin

    # ============================================================
    # A. Thin solve wrapper semantics without PATH dependence
    # ============================================================

    probe_model = GEMBModel(
        [:product, :labor];
        numeraire=:product,
        solver=(
            low_model;
            marker=nothing,
            kwargs...
        ) -> (
            low_model=low_model,
            marker=marker,
            kwargs=kwargs,
        ),
    )

    add_agent!(
        probe_model,
        CESSpec([1.0]);
        outputs=:product,
        demands=:labor,
        name=:probe_firm,
    )

    probe_result = solve(
        probe_model;
        marker=:default_solver,
        alpha=3,
    )

    @test probe_result.low_model isa GEM.EquilibriumModel
    @test probe_result.low_model.commodity_names == [:product, :labor]
    @test probe_result.marker == :default_solver
    @test probe_result.kwargs[:alpha] == 3

    original_solver = probe_model.solver

    override_solver = (
        low_model;
        marker=nothing,
        kwargs...
    ) -> (
        low_model=low_model,
        marker=marker,
        kwargs=kwargs,
        source=:override,
    )

    override_result = solve(
        probe_model;
        solver=override_solver,
        marker=:override_solver,
        beta=4,
    )

    @test override_result.source == :override
    @test override_result.marker == :override_solver
    @test override_result.kwargs[:beta] == 4
    @test probe_model.solver === original_solver


    # ============================================================
    # B. Existing low-level integer API
    #
    # Same economy as examples/gemb_CES_nc2_na2_v4.jl.
    # ============================================================

    low_firm = build_agent(
        CESSpec([0.5, 0.5]);
        output_indices=[1],
        demand_indices=[1, 2],
        activity_start=40.0,
        name=:firm,
    )

    low_laborer = build_agent(
        CESSpec([0.8, 0.2]);
        demand_indices=[1, 2],
        endowment_indices=[2],
        endowment_quantities=[100.0],
        activity_start=20.0,
        name=:laborer,
    )

    low_model = GEM.EquilibriumModel(
        [low_firm, low_laborer],
        [:prod, :lab],
    )

    low_result = GEM.solve_equilibrium_model_mcp_jump(
        low_model;
        p0=[1.0, 0.25],
        residual_tol=1.0e-8,
        silent=true,
    )


    # ============================================================
    # C. New high-level name API
    # ============================================================

    high_model = GEMBModel(
        [:prod, :lab];
        numeraire=:prod,
    )

    add_agent!(
        high_model,
        CESSpec([0.5, 0.5]);
        outputs=:prod,
        demands=[:prod, :lab],
        activity_start=40.0,
        name=:firm,
    )

    add_agent!(
        high_model,
        CESSpec([0.8, 0.2]);
        demands=[:prod, :lab],
        endowments=:lab,
        endowment_quantities=[100.0],
        activity_start=20.0,
        name=:laborer,
    )

    high_result = solve(
        high_model;
        p0=[1.0, 0.25],
        residual_tol=1.0e-8,
        silent=true,
    )


    # ============================================================
    # D. Both routes solve the same equilibrium
    # ============================================================

    @test low_result.solved
    @test high_result.solved

    @test low_result.mcp_solved
    @test high_result.mcp_solved

    @test low_result.all_markets_clear
    @test high_result.all_markets_clear

    @test high_result.prices ≈ low_result.prices atol=1.0e-9 rtol=1.0e-9
    @test high_result.prices ≈ [1.0, 0.25] atol=1.0e-7 rtol=1.0e-7

    @test high_result.agent_variable_values[1] ≈
          low_result.agent_variable_values[1] atol=1.0e-9 rtol=1.0e-9
    @test high_result.agent_variable_values[2] ≈
          low_result.agent_variable_values[2] atol=1.0e-9 rtol=1.0e-9

    @test high_result.agent_variable_values[1][1] ≈ 40.0 atol=1.0e-7 rtol=1.0e-7
    @test high_result.agent_variable_values[2][1] ≈ 20.0 atol=1.0e-7 rtol=1.0e-7

    @test high_result.agent_net_supplies[1] ≈
          low_result.agent_net_supplies[1] atol=1.0e-9 rtol=1.0e-9
    @test high_result.agent_net_supplies[2] ≈
          low_result.agent_net_supplies[2] atol=1.0e-9 rtol=1.0e-9

    @test high_result.agent_net_supplies[1] ≈
          [20.0, -80.0] atol=1.0e-7 rtol=1.0e-7
    @test high_result.agent_net_supplies[2] ≈
          [-20.0, 80.0] atol=1.0e-7 rtol=1.0e-7

    @test high_result.total_net_supply ≈
          low_result.total_net_supply atol=1.0e-9 rtol=1.0e-9

    @test maximum(abs, high_result.total_net_supply) <= 1.0e-7
    @test high_result.max_natural_residual <= 1.0e-8

    # High-level result still exposes the ordinary canonical GEM model.
    @test high_result.canonical_model isa GEM.EquilibriumModel
    @test high_result.canonical_model.commodity_names == [:prod, :lab]
    @test high_result.canonical_model.numeraire_index == 1
    @test high_result.canonical_model.numeraire_value == 1.0


    # ============================================================
    # E. solve does not mutate the high-level model definition
    # ============================================================

    @test high_model.commodity_names == [:prod, :lab]
    @test high_model.numeraire == :prod
    @test length(high_model.agents) == 2
    @test high_model.agent_index == Dict(
        :firm => 1,
        :laborer => 2,
    )
end

println("GEMBModel STEP 6 solve/equivalence tests passed.")
