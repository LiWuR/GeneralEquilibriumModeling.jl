using Test
using GeneralEquilibriumModeling

# The three modules must be declared at top level in Julia.
# They isolate the formerly independent GEM and GEMB package test suites.

module GEMTests
using Test
using GeneralEquilibriumModeling
end

module GEMBTests
using Test
using GeneralEquilibriumModeling
end

module IntegrationTests
using Test
using GeneralEquilibriumModeling
end

@testset "GeneralEquilibriumModeling" begin

    @testset "GEM" begin
        Base.include(
            GEMTests,
            joinpath(@__DIR__, "gem", "runtests.jl"),
        )
    end

    @testset "GEMB" begin
        Base.include(
            GEMBTests,
            joinpath(@__DIR__, "gemb", "runtests.jl"),
        )
    end

    @testset "GEM-GEMB integration" begin
        Base.include(
            IntegrationTests,
            joinpath(@__DIR__, "integration", "runtests.jl"),
        )
    end

end
