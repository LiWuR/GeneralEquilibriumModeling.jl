# ================================================================
# test_assetEquilibriumAMSD_v1.jl
#
# Regression test for solve_asset_equilibrium_amsd.
# ================================================================

using Test
using GEMB

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

@testset "GEMB AMSD asset equilibrium" begin
    result = solve_asset_equilibrium_amsd(
        Supply=Supply,
        gamma=gamma,
        PMP=PMP,
        PSD=PSD,
        Cor=Cor,
        silent=true,
    )

    @test result.solved
    @test result.kkt_passed
    @test result.value_marginal_utility_conditions_passed

    @test size(result.D) == (5, 3)
    @test length(result.p) == 5
    @test length(result.lambda) == 3

    @test result.p[5] ≈ 1.0 atol=1.0e-10 rtol=1.0e-10
    @test maximum(abs.(result.market_residual)) <= 1.0e-7
    @test maximum(abs.(result.budget_slack)) <= 1.0e-7

    # Numerical benchmark for the supplied data.
    expected_p = [
        0.7604591258,
        0.9102246780,
        0.9484285222,
        0.7108081164,
        1.0,
    ]

    expected_D = [
          0.0         41.4575420675  111.8310179325
         82.7348394146 81.6671905854    0.0
        149.5083548686 53.3523051314    0.0
          0.0          6.9285487004  195.9997412996
          0.0        122.9978600000    0.0
    ]

    expected_lambda = [
        1.4667540641,
        1.0676716000,
        1.7046588610,
    ]

    @test result.p ≈ expected_p atol=1.0e-6 rtol=1.0e-6
    @test result.D ≈ expected_D atol=1.0e-5 rtol=1.0e-6
    @test result.lambda ≈ expected_lambda atol=1.0e-6 rtol=1.0e-6
end
