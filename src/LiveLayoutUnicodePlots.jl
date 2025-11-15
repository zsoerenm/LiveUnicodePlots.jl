module LiveLayoutUnicodePlots

using UnicodePlots

export merge_plots_horizontal, merge_plots_vertical, LivePlot, @layout, @live_layout, textplot

# Include submodules in dependency order
include("types.jl")
include("helpers.jl")
include("merging.jl")
include("layout_generation.jl")
include("textplot.jl")
include("macros.jl")

end # module
