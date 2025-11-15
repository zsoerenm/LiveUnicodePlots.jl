using Test
using LiveLayoutUnicodePlots
using UnicodePlots

@testset "LiveLayoutUnicodePlots.jl" begin
    include("test_types.jl")
    include("test_helpers.jl")
    include("test_merging.jl")
    include("test_textplot.jl")
    include("test_integration.jl")
end
