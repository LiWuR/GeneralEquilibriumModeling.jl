using Test

root = raw"D:\Ju\GeneralEquilibriumModeling"

guide_path = joinpath(root, "docs", "src", "gemb", "custom_net_supply_agents.md")
index_path = joinpath(root, "docs", "src", "gemb", "index.md")
api_path = joinpath(root, "docs", "src", "gemb", "api", "GEMB_ModelingFramework.md")
make_path = joinpath(root, "docs", "make.jl")
source_path = joinpath(root, "src", "GEMB", "gemb_model_v16.jl")

@testset "GEMB custom net-supply documentation" begin
    for path in (guide_path, index_path, api_path, make_path, source_path)
        @test isfile(path)
    end

    guide = read(guide_path, String)
    index = read(index_path, String)
    api = read(api_path, String)
    make = read(make_path, String)
    source = read(source_path, String)

    @test occursin("add_net_supply_agent!", guide)
    @test occursin("standard economic behavior", lowercase(guide))
    @test occursin("build_agent", guide)
    @test occursin("advanced", lowercase(guide))

    @test occursin("custom_net_supply_agents.md", index)
    @test occursin("gemb_model_v16.jl", api)
    @test occursin("gemb/custom_net_supply_agents.md", make)
    @test occursin("function add_net_supply_agent!(", source)
end

println("GEMB custom net-supply documentation tests passed.")
