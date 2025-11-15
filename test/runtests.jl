using Test
using LiveLayoutUnicodePlots
using UnicodePlots

@testset "LiveLayoutUnicodePlots.jl" begin
    include("test_types.jl")
    include("test_helpers.jl")
    include("test_merging.jl")
    include("test_textplot.jl")
    include("test_integration.jl")
    include("test_cache_invalidation.jl")
end
