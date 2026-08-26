# ================================================================
# test_path_solver_license_handling_v1.jl
#
# Focused regression for GEM's user-facing PATH license handling.
#
# This test does not require an unlicensed Julia session and does not solve
# a large MCP. It verifies the public exception type, PATH status classifier,
# and error message used when PATHSolver returns its license-failure status.
# ================================================================

using Test
using GeneralEquilibriumModeling.GEM
import MathOptInterface as MOI

@testset "PATH solver license handling" begin
    @test isdefined(GEM, :PATHSolverLicenseError)

    solver_module = GEM.EquilibriumModelSolverV10V19

    @test solver_module._is_path_license_error(
        MOI.OTHER_ERROR,
        "License could not be found",
    )

    @test !solver_module._is_path_license_error(
        MOI.LOCALLY_SOLVED,
        "The problem was solved",
    )

    err = PATHSolverLicenseError(
        321,
        "License could not be found",
    )

    io = IOBuffer()
    showerror(io, err)
    message = String(take!(io))

    @test occursin("PATH solver license error", message)
    @test occursin("complementarity variables: 321", message)
    @test occursin("300 variables", message)
    @test occursin("2000 Jacobian nonzeros", message)
    @test occursin("PATH_LICENSE_STRING", message)
    @test occursin("License could not be found", message)
end

println("PATH solver license handling regression passed.")
