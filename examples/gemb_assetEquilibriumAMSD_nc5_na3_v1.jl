# ================================================================
# gemb_assetEquilibriumAMSD_nc5_na3_v1.jl
#
# Five-asset, three-investor pure exchange equilibrium under AMSD
# preferences.
#
# The data below are kept exactly as supplied for this example.
# Asset 5 is the numeraire, so its equilibrium price is fixed at 1.
# ================================================================

using GEMB


# ----------------------------------------------------------------
# 1. Example data
# ----------------------------------------------------------------

Supply = [
    33.89578  90.85507  28.53771
    43.49115  95.02077  25.89011
    61.55680  69.47180  71.83206
    91.73870  66.62026  44.56933
    28.15137  15.56076  79.28573
]

gamma = [
    0.6232744,
    0.7882139,
    0.9939296,
]

PMP = [
    1.0660246  0.8878886  1.408784
    1.3442117  0.9870545  1.038244
    1.4542937  1.0702799  1.137456
    0.9484998  0.8093732  1.219696
    1.2561716  1.0676716  1.145479
]

PSD = [
    0.04538134  0.14750508  0.11507690
    0.16720093  0.08814214  0.11064672
    0.13700868  0.16597980  0.15997768
    0.16090557  0.13294144  0.01443293
    0.00000000  0.00000000  0.00000000
]

Cor = [
     1.00000000   0.06580022  -0.05338782   0.39778140  0.0
     0.06580022   1.00000000  -0.60527189  -0.07101410  0.0
    -0.05338782  -0.60527189   1.00000000   0.21856150  0.0
     0.39778140  -0.07101410   0.21856150   1.00000000  0.0
     0.00000000   0.00000000   0.00000000   0.00000000  1.0
]


# ----------------------------------------------------------------
# 2. Solve equilibrium
# ----------------------------------------------------------------

result = solve_asset_equilibrium_amsd(
    Supply=Supply,
    gamma=gamma,
    PMP=PMP,
    PSD=PSD,
    Cor=Cor,
)


# ----------------------------------------------------------------
# 3. Results
# ----------------------------------------------------------------

println()
println("========== AMSD asset equilibrium ==========")
println("Solved: ", result.solved)
println("Prices: ", result.p)

println()
println("Equilibrium holdings D:")
display(result.D)

println()
println("Budget multipliers lambda:")
display(result.lambda)

println()
println("Market residual:")
display(result.market_residual)

println()
println("Consumer KKT passed: ", result.kkt_passed)
println(
    "Value-marginal-utility conditions passed: ",
    result.value_marginal_utility_conditions_passed,
)
println("Maximum MCP natural residual: ", result.max_natural_residual)
