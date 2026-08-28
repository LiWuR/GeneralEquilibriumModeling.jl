using Test
using GeneralEquilibriumModeling.GEM

@testset "GEM" begin
    @testset "Profit condition rules" begin
        include("test_profit_condition_rule_dispatch_v2.jl")
        include("test_UREBC_v2.jl")
        include("test_TREBC_v3.jl")
    end

    @testset "Core regression tests" begin
        include("test_stationary_nonhomogeneous_v1.jl")
        include("test_stationary_nonconvex_multiple_equilibria_v1.jl")
        include("test_cost_minimization_kkt_v1.jl")
        include("test_cost_minimization_kkt_observed_variable_v1.jl")
        include("test_auxiliary_feedback_v1.jl")
        include("test_endogenous_output_tax_auxiliary_v1.jl")
        include("test_pollution_externality_negative_price_v2.jl")
    end
end

# PATH license handling
include("test_path_solver_license_handling_v1.jl")
